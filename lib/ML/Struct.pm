package ML::Struct;

use strict;
use warnings;
use ML::Struct::Symb;


my $err;
sub err { $err }

sub parse {
    shift() if $_[0] && ($_[0] eq __PACKAGE__);

    undef $err;

    my @symb = ML::Struct::Symb->parse(@_);
    if (my $e = ML::Struct::Symb->err()) {
        $err = $e;
    }

    return @symb;
}

1;
