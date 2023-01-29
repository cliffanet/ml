package ML::Struct;

use strict;
use warnings;
use base 'ML::Struct::Symb';

sub new {
    my ($class, $src) = @_;

    if (!defined($src)) {
        $src = '';
    }

    my $self = {};
    bless $self, $class;

    $self->symb_init($src) || return $self;

    #if (my $root = $self->parse_root) {
    #    $self->{root} = $root;
    #}

    return $self;
}

sub err {
    my $self = shift;

    if (@_) {
        my $s = shift;

        if (@_) {
            $s = sprintf $s, @_;
        }

        $self->{err} = $s;
        return;
    }

    exists( $self->{err} ) || return;

    return sprintf('[row: %d, col: %d] %s', $self->{row}, $self->{col}, $self->{err});
}

1;
