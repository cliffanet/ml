package ML::Struct;

use strict;
use warnings;
use ML::Struct::Symb;
use ML::Struct::Obj;

my $err;
sub err { $err }

sub parse {
    shift() if $_[0] && ($_[0] eq __PACKAGE__);

    undef $err;

    my @symb = ML::Struct::Symb->parse(@_);
    if (my $e = ML::Struct::Symb->err()) {
        $err = 'stage 1 (structure): ' . $e;
    }

    my @obj = ML::Struct::Obj->parse(@symb);
    if (my $e = ML::Struct::Obj->err()) {
        $err = 'stage 2 (syntax): ' . $e;
    }

    return @obj;
}

1;
