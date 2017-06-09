package Finance::VolSurface;
# ABSTRACT: Abstraction for dealing with volatility surfaces

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Finance::VolSurface -  represents a volatility surface

=head1 SYNOPSIS

    use feature qw(say);
    use Finance::VolSurface;

    Finance::VolSurface->new(
        delta => { ... },
    );

    my $volsurface = Finance::VolSurface::Delta->new(
        surface       => { ... },
        recorded_date => $date,
        underlying    => Finance::Underlying->by_symbol('frxEURUSD'),
        r_rates       => Finance::YieldCurve->new(asset => 'EUR', data => { ... }),
        q_rates       => Finance::YieldCurve->new(asset => 'USD', data => { ... }),
    );

    # Interpolate points on the surface to get a single number for volatility
    my $vol = $volsurface->get_volatility(
        delta => 50,
        from  => $now,
        to    => $now->plus('3d'),
    );
    # Spread from max or atm
    my $spread = $volsurface->get_spread(
        sought_point => 'atm', # may rename to delta
        days         => 7,     # may rename to tenor
    );

    # Validation for the supplied volsurface
    die 'incorrect volsurface provided: ' . $volsurface->validation_error unless $volsurface->is_valid;

=head1 DESCRIPTION

=head2 Delta surface

Raw surface data for a delta surface:

 {
   'ON' => {
       smile => {
           50 => 0.4,
           25 => 0.2,
           75 => 0.7,
       },
       spread => {
           50 => 0.1,
           25 => 0.1,
           75 => 0.1,
       },
   },
   '1W' => {
       smile => {
           50 => 0.4,
           25 => 0.2,
           75 => 0.7,
       },
       spread => {
           50 => 0.1,
           25 => 0.1,
           75 => 0.1,
       },
   },
   '2W' => { ... }
 }

Expected tenors could include:

* ON for overnight
* 1W for 1 week
* 6M for 6 month
* 1Y for 1 year

Internally, the key for the surface is always a number of days (the tenor),
and for overnight this would typically be 1 to 3 (for weekends).

On load, we need to 

=head2 Moneyness

The keys in the smile hashref are moneyness points as percentages (100 = 100%),
typically ranging from 80%-120%.

Spread has a single atm value.

 {
   1 => {
       smile => {
           80 => 0.2,
           82 => 0.2,
           84 => 0.2,
           88 => 0.2,
           92 => 0.2,
           96 => 0.2,
           100 => 0.4,
           102 => 0.4,
           104 => 0.4,
           108 => 0.4,
           114 => 0.4,
           120 => 0.7,
       },
       spread => {
           100 => 0.1,
       },
   },
   7 => { ... },
 }

=head2 Flat

This is a single point.

 {
   1 => {
       smile => {
           100 => 0.1,
       },
       spread => {
           100 => 0,
       },
   },
   7 => { ... },
 }

=head2 Construction

    Finance::VolSurface->new({
        underlying    => Finance::Underlying->by_symbol('frxEURUSD'),
    });

=cut

no indirect;

use Moose;

use Date::Utility;
use Try::Tiny;

use List::Util qw(first);
use List::MoreUtils qw(notall any);
use List::Util qw( min max first );

use Finance::Underlying;
use Finance::YieldCurve;

use Finance::VolSurface::Utils;
use Finance::VolSurface::Types qw(Finance_VolSurface_Type);
use Finance::VolSurface::ExpiryConventions;

=head2 effective_date

Surfaces roll over at 5pm NY time, so the vols of any surfaces recorded after 5pm NY but
before GMT midnight are effectively for the next GMT day. This attribute holds this
effective date.

=cut

has effective_date => (
    is         => 'ro',
    init_arg   => undef,
    lazy_build => 1,
);

sub _build_effective_date {
    my $self = shift;

    return Finance::VolSurface::Utils->new->effective_date_for($self->recorded_date);
}

=head2 for_date

The date for which we want to have the volatility surface data

=cut

has for_date => (
    is      => 'ro',
    default => undef,
);

=head2 recorded_date

The date (and time) that the surface was recorded, as a Date::Utility.

=cut

has recorded_date => (
    is         => 'ro',
    lazy_build => 1,
);

=head2 q_rates

A yield curve for Q rates. For stocks, these would represent dividends.

=cut

has q_rates => (
    is       => 'ro',
    isa      => 'Finance::YieldCurve',
    required => 1,
);

=head2 r_rates

A yield curve for R rates. This would typically be interest rates.

=cut

has r_rates => (
    is       => 'ro',
    isa      => 'Finance::YieldCurve',
    required => 1,
);

=head2 smile_points

The points across a smile.

It can be delta points, moneyness points or any other points that we might have in the future.

=cut

has smile_points => (
    is         => 'ro',
    isa        => 'ArrayRef',
    lazy_build => 1,
);

sub _build_smile_points {
    my $self = shift;

    # Default to the point found in the first day we find
    # in $self->surface that has a smile. As long as each smile
    # has the same points, this works. If each smile has different
    # points, the Validator is going to give you trouble!
    my $surface = $self->surface;
    my $suitable_day = first { exists $surface->{$_}->{smile} } @{$self->term_by_day};

    return [sort { $a <=> $b } keys %{$surface->{$suitable_day}->{smile}}] if $suitable_day;
    return [];
}

=head2 spread_points

This will give an array-reference containing volatility spreads for first tenor which has a volatility spread (or ATM if none).

=cut

has spread_points => (
    is         => 'ro',
    isa        => 'ArrayRef',
    lazy_build => 1,
);

sub _build_spread_points {
    my $self = shift;

    # Default to the point found in the first day we find
    # in $self->surface that has a volspread. As long as each volspread
    # has the same points, this works. If each smile has different
    # points, the Validator is going to give you trouble!
    my $surface = $self->surface;
    my $suitable_day = first { exists $surface->{$_}->{vol_spread} } keys %{$surface};

    return [sort { $a <=> $b } keys %{$surface->{$suitable_day}{vol_spread}}] if $suitable_day;
    return [];
}

=head2 surface

Volatility surface in a hash reference.

=cut

has surface => (
    is         => 'ro',
    lazy_build => 1,
);

=head2 surface_data

The original surface data.

=cut

has surface_data => (
    is         => 'ro',
    lazy_build => 1,
);

=head2 symbol

The symbol of the underlying that this surface is for (e.g. frxUSDJPY)

=cut

sub symbol { shift->underlying->symbol }

=head2 term_by_day

Get all the terms in a surface in ascending order.

=cut

has term_by_day => (
    is         => 'ro',
    isa        => 'ArrayRef',
    init_arg   => undef,
    lazy_build => 1,
);

sub _build_term_by_day {
    my $self = shift;

    return [sort { $a <=> $b } keys %{$self->surface}];
}

=head2 type

Type of the surface, delta, moneyness or flat.

=cut

has type => (
    is       => 'ro',
    isa      => Finance_VolSurface_Type,
    required => 1,
    init_arg => undef,
    default  => undef,
);

=head2 underlying

The L<Finance::Underlying> for this volsurface (mandatory).

=cut

has underlying => (
    is  => 'ro',
    isa => 'Finance::Underlying',
);

=head2 get_rr_bf_for_smile

Return the rr and bf values for a given smile
For more info see: https://en.wikipedia.org/wiki/Risk_reversal and https://en.wikipedia.org/wiki/Butterfly_(options)

=cut

sub get_rr_bf_for_smile {
    my ($self, $market_smile) = @_;

    my $result = {
        ATM   => $market_smile->{50},
        RR_25 => $market_smile->{25} - $market_smile->{75},
        BF_25 => ($market_smile->{25} + $market_smile->{75}) / 2 - $market_smile->{50},
    };
    if (exists $market_smile->{10}) {
        $result->{RR_10} = $market_smile->{10} - $market_smile->{90};
        $result->{BF_10} = ($market_smile->{10} + $market_smile->{90}) / 2 - $market_smile->{50};
    }

    return $result;
}

=head2 get_surface_smile

Returns the smile on the surface.
Returns an empty hash reference if not present.

=cut

sub get_surface_smile {
    my ($self, $days) = @_;

    return $self->surface->{$days}->{smile} // {};
}

=head2 is_valid

Does this volatility surface pass our validation.

=cut

sub is_valid {
    my $self = shift;

    try {
        $self->$_ for ($self->_validation_methods);
    }
    catch {
        $self->validation_error($_);
    };

    return !$self->validation_error;
}

sub _validate_age {
    my $self = shift;

    if (time - $self->recorded_date->epoch > 4 * 3600) {
        die('Volatility surface from provider for ' . $self->symbol . ' is more than 4 hours old.');
    }

    return;
}

sub _validate_structure {
    my $self = shift;

    my $surface_hashref = $self->surface;
    my $system_symbol   = $self->symbol;

    # Somehow I do not know why there is a limit of term on delta surface, but
    # for moneyness we might need at least up to 2 years to get the spread.
    my $extra_allowed = $Quant::Framework::Underlying::extra_vol_diff_by_delta || 0;
    my $max_vol_change_by_delta = 0.4 + $extra_allowed;

    my @days = sort { $a <=> $b } keys %{$surface_hashref};

    if (@days < 2) {
        die('Must be at least two maturities on vol surface for ' . $self->symbol . '.');
    }

    if ($days[-1] > $self->_max_allowed_term) {
        die("Day[$days[-1]] in volsurface for underlying[$system_symbol] greater than allowed[" . $self->_max_allowed_term . "].");
    }

    if ($self->underlying->market->name eq 'forex' and $days[0] > 7) {
        die("ON term is missing in volsurface for underlying $system_symbol, the minimum term is $days[0].");
    }

    foreach my $day (@days) {
        if ($day !~ /^\d+$/) {
            die("Invalid day[$day] in volsurface for underlying[$system_symbol]. Not a positive integer.");
        }
    }

    foreach my $day (grep { exists $surface_hashref->{$_}->{smile} } @days) {
        my $smile = $surface_hashref->{$day}->{smile};
        my @volatility_level = sort { $a <=> $b } keys %$smile;

        for (my $i = 0; $i < $#volatility_level; $i++) {
            my $level = $volatility_level[$i];

            if ($level !~ /^\d+\.?\d+$/) {
                die("Invalid vol_point[$level] for underlying[$system_symbol].");
            }

            my $next_level = $volatility_level[$i + 1];
            if (abs($level - $next_level) > $self->_max_difference_between_smile_points) {
                die("Difference between point $level and $next_level is too great for days $day.");
            }

            if (not $self->_is_valid_volatility_smile($smile)) {
                die("Invalid smile volatility on $day for $system_symbol");
            }

            if (abs($smile->{$level} - $smile->{$next_level}) > $max_vol_change_by_delta * $smile->{$level}) {
                die(      "Invalid volatility points: too big jump from "
                        . "$level:$smile->{$level} to $next_level:$smile->{$next_level}"
                        . "for maturity[$day], underlying[$system_symbol]");
            }
        }
    }

    return;
}

sub _is_valid_volatility_smile {
    my ($self, $smile) = @_;

    foreach my $vol (values %$smile) {
        # sanity check on volatility. Cannot be more than 500% and must be a number.
        return if ($vol !~ /^\d?\.?\d*$/ or $vol > 5);
    }

    return 1;
}

sub _validate_identical_surface {
    my $self = shift;

    my $existing = $self->new({
        underlying       => $self->underlying,
        chronicle_reader => $self->chronicle_reader,
        chronicle_writer => $self->chronicle_writer,
    });

    my $existing_surface_data = $existing->surface;
    my $new_surface_data      = $self->surface;

    my @existing_terms = sort { $a <=> $b } grep { exists $existing_surface_data->{$_}{smile} } keys %$existing_surface_data;
    my @new_terms      = sort { $a <=> $b } grep { exists $new_surface_data->{$_}{smile} } keys %$new_surface_data;

    return if @existing_terms != @new_terms;
    return if any { $existing_terms[$_] != $new_terms[$_] } (0 .. $#existing_terms);

    foreach my $term (@existing_terms) {
        my $existing_smile = $existing_surface_data->{$term}->{smile};
        my $new_smile      = $new_surface_data->{$term}->{smile};
        return if (scalar(keys %$existing_smile) != scalar(keys %$new_smile));
        return if (any { $existing_smile->{$_} != $new_smile->{$_} } keys %$existing_smile);
    }

    my $existing_surface_epoch = Date::Utility->new($self->document->{date})->epoch;

    if (time - $existing_surface_epoch > 15000 and not $self->underlying->quanto_only) {
        die('Surface data has not changed since last update [' . $existing_surface_epoch . '] for ' . $self->symbol . '.');
    }

    return;
}

sub _validate_volatility_jumps {
    my $self = shift;

    my $existing = $self->new({
        underlying       => $self->underlying,
        chronicle_reader => $self->chronicle_reader,
        chronicle_writer => $self->chronicle_writer,
    });

    my @terms           = @{$self->original_term_for_smile};
    my @new_expiry      = @{$self->get_smile_expiries};
    my @existing_expiry = @{$existing->get_smile_expiries};

    my @points = @{$self->smile_points};
    my $type   = $self->type;

    for (my $i = 1; $i <= $#new_expiry; $i++) {
        for (my $j = 0; $j <= $#points; $j++) {
            my $sought_point = $points[$j];
            my $new_vol      = $self->get_volatility({
                $type => $sought_point,
                from  => $self->recorded_date,
                to    => $new_expiry[$i],
            });
            my $existing_vol = $existing->get_volatility({
                $type => $sought_point,
                from  => $existing->recorded_date,
                to    => $existing_expiry[$i],
            });
            my $diff = abs($new_vol - $existing_vol);
            if ($diff > 0.03 and $diff > $existing_vol) {
                die('Big difference found on term[' . $terms[$i - 1] . '] for point [' . $sought_point . '] with absolute diff [' . $diff . '].');
            }
        }
    }

    return;
}

has validation_error => (
    is      => 'rw',
    default => '',
);
1;
