#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

use MaatkitTest;

# See 101_slowlog_analyses.t or http://code.google.com/p/maatkit/wiki/Testing
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift

$ENV{LABEL_WIDTH} = 9;  

require "$trunk/mk-query-digest/mk-query-digest";

my @args   = qw(--type tcpdump --report-format=query_report --limit 10);
my $sample = "$trunk/common/t/samples/";

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'tcpdump003.txt') },
      "mk-query-digest/t/samples/tcpdump003.txt"
   ),
   'Analysis for tcpdump003 with numeric Error_no'
);

# #############################################################################
# Issue 228: parse tcpdump.
# #############################################################################
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'tcpdump002.txt') },
      "mk-query-digest/t/samples/tcpdump002_report.txt"
   ),
   'Analysis for tcpdump002',
);

# #############################################################################
# Issue 398: Fix mk-query-digest to handle timestamps that have microseconds
# #############################################################################
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'tcpdump017.txt',
         '--report-format', 'header,query_report,profile') },
      "mk-query-digest/t/samples/tcpdump017_report.txt"
   ),
   'Analysis for tcpdump017 with microsecond timestamps (issue 398)'
);

# #############################################################################
# Done.
# #############################################################################
exit;
