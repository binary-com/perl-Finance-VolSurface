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

    my $volsurface = Finance::VolSurface::Delta->new(
        surface       => { ... },  # see L</Delta surface> for format
        recorded_date => $date,    # this is a L<Date::Utility> instance
        underlying    => Finance::Underlying->by_symbol('frxEURUSD'),
        r_rates       => Finance::YieldCurve->new(asset => 'EUR', data => { ... }),
        q_rates       => Finance::YieldCurve->new(asset => 'USD', data => { ... }),
    );

    # Interpolate points on the surface to get a single number for volatility
    my $vol = $volsurface->get_volatility(
        delta => 50,
        from  => $now,  # This is a L<Date::Utility> instance
        to    => $now->plus('3d'),
    );

    # TODO - Spread from max or atm
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

Note that a volsurface instance must always be created from the appropriate subclass,
i.e. one of:

=over 4

=item * L<Finance::VolSurface::Delta>

=item * L<Finance::VolSurface::Moneyness>

=item * L<Finance::VolSurface::Flat>

=back

=cut

no indirect;

use Moose;

use Date::Utility;

use List::Util qw(first);

use Finance::Underlying;

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

1;
