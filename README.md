# NAME

Finance::VolSurface -  represents a volatility surface

# SYNOPSIS

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

Note that a volsurface instance must always be created from the appropriate subclass,
i.e. one of:

- [Finance::VolSurface::Delta](https://metacpan.org/pod/Finance::VolSurface::Delta)
- [Finance::VolSurface::Moneyness](https://metacpan.org/pod/Finance::VolSurface::Moneyness)
- [Finance::VolSurface::Flat](https://metacpan.org/pod/Finance::VolSurface::Flat)

# ATTRIBUTES

## effective\_date

Surfaces roll over at 5pm NY time, so the vols of any surfaces recorded after 5pm NY but
before GMT midnight are effectively for the next GMT day. This attribute holds this
effective date.

## recorded\_date

The date (and time) that the surface was recorded, as a [Date::Utility](https://metacpan.org/pod/Date::Utility). This should
be provided on construction.

## q\_rates

A yield curve for Q rates. For stocks, these would represent dividends.

## r\_rates

A yield curve for R rates. This would typically be interest rates.

## smile\_points

The points across a smile.

It can be delta points, moneyness points or any other points that we might have in the future.

Returns an arrayref of numerical point values that comprise the smile.

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

## underlying

The [Finance::Underlying](https://metacpan.org/pod/Finance::Underlying) for this volsurface (mandatory).

## get\_rr\_bf\_for\_smile

Return the rr and bf values for a given smile
For more info see: https://en.wikipedia.org/wiki/Risk\_reversal and https://en.wikipedia.org/wiki/Butterfly\_(options)

## get\_surface\_smile

Returns the smile on the surface.
Returns an empty hash reference if not present.

## is\_valid

Does this volatility surface pass our validation.

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

## atm\_spread\_point

(to be defined)

## variance\_table

A variance surface. Converted from raw volatility input surface.
Only available on delta volsurfaces.

## get\_smile

Calculate the requested smile from volatility surface.

Usage:

    my $smile = $vol_surface->get_smile($days);

## get\_variances

Calculate the variance for a given date based on volatility surface data.

Only applicable to delta volsurfaces.

## get\_weight

Get the weight between two given dates.

## get\_market\_rr\_bf

Returns the rr and bf values for a given day

## get\_smile\_expiries

An array reference of that contains expiry dates for smiles on the volatility surface.

## min\_vol\_spread

minimum volatility spread that we can accept for this volatility surface.

## interpolate

Quadratic interpolation to interpolate across smile

    $surface->interpolate({smile => $smile, sought_point => $sought_point});

---

# NAME

Finance::VolSurface::Delta

# DESCRIPTION

See [Finance::VolSurface](https://metacpan.org/pod/Finance::VolSurface).

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

See [Finance::VolSurface](https://metacpan.org/pod/Finance::VolSurface).

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

## get\_ny\_offset\_from\_gmt

Returns offset in hours for the given epoch for NY vs GMT.
Caches output per hour.
