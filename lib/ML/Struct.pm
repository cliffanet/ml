package ML::Struct;

use strict;
use warnings;

sub new {
    my ($class, $src) = @_;

    if (!defined($src)) {
        $src = '';
    }

    my $root = {
        type    => 'root',
        content => '',
        beg     => { line => 1, pos => 0 },
        inner   => [],
    };

    my $self = {
        src     => $src,
        root    => $root
    };

    my %p = _parse($root, $src, dst => $root->{inner});

    bless $self, $class;

    return $self;
}

sub err {
    my $self = shift;

    return %{ $self->{err} || {} };
}

=pod
sub _err {
    my $s = shift;

    if (@_) {
        $s = sprintf $s, @_;
    }

    $self->{err} = {
        line    => $self->{line},
        pos     => $self->{pos},
        text    => $s,
    };
}
=cut

sub _parse {
    my ($ctx, $src, $dst) = @_;

    return
        $src =~ /^if[^a-zA-Z0-9]/ ?
            _parse_if(@_) :
            (

            );
}

sub _parse_if {
    my ($ctx, $src, $dst) = @_;
}

1;