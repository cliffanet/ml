#!/usr/bin/perl

use strict;
use warnings;
use utf8;

my $libdir;
BEGIN {
    $libdir = $0;
    $libdir =~ s/\/?[^\/\\]+$//;
    $libdir = '.' if $libdir eq '';
    $libdir .= '/lib';
}
use lib $libdir;

use ML::Struct;

my $src;

if (@ARGV != 1) {
    my $f = $0 =~ /([^\/\\]+)$/ ? $1 : $0;
    print STDERR "Usage:\n\t$f <src-file>\n";
    exit -1;
}

my $fname = $ARGV[0];
if (open my $fh, $fname) {
    local $/ = undef;
    $src = <$fh>;
    close $fh;
}
else {
    print STDERR 'Can\'t open file \''.$fname.'\': ' . $! . "\n";
    exit -1;
}

my $bld = ML::Struct->new($src);

if (my %p = $bld->err()) {
    print STDERR '>> [line: '.$p{line}.', pos: '.$p{pos}.'] '.$p{text}."\n";
    exit -1;
}

use Data::Dumper;
print Dumper $bld->{root};
