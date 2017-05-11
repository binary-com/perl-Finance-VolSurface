package Finance::VolSurface::Types;

use strict;
use warnings;

use Type::Tiny;
use Type::Library -base;

my @surface_types = qw( delta flat moneyness);
my $regex = '(' . join('|', @surface_types) . ')';
my $type = "Type::Tiny"->new(
    name       => "finance_volsurface_type",
    constraint => sub { 
        /^$regex$/;
    },
    message    => sub {
        "Invalid surface type $_. Must be one of: " . join(', ', @surface_types);
    },
);

__PACKAGE__->meta->add_type($type);
__PACKAGE__->meta->make_immutable;

1;

