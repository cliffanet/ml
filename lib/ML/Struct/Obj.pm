package ML::Struct::Obj;

use strict;
use warnings;

my $err;

sub parse {
    shift() if $_[0] && ($_[0] eq __PACKAGE__);
    
    undef $err;

    my $self = {};
    bless $self, __PACKAGE__;

    my $obj = $self->init(@_);
    if (!$obj) {
        $err = $self->err();
        return;
    }

    return @$obj;
}

sub err {
    return $err if !@_ || !ref($_[0]);

    my $self = shift;

    if (@_) {
        my $symb = ref($_[0]) ? shift() : shift(@{ $self->{symb}||[] });
        @_ || return;

        my $s = shift;

        if (@_) {
            $s = sprintf $s, @_;
        }

        $self->{err} = 
            $symb ? {
                row => $symb->{row},
                col => $symb->{col},
                str => sprintf('[row: %d, col: %d] %s', $symb->{row}, $symb->{col}, $s)
            } : {
                str => $s
            };

        return;
    }

    exists( $self->{err} ) || return;

    return $self->{err}->{str};
}

sub init {
    my $self = shift;
    
    $self->{symb} = [@_];
    delete $self->{obj};
    delete $self->{err};

    my $obj = $self->inner($self->{symb}) || return;
    return $self->{obj} = $obj;
}

sub inner {
    my $self = shift;
    my $list = shift() || return;
    
    my @obj = ();

    while (my $s = shift @$list) {
        if ($s->{type} eq 'name') {
            my $obj = $self->begname($s, $list, @_) || return;
            push @obj, ref($obj) eq 'ARRAY' ? @$obj : $obj;
        }
        else {
            return $self->err($s, '`%s` not allowed here', $s->{type});
        }
    }

    return [@obj];
}

sub begname {
    my $self = shift;
    my $f = shift() || return;
    my $list = shift() || return;

    my $s = shift(@$list)
        || return $self->err($f, 'Unknown name at end of file');

    my $obj = {
        row     => $s->{row},
        col     => $s->{col},
    };
    
    if (($s->{type} eq 'block') && ($s->{str} eq '(')) {
        # call func
        $obj->{type} = 'call';
        $obj->{name} = $f->{str};
        $obj->{arg}  = $self->funcarg($s) || return;

        my $t = shift @$list;
        if ($t && ($t->{type} ne 'term')) {
            return $self->err($t, 'Need terminator ";" at end of function call');
        }
    }

    elsif ($s->{type} eq 'name') {
        # define
        $obj->{type} = 'define';
        unshift @$list, $s;
        return $self->definition($f, $list);
    }

    elsif ($s->{type} eq 'opset') {
        $obj->{type} = 'varset';
        $obj->{name} = $f->{str};
        $obj->{expr} = $self->expression($list) || return;
        my $t = shift @$list;
        if ($t && ($t->{type} ne 'term')) {
            return $self->err($t, '`%s` not allowed here: need termination(;)', $t->{type});
        }
    }

    else {
        return $self->err($s, '`%s` not allowed after literal', $s->{type});
    }
    
    return $obj;
}

sub expression {
    my $self = shift;
    my $list = shift() || return;

    my @symb = ();
    my $p;
    while (my $s = shift @$list) {
        if ($s->{type} =~ /^op(eq|cmp|int)/) {
            if (!@symb && !(($s->{type} eq 'opint') && (($s->{str} eq '+') || ($s->{str} eq '-')))) {
                return $self->err($s, 'Not allowed `%s` for unary operation', $s->{str});
            }
        }
        elsif (($s->{type} eq 'block') && ($s->{str} eq '(')) {
            my $l = [@{ $s->{symb} }];
            my $symb = $self->expression($l) || return;
            if (!@$symb) {
                return $self->err($s, 'Empty expression');
            }
            if (my ($s) = @$l) {
                return $self->err($s, '`%s` not allowed in expression', $s->{type});
            }
        }
        elsif (($s->{type} =~ /^dig/) || ($s->{type} eq 'str')) {
            if ($p && (!$p->{type} !~ /^op/)) {
                return $self->err($s, 'Need operator before operand');
            }
        }
        elsif ($s->{type} eq 'name') {
            if ($p && (!$p->{type} !~ /^op/)) {
                return $self->err($s, 'Need operator before operand');
            }
            my ($n) = @$list;
            if ($n && ($n->{type} eq 'block') && ($n->{str} eq '(')) {
                my $arg = $self->funcarg(shift(@$list)) || return;
                $s = {
                    %$s,
                    type    => 'call',
                    arg     => $arg
                };
            }
            else {
                $s = {
                    %$s,
                    type    => 'var',
                    name    => $s->{str}
                };
            }
        }
        else {
            unshift @$list, $s;
            last;
        }

        push @symb, $s;
    }

    if ($p && $p->{type} =~ /^op/) {
        return $self->err($p, 'Need value after operation');
    }

    return [@symb];
}

sub funcarg {
    my $self = shift;
    my $sblck = shift();

    if (!$sblck) {
        return $self->err('Need arg list for call');
    }
    if (($sblck->{type} ne 'block') || ($sblck->{str} ne '(')) {
        return $self->err($sblck, 'Need arg list for call');
    }
    my $list = [ @{ $sblck->{symb}||[] } ];

    my @arg = ();
    while (@$list) {
        my $e = $self->expression($list) || return;
        push @arg, $e;

        my $s = shift(@$list) || last;
        if ($s->{type} ne 'comma') {
            return $self->err($s, '`%s` not allowed here: for next arg need `comma`', $s->{type});
        }
        if (!@$list) {
            return $self->err($s, 'Not allowed empty expression after `comma`');
        }
    }

    return [@arg];
}

sub funcdef {
    my $self = shift;
    my $sblck = shift();

    if (!$sblck) {
        return $self->err('Need arg list defining');
    }
    if (($sblck->{type} ne 'block') || ($sblck->{str} ne '(')) {
        return $self->err($sblck, 'Need arg list defining');
    }
    my $list = [ @{ $sblck->{symb}||[] } ];

    my @arg = ();
    while (@$list) {
        my $t = shift @$list;
        if ($t->{type} ne 'name') {
            return $self->err($t, '`%s` not allowed here: need arg-type', $t->{type});
        }

        my $v = shift @$list;
        if (!$v) {
            return $self->err($t, 'Need arg-name');
        }
        if ($v->{type} ne 'name') {
            return $self->err($v, '`%s` not allowed here: need arg-name', $v->{type});
        }

        my $s = shift(@$list) || last;
        if ($s->{type} ne 'comma') {
            return $self->err($s, '`%s` not allowed here: for next arg need `comma`', $s->{type});
        }
        if (!@$list) {
            return $self->err($s, 'Not allowed empty expression after `comma`');
        }
    }

    return [@arg];
}

sub definition {
    my $self = shift;
    my $t = shift() || return;
    my $list = shift() || return;

    my @def = ();

    my $e = $t;
    while (1) {
        my $s = shift @$list;
        if (!$s) {
            return $self->err($e, 'Need variable name here');
        }
        $e = $s;
        if ($s->{type} ne 'name') {
            return $self->err($e, '`%s` not allowed here: must be variable name', $s->{type});
        }
        my $def = {
            type    => 'vardef',
            typname => $t->{str},
            name    => $s->{str},
            row     => $s->{row},
            col     => $s->{col},
        };

        my $o = shift @$list;
        if (!@def && $o && ($o->{type} eq 'block') && ($o->{str} eq '(')) {
            $def->{arg} = $self->funcdef($o) || return;

            my $body = shift @$list;
            if (!$body || !(($body->{type} eq 'block') && ($body->{str} eq '{'))) {
                return $self->err($body||$o, 'Need function body here');
            }

            $def->{func} = $self->inner($body->{symb}) || return;
            # при определении функции не может быть запятых и терминатора (;)
            # в конце - тут определяется только одно имя, поэтому сразу выходим.
            return [$def];
        }

        push @def, $def;
        if ($o && ($o->{type} eq 'opset') && ($o->{str} eq '=')) {
            my $symb = $self->expression($list) || return;
            if (!@$symb) {
                return $self->err($o, 'Empty expression');
            }
            $def->{expr} = $symb;
            $o = shift @$list;
        }

        if (!$o || ($o->{type} eq 'term')) {
            last;
        }
        if ($o->{type} eq 'comma') {
            next;
        }

        return $self->err($o);
    }

    return [@def];
}

1;
