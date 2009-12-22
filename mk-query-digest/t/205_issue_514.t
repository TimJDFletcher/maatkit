#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

my $run_with = '../mk-query-digest --report-format=query_report --limit 10 ../../common/t/samples/';
my $cmd;
my $output;

# #############################################################################
# Issue 514: mk-query-digest does not create handler sub for new auto-detected
# attributes
# #############################################################################
# This issue actually introduced --check-attributes-limit.
$cmd = "${run_with}slow030.txt";
$output = `$cmd --check-attributes-limit 100 2>&1`;
unlike(
   $output,
   qr/IDB IO rb/,
   '--check-attributes-limit (issue 514)'
);

# #############################################################################
# Done.
# #############################################################################
exit;
