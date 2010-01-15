#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use MaatkitTest;

my $output;

# #############################################################################
# Test that --group-by cascades to --order-by.
# #############################################################################
$output = `$trunk/mk-query-digest/mk-query-digest --group-by foo,bar --help`;
like($output, qr/--order-by\s+Query_time:sum,Query_time:sum/,
   '--group-by cascades to --order-by');

$output = `$trunk/mk-query-digest/mk-query-digest --no-report --help 2>&1`;
like(
   $output,
   qr/--group-by\s+fingerprint/,
   "Default --group-by with --no-report"
);

# #############################################################################
# Done.
# #############################################################################
exit;
