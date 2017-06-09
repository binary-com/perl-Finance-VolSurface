# NAME

Finance::VolSurface -  represents a volatility surface

# SYNOPSIS

    use feature qw(say);
    use Finance::VolSurface;

    Finance::VolSurface->new(
        delta => { ... },
    );

    my $volsurface = Finance::VolSurface::Delta->new(
        surface       => { ... },
        recorded_date => $date,
        underlying    => '...',
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

# DESCRIPTION

## Delta surface

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

\* ON for overnight
\* 1W for 1 week
\* 6M for 6 month
\* 1Y for 1 year

Internally, the key for the surface is always a number of days (the tenor),
and for overnight this would typically be 1 to 3 (for weekends).

On load, we need to 

## Moneyness

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

## Flat

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

## Construction

    Finance::VolSurface->new({
        underlying    => 'frxUSDJPY',
    });

## effective\_date

Surfaces roll over at 5pm NY time, so the vols of any surfaces recorded after 5pm NY but
before GMT midnight are effectively for the next GMT day. This attribute holds this
effective date.

## for\_date

The date for which we want to have the volatility surface data

## recorded\_date

The date (and time) that the surface was recorded, as a Date::Utility.

## smile\_points

The points across a smile.

It can be delta points, moneyness points or any other points that we might have in the future.

## spread\_points

This will give an array-reference containing volatility spreads for first tenor which has a volatility spread (or ATM if none).

## surface

Volatility surface in a hash reference.

## surface\_data

The original surface data.

## symbol

The symbol of the underlying that this surface is for (e.g. frxUSDJPY)

## term\_by\_day

Get all the terms in a surface in ascending order.

## type

Type of the surface, delta, moneyness or flat.

## get\_rr\_bf\_for\_smile

Return the rr and bf values for a given smile
For more info see: https://en.wikipedia.org/wiki/Risk\_reversal and https://en.wikipedia.org/wiki/Butterfly\_(options)

## get\_surface\_smile

Returns the smile on the surface.
Returns an empty hash reference if not present.

---

# NAME

Finance::VolSurface::Delta

# DESCRIPTION

Represents a volatility surface, built from market implied volatilities.

# SYNOPSIS

    my $underlying = 'frxUSDJPY';
    my $surface = Finance::VolSurface::Delta->new({underlying => $underlying});

# ATTRIBUTES

## type

Return the surface type

## atm\_spread\_point

(to be defined)

## variance\_table

A variance surface. Converted from raw volatility input surface.

## get\_volatility

Calculates volatility from the surface based input parameters.

Expects 3 mandatory arguments as input.

1) from - Date::Utility object
2) to - Date::Utility object
3) delta | strike | moneyness.

For a moneyness surface, the `spot` value is also required.

Will return a single volatility value, or throw an exception if the volsurface or parameters
are invalid.

Examples:

    my $from = Date::Utility->new('2016-06-01 10:00:00');
    my $to   = Date::Utility->new('2016-06-01 15:00:00');
    my $vol  = $s->get_volatility({delta => 25, from => $from, to => $to});
    my $vol  = $s->get_volatility({strike => $bet->barrier, from => $from, to => $to});
    my $vol  = $s->get_volatility({moneyness => 95, spot => 104.23, from => $from, to => $to});

## get\_smile

Calculate the requested smile from volatility surface.

## get\_variances

Calculate the variance for a given date based on volatility surface data.

## get\_weight

Get the weight between to given dates.

## interpolate

Quadratic interpolation to interpolate across smile
\->interpolate({smile => $smile, sought\_point => $sought\_point});

## get\_market\_rr\_bf

Returns the rr and bf values for a given day

## get\_smile\_expiries

An array reference of that contains expiry dates for smiles on the volatility surface.

---

# NAME

Finance::VolSurface::ExpiryConventions - utilities for dealing with expiry for converting tenor to/from a number of days

# SYNOPSIS

    use Finance::VolSurface::ExpiryConventions;

# DESCRIPTION

---

# NAME

Finance::VolSurface::Moneyness

# DESCRIPTION

Base class for strike-based volatility surfaces by moneyness.

## type

Return the surface type

## min\_vol\_spread

minimum volatility spread that we can accept for this volatility surface.

## spot

Get the spot reference used to calculate the surface.

We should always use reference spot of the surface for any moneyness-related vol calculation

## get\_volatility

USAGE:

    my $vol = $s->get_volatility({moneyness => 96, from => $from, to => $to});
    my $vol = $s->get_volatility({strike => $bet->barrier, from => $from, to => $to});
    my $vol = $s->get_volatility({moneyness => 90, from => $from, to => $to});

## get\_smile

Get the smile for specific day.

Usage:

    my $smile = $vol_surface->get_smile($days);

## interpolate

This is how you could interpolate across smile.
This uses the default interpolation method of the surface.

    $surface->interpolate({smile => $smile, sought_point => $sought_point});

## get\_market\_rr\_bf

Returns the rr and bf values for a given day

## get\_smile\_expiries

An array reference of that contains expiry dates for smiles on the volatility surface.

---

## finance\_volsurface\_type

Volatility surface types.

---

# NAME

Finance::VolSurface::Utils

# DESCRIPTION

Some general vol-related utility functions.

# SYNOPSIS

## NY1700\_rollover\_date\_on

Returns (as a Date::Utility) the NY1700 rollover date for a given Date::Utility.

## effective\_date\_for

Get the "effective date" for a given Date::Utility (stated in GMT).

This is the we should consider a volsurface effective for, and rolls over
every day at NY1700. If a volsurface is quoted at GMT2300, its effective
date is actually the next day.

This returns a Date::Utility truncated to midnight of the relevant day.

## is\_before\_rollover

Returns 1 if given date-time is before roll-over time.
