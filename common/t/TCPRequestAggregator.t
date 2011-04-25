#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 5;

use TCPRequestAggregator;
use MaatkitTest;

my $p;

# Check that I can parse a simple log and aggregate it into 100ths of a second
$p = new TCPRequestAggregator(interval => '.01', quantile => '.99');
# intervals.
test_log_parser(
   parser => $p,
   file   => 'common/t/samples/simpletcp-requests001.txt',
   result => [
      {  ts            => '1301957863.82',
         concurrency   => '0.346932',
         throughput    => '1800.173395',
         arrivals      => 18,
         completions   => 17,
         busy_time     => '0.002861',
         weighted_time => '0.003469',
         sum_time      => '0.003492',
         variance_mean => '0.000022',
         quantile_time => '0.000321',
         obs_time      => '0.009999',
         pos_in_log    => 0,
      },
      {  ts            => '1301957863.83',
         concurrency   => '1.646735',
         throughput    => '1600.001526',
         arrivals      => 16,
         completions   => 15,
         busy_time     => '0.010000',
         weighted_time => '0.016467',
         sum_time      => '0.011227',
         variance_mean => '0.004070',
         quantile_time => '0.007201',
         obs_time      => '0.010000',
         pos_in_log    => 1296,
      },
   ],
);

# Check that I can parse a log whose first event is ID = 0, and whose events all
# fit within one time interval.
$p = new TCPRequestAggregator(interval => '.01', quantile => '.99');
test_log_parser(
   parser => $p,
   file   => 'common/t/samples/simpletcp-requests002.txt',
   result => [
      {  ts            => '1301957863.82',
         concurrency   => '0.353948',
         throughput    => '1789.648311',
         arrivals      => 17,
         completions   => 17,
         busy_time     => '0.002754',
         weighted_time => '0.003362',
         variance_mean => '0.000022',
         sum_time      => '0.003362',
         quantile_time => '0.000321',
         obs_time      => '0.009499',
         pos_in_log    => 0,
      },
   ],
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $p->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
