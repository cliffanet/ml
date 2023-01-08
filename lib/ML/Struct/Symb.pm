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

    my $symb = $self->symb_root() || return;
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

sub skipspace {
    my $self = shift;

    return '' if $self->{src} !~ s/^(\s+)//;

    my $s = $1;
    $self->incpos($s);

    return $s;
}

sub skipsym {
    my $self = shift;
    my $len = shift() || return;

    my $s = substr($self->{src}, 0, $len);

    substr($self->{src}, 0, $len) = '';
    $self->incpos($s);

    return $s;
}

sub nextsym {
    my $self = shift;

    my $type =
        $self->{src} =~ /^([a-zA-Z_][a-zA-Z0-9_]*)/ ?
            'name' :
        $self->{src} =~ /^([\<\{\[\(])/ ?
            'blockbeg' :
        $self->{src} =~ /^([\>\}\]\)])/ ?
            'blockend' :
        $self->{src} =~ /^([\'\"\`])/ ?
            'quote' :
        $self->{src} =~ /^([0-9]*\.[0-9]+)([^a-zA-Z_]|$)/ ?
            'digfloat' :
        $self->{src} =~ /^([0-9]+)([^a-zA-Z_]|$)/ ?
            'digdec' :
        $self->{src} =~ /^(0x[0-9a-fA-F]+)([^a-zA-Z_]|$)/ ?
            'dighex' :
        $self->{src} =~ /^([01]+b)([^a-zA-Z_]|$)/ ?
            'digbin' :
        $self->{src} =~ /^(;)/ ?
            'term' :
        $self->{src} =~ /^([\=\!]\=|[\>\<]\=?)([^|!\#\$\%\^\&\*\~\:\\\/\?\=\-]|$)/ ?
            'opcomp' :
        $self->{src} =~ /^(([\+\-\*\/\%\^\&\|]|\&\&|\|\|)?\=)([^|!\#\$\%\^\&\*\~\:\\\/\?\=\-]|$)/ ?
            'opset' :
        $self->{src} =~ /^([!\~])([^|!\#\$\%\^\&\*\~\:\\\/\?\=\-]|$)/ ?
            'opunary' :
        $self->{src} =~ /^(\,)/ ?
            'comma' :
        $self->{src} =~ /^(\.)/ ?
            'dot' :
        $self->{src} =~ /^(\?)/ ?
            'what' :
        $self->{src} =~ /^(\:)/ ?
            'colon' :
            '';
    
    $type || return $self->err('Unknow symbol');
    my $s = $1;

    return
        type    => $type,
        str     => $s;
}

sub symb_root {
    my $self = shift;

    $self->skipspace();

    my @symb = ();

    while ($self->{src} ne '') {
        my %n = $self->nextsym();
        %n || return;

        if ($n{type} eq 'blockbeg') {
            my $el = $self->symb_block(%n) || return;
            push @symb, $el;
        }
        elsif ($n{type} eq 'blockend') {
            return $self->err('Unexpected block end');
        }
        elsif ($n{type} eq 'quote') {
            my $el = $self->symb_quote(%n) || return;
            push @symb, $el;
        }
        else {
            push @symb, {
                row => $self->{row},
                col => $self->{col},
                %n
            };
            $self->skipsym(length $n{str});
        }

        $self->skipspace();
    }

    return [@symb];
}

sub symb_block {
    my $self = shift;
    my %n = @_;

    my $beg = {
        symb => $n{str},
        row => $self->{row},
        col => $self->{col},
    };
    my $symend =
        $n{str} eq '{' ? '}' :
        $n{str} eq '(' ? ')' :
        $n{str} eq '<' ? '>' :
        $n{str} eq '[' ? ']' : '';
    
    $symend || return $self->err('Unknown block type');

    $self->skipsym(length $n{str});
    $self->skipspace();

    my @symb = ();

    while ($self->{src} ne '') {
        my %n = $self->nextsym();
        %n || return;

        if ($n{type} eq 'blockbeg') {
            my $el = $self->symb_block(%n) || return;
            push @symb, $el;
        }
        elsif ($n{type} eq 'blockend') {
            if ($n{str} eq $symend) {
                my $end = {
                    symb => $n{str},
                    row => $self->{row},
                    col => $self->{col},
                };
                $self->skipsym(length $n{str});

                return {
                    type    => 'block',
                    beg     => $beg,
                    end     => $end,
                    symb    => [@symb],
                };
            }

            return $self->err('Unexpected block end');
        }
        elsif ($n{type} eq 'quote') {
            my $el = $self->symb_quote(%n) || return;
            push @symb, $el;
        }
        else {
            push @symb, {
                row => $self->{row},
                col => $self->{col},
                %n
            };
            $self->skipsym(length $n{str});
        }

        $self->skipspace();
    }

    return $self->err('Unexpected end of block, beginned at: row=%d, col=%s', $beg->{row}, $beg->{col});
}

sub symb_quote {
    my $self = shift;
    my %n = @_;

    my $beg = {
        symb => $n{str},
        row => $self->{row},
        col => $self->{col},
    };
    my $symend = $n{str};
    $self->skipsym(length $n{str});

    my @symb = ();
    my $static = '';

    while ($self->{src} ne '') {
        if (substr($self->{src}, 0, length $symend) eq $symend) {
            push @symb, $static;
            my $end = {
                symb => $symend,
                row => $self->{row},
                col => $self->{col},
            };
            $self->skipsym(length $symend);

            return {
                type    => 'str',
                beg     => $beg,
                end     => $end,
                symb    => [@symb],
            };
        }
        elsif (
                (length($self->{src}) >= 2) &&
                (substr($self->{src}, 0, 1) eq '\\') &&
                (substr($self->{src}, 1, length $symend) eq $symend)
            ) {
            $static .= $symend;
            $self->skipsym(1 + length($symend));
        }
        else {
            $static .= $self->skipsym(1);
        }
    }

    return $self->err('Unexpected end of quote, beginned at: row=%d, col=%s', $beg->{row}, $beg->{col});
}

1;
