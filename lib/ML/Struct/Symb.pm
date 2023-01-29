package ML::Struct::Symb;

use strict;
use warnings;

sub symb_init {
    my $self = shift;
    my $src = shift;
    
    $self->{src} = $src;
    $self->{row} = 1;
    $self->{col} = 1;
    delete $self->{symb};
    delete $self->{err};

    my $symb = $self->symb_inner() || return;
    $self->{symb} = $symb;

    return 1;
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

sub symbdef {
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

sub symb_inner {
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
        return $self->symbdef(space => $1);
    }
    elsif ($self->{src} =~ s/^([a-zA-Z_][a-zA-Z0-9_]*)//) {
        return $self->symbdef(name => $1);
    }
    elsif ($self->{src} =~ /^\.?\d/) {
        return $self->symb_dig();
    }
    elsif ($self->{src} =~ /^[\=\!\>\<\+\-\*\/\%\^\&\|\~]/) {
        return $self->symb_op();
    }
    elsif ($self->{src} =~ s/^(\:)//) {
        return $self->symbdef(colon => $1);
    }
    elsif ($self->{src} =~ s/^(\,)//) {
        return $self->symbdef(comma => $1);
    }
    elsif ($self->{src} =~ s/^(\?)//) {
        return $self->symbdef(what => $1);
    }
    elsif ($self->{src} =~ s/^(\;)//) {
        return $self->symbdef(term => $1);
    }
    elsif ($self->{src} =~ s/^([\'\"\`])//) {
        return $self->symb_quote($1);
    }
    elsif ($self->{src} =~ s/^([\<\{\[\(])//) {
        my $beg = $1;
        my $end = 
            $beg eq '{' ? '}' :
            $beg eq '(' ? ')' :
            $beg eq '<' ? '>' :
            $beg eq '[' ? ']' : '';
        my @def = $self->symbdef(block => $beg);
        my $symb = $self->symb_inner({@def}, $end) || return;

        return
            @def,
            beg => $beg,
            end => $end,
            symb=> $symb;
    }

    my $s = substr($self->{src}, 0, 10);
    
    return $self->err('Unknow symbol: %s...', $s);
}

sub symb_dig {
    my $self = shift;

    my @r;
    if ($self->{src} =~ s/^(0x[\da-fA-F]+)//) {
        @r = $self->symbdef(dighex => $1);
    }
    elsif ($self->{src} =~ s/^([01]+b)//) {
        @r = $self->symbdef(digbin => $1);
    }
    elsif ($self->{src} =~ s/^(\d*(\.\d+)?)//) {
        my $type = $2 ? 'float' : 'digint';
        @r = $self->symbdef($type => $1);
    }
    else {
        return $self->err('Unknow dig symbol');
    }

    if ($self->{src} =~ /^[a-zA-Z\_]/) {
        return $self->err('Unknow symbol after digits');
    }

    return @r;
}

sub symb_op {
    my $self = shift;

    my @r;
    if ($self->{src} =~ s/^([\!\=]=)//) {
        @r = $self->symbdef(opeq => $1);
    }
    elsif ($self->{src} =~ s/^([\<\>]=?)//) {
        @r = $self->symbdef(opcmp => $1);
    }
    elsif ($self->{src} =~ s/^([\-\+\*\/]?=)//) {
        @r = $self->symbdef(opset => $1);
    }
    elsif ($self->{src} =~ s/^(\+\+|\-\-|[\-\+\*\/])//) {
        @r = $self->symbdef(opint => $1);
    }
    else {
        return $self->err('Unknow op symbol');
    }

    if ($self->{src} =~ /^[\=\!\>\<\+\-\*\/\%\^\&\|\~]/) {
        return $self->err('Unknow symbol after operation');
    }

    return @r;
}

sub symb_quote {
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
