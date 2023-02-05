package ML::Struct::Symb;

use strict;
use warnings;

my $err;

sub parse {
    shift() if $_[0] && ($_[0] eq __PACKAGE__);
    
    undef $err;

    my $self = {};
    bless $self, __PACKAGE__;

    my $symb = $self->init(@_);
    if (!$symb) {
        $err = $self->err();
        return;
    }

    return @$symb;
}

sub err {
    return $err if !@_ || !ref($_[0]);

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

sub init {
    my $self = shift;
    my $src = shift;
    
    $self->{src} = $src;
    $self->{row} = 1;
    $self->{col} = 1;
    delete $self->{symb};
    delete $self->{err};

    my $symb = $self->inner() || return;
    return $self->{symb} = $symb;
}

sub incpos {
    my $self = shift();
    my $s = shift;
    return if !defined($s) || ($s eq '');

    while ($s ne '') {
        if ($s =~ s/^([^\r\n]+)//) {
            $self->{col} += length $1;
        }
        if (($s =~ s/^\r?\n//) || ($s =~ s/^\r//)) {
            $self->{row} ++;
            $self->{col} = 1;
        }
    }
}

sub elem {
    my $self = shift;
    my $type = shift;
    my $str = shift;

    my @r = (
        type    => $type,
        str     => $str,
        row     => $self->{row},
        col     => $self->{col},
        @_,
    );
    $self->incpos($str);

    return @r;
}

sub inner {
    my $self = shift;
    my ($beg, $end) = @_;

    my @symb = ();

    while ($self->{src} ne '') {
        if ($end && (substr($self->{src}, 0, length($end)) eq $end)) {
            substr($self->{src}, 0, length($end)) = '';
            return [@symb];
        }

        my $s = { $self->symb() };
        $s->{type} || return;

        if ($s->{type} ne 'space') {
            push @symb, $s;
        }
    }

    if ($beg) {
        $self->err('Unexpected end of block, beginned at: row=%d, col=%s, symb=%s', $beg->{row}, $beg->{col}, $beg->{str});
    }

    return [@symb];
}

sub symb {
    my $self = shift;

    if ($self->{src} =~ s/^(\s+)//) {
        return $self->elem(space => $1);
    }
    elsif ($self->{src} =~ s/^([a-zA-Z_][a-zA-Z0-9_]*)//) {
        return $self->elem(name => $1);
    }
    elsif ($self->{src} =~ /^\.?\d/) {
        return $self->dig();
    }
    elsif ($self->{src} =~ /^[\=\!\>\<\+\-\*\/\%\^\&\|\~]/) {
        return $self->op();
    }
    elsif ($self->{src} =~ s/^(\:)//) {
        return $self->elem(colon => $1);
    }
    elsif ($self->{src} =~ s/^(\,)//) {
        return $self->elem(comma => $1);
    }
    elsif ($self->{src} =~ s/^(\?)//) {
        return $self->elem(what => $1);
    }
    elsif ($self->{src} =~ s/^(\;)//) {
        return $self->elem(term => $1);
    }
    elsif ($self->{src} =~ s/^([\'\"\`])//) {
        return $self->quote($1);
    }
    elsif ($self->{src} =~ s/^([\<\{\[\(])//) {
        my $beg = $1;
        my $end = 
            $beg eq '{' ? '}' :
            $beg eq '(' ? ')' :
            $beg eq '<' ? '>' :
            $beg eq '[' ? ']' : '';
        my @def = $self->elem(block => $beg);
        my $symb = $self->inner({@def}, $end) || return;

        return
            @def,
            beg => $beg,
            end => $end,
            symb=> $symb;
    }

    my $s = substr($self->{src}, 0, 10);
    
    return $self->err('Unknow symbol: %s...', $s);
}

sub dig {
    my $self = shift;

    my @r;
    if ($self->{src} =~ s/^(0x[\da-fA-F]+)//) {
        @r = $self->elem(dighex => $1);
    }
    elsif ($self->{src} =~ s/^([01]+b)//) {
        @r = $self->elem(digbin => $1);
    }
    elsif ($self->{src} =~ s/^(\d*(\.\d+)?)//) {
        my $type = $2 ? 'digfloat' : 'digint';
        @r = $self->elem($type => $1);
    }
    else {
        return $self->err('Unknow dig symbol');
    }

    if ($self->{src} =~ /^[a-zA-Z\_]/) {
        return $self->err('Unknow symbol after digits');
    }

    return @r;
}

sub op {
    my $self = shift;

    my @r;
    if ($self->{src} =~ s/^([\!\=]=)//) {
        @r = $self->elem(opeq => $1);
    }
    elsif ($self->{src} =~ s/^([\<\>]=?)//) {
        @r = $self->elem(opcmp => $1);
    }
    elsif ($self->{src} =~ s/^([\-\+\*\/]?=)//) {
        @r = $self->elem(opset => $1);
    }
    elsif ($self->{src} =~ s/^(\+\+|\-\-|[\-\+\*\/])//) {
        @r = $self->elem(opint => $1);
    }
    else {
        return $self->err('Unknow op symbol');
    }

    if ($self->{src} =~ /^[\=\!\>\<\+\-\*\/\%\^\&\|\~]/) {
        return $self->err('Unknow symbol after operation');
    }

    return @r;
}

sub quote {
    my $self = shift;
    my $q = shift() || return;

    my $row = $self->{row};
    my $col = $self->{col};
    my $str = '';

    $self->incpos($q);

    while ($self->{src} ne '') {
        if (substr($self->{src}, 0, length($q)) eq $q) {
            substr($self->{src}, 0, length($q)) = '';
            $self->incpos($q);

            return
                type    => 'str',
                str     => $str,
                quote   => $q,
                row     => $row,
                col     => $col;
        }
        elsif (
                (length($self->{src}) >= 2) &&
                (substr($self->{src}, 0, 1) eq '\\') &&
                (substr($self->{src}, 1, length($q)) eq $q)
            ) {
            $str .= $q;
            $self->incpos(substr($self->{src}, 0, 1 + length($q)));
            substr($self->{src}, 0, 1 + length($q)) = '';
        }
        elsif ($self->{src} =~ s/^(\s+)//) {
            $str .= $1;
            $self->incpos($1);
        }
        else {
            my $s = substr($self->{src}, 0, 1);
            substr($self->{src}, 0, 1) = '';
            $self->incpos($s);
            $str .= $s;
        }
    }

    return $self->err('Unexpected end of quote, beginned at: row=%d, col=%s', $row, $col);
}

1;
