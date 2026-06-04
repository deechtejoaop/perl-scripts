#!/usr/bin/env perl

# A simple perl program to decode email format.
# Author: J. P. Rodrigues <deechtejoao@gmail.com>

use warnings;
use strict;

my @array;
open(my $fh, "<", "email.txt")
    or die "Failed to open file $!\n";
while(<$fh>) {
    chomp;
    push @array, $_;
}
close $fh;

my $arrSize = scalar @array;
print "Email list size: $arrSize\n\n";

for (my $count = 0 ; $count != scalar @array ; $count++)
{
    my $str;
    $str = $array[$count];
    $str =~ s/at/@/g;
    $str =~ s/dot/./g;
    $str =~ s/\s*//g;
    print("$str \n");
}

