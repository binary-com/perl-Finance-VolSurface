# NAME

Finance::VolSurface - 

# SYNOPSIS

    use feature qw(say);
    use Finance::VolSurface;

# DESCRIPTION

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
