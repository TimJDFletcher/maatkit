#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 1;
use English qw(-no_match_vars);

my $cmd = "perl ../mk-log-parser ../../common/t/samples/";

# Each test file is self-contained.  It has the command-line at the top of the
# file and the results below.
foreach my $file ( <test_*> ) {
   my $result = `./run_test $file`;
   chomp $result;
   is($result, '', $file);
}
