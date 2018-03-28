package Finance::VolSurface::Utils;

=head1 NAME

Finance::VolSurface::Utils

=head1 DESCRIPTION

Some general vol-related utility functions.

=head1 SYNOPSIS

=cut

no indirect;
use Moo;

use Date::Utility;
use Number::Closest::XS qw(find_closest_numbers_around);
use List::MoreUtils qw(notall);
use List::Util qw(min max);

## VERSION

=head2 NY1700_rollover_date_on

Returns (as a Date::Utility) the NY1700 rollover date for a given Date::Utility.

=cut

sub NY1700_rollover_date_on {
    my ($self, $date) = @_;

    return $date->truncate_to_day->plus_time_interval((17 - $date->timezone_offset('America/New_York')->hours) * 3600);
}

=head2 effective_date_for

Get the "effective date" for a given Date::Utility (stated in GMT).

This is the we should consider a volsurface effective for, and rolls over
every day at NY1700. If a volsurface is quoted at GMT2300, its effective
date is actually the next day.

This returns a Date::Utility truncated to midnight of the relevant day.

=cut

sub effective_date_for {
    my ($self, $date) = @_;

    return $date->plus_time_interval((7 + $date->timezone_offset('America/New_York')->hours) * 3600)->truncate_to_day;
}

=head2 is_before_rollover

Returns 1 if given date-time is before roll-over time.

=cut

sub is_before_rollover {
    my ($self, $date) = @_;

    return ($date->is_after($self->NY1700_rollover_date_on($date))) ? 0 : 1;
}

sub _get_points_to_interpolate {
    my ($seek, $available_points) = @_;
    die('Need 2 or more term structures to interpolate.')
        if scalar @$available_points <= 1;

    return @{find_closest_numbers_around($seek, $available_points, 2)};
}

sub _is_between {
    my ($seek, $points) = @_;

    my @points = @$points;

    die('some of the points are not defined')
        if (notall { defined $_ } @points);
    die('less than two available points')
        if (scalar @points < 2);

    return if $seek > max(@points) or $seek < min(@points);
    return 1;
}

=head2 get_ny_offset_from_gmt

Returns offset in hours for the given epoch for NY vs GMT.
Caches output per hour.

=cut

my $ny_offset_from_gmt_by_hour = {};

sub get_ny_offset_from_gmt {
    my $epoch = shift;
    $epoch = int($epoch / 3600);
    $ny_offset_from_gmt_by_hour->{$epoch} = Date::Utility->new($epoch * 3600)->timezone_offset('America/New_York')->hours
        unless $ny_offset_from_gmt_by_hour->{$epoch};
    return $ny_offset_from_gmt_by_hour->{$epoch};
}

1;
