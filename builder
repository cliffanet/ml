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

my @obj = ML::Struct->parse($src);

if (my $err = ML::Struct->err()) {
    print STDERR '>> '.$err."\n";
    exit -1;
}

use Data::Dumper;
print Dumper \@obj;
