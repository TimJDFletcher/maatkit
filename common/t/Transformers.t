#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 37;

BEGIN {
   # The timestamps for unix_timestamp are East Coast (EST), so GMT-4.
   $ENV{TZ}='EST5EDT';
   require '../Transformers.pm';
   Transformers->import( qw(parse_timestamp micro_t shorten secs_to_time
   percentage_of unix_timestamp make_checksum any_unix_timestamp) );
};

# #############################################################################
# micro_t() tests.
# #############################################################################
is(micro_t('0.000001'),       "1us",        'Formats 1 microsecond');
is(micro_t('0.001000'),       '1ms',        'Formats 1 milliseconds');
is(micro_t('1.000000'),       '1s',         'Formats 1 second');
is(micro_t('0.123456789999'), '123ms',  'Truncates long value, does not round');
is(micro_t('1.123000000000'), '1s',     'Truncates, removes insignificant zeros');
is(micro_t('0.000000'), '0', 'Zero is zero');
is(micro_t('-1.123'), '0', 'Negative number becomes zero');
is(micro_t('0.9999998', p_ms => 3), '999.999ms', 'ms high edge is not rounded (999.999 ms)');
is(micro_t('.060123', p_ms=>1), '60.1ms', 'Can change float precision for ms in micro_t');
is(micro_t('123.060123', p_s=>1), '123.1s', 'Can change float precision for seconds in micro_t');
 
# #############################################################################
# shorten() tests.
# #############################################################################
is(shorten('1024.00'), '1.00k', 'Shortens 1024.00 to 1.00k');
is(shorten('100'),     '100',   '100 does not shorten (stays 100)');
is(shorten('99999', p => 1, d => 1_000), '100.0k', 'Can change float precision and divisor in shorten');
is(shorten('6.992e+19', 'p', 1, 'd', 1000), '69.9E', 'really big number');
is(shorten('1000e+52'), '8271806125530276833376576995328.00Y', 'Number bigger than any units');
is(shorten('583029', p=>0, d=>1_000), '583k', 'Zero float precision');

# #############################################################################
# secs_to_time() tests.
# #############################################################################
is(secs_to_time(0), '00:00', 'secs_to_time 0 s = 00:00');
is(secs_to_time(60), '01:00', 'secs_to_time 60 s = 1 minute');
is(secs_to_time(3600), '01:00:00', 'secs_to_time 3600 s = 1 hour');
is(secs_to_time(86400), '1+00:00:00', 'secd_to_time 86400 = 1 day');

# #############################################################################
# percentage_of() tests.
# #############################################################################
is(percentage_of(25, 100, p=>2), '25.00', 'Percentage with precision');
is(percentage_of(25, 100), '25', 'Percentage as int');

# #############################################################################
# parse_timestamp() tests.
# #############################################################################
is(parse_timestamp('071015  1:43:52'), '2007-10-15 01:43:52', 'timestamp');
is(parse_timestamp('071015  1:43:52.108'), '2007-10-15 01:43:52.108000',
   'timestamp with microseconds');

# #############################################################################
# unix_timestamp() tests.
# #############################################################################
is(unix_timestamp('2007-10-15 01:43:52'), 1192427032, 'unix_timestamp');
is(unix_timestamp('2009-05-14 12:51:10.001817'), 1242319870, 'unix_timestamp with microseconds');

# #############################################################################
# make_checksum() tests.
# #############################################################################
is(make_checksum('hello world'), '93CB22BB8F5ACDC3', 'make_checksum');

# #############################################################################
# any_unix_timestamp() tests.
# #############################################################################
is(
   any_unix_timestamp('5'),
   time - 5,
   'any_unix_timestamp simple N'
);
is(
   any_unix_timestamp('7s'),
   time - 7,
   'any_unix_timestamp simple Ns'
);
is(
   any_unix_timestamp('7d'),
   time - (7 * 86400),
   'any_unix_timestamp simple 7d'
);
is(
   any_unix_timestamp('071015  1:43:52'),
   unix_timestamp('2007-10-15 01:43:52'),
   'any_unix_timestamp MySQL timestamp'
);
is(
   any_unix_timestamp('071015'),
   unix_timestamp('2007-10-15 00:00:00'),
   'any_unix_timestamp MySQL timestamp without hh:mm:ss'
);
is(
   any_unix_timestamp('2007-10-15 01:43:52'),
   1192427032,
   'any_unix_timestamp proper timestamp'
);
is(
   any_unix_timestamp('2007-10-15'),     # Same as above minus
   1192427032 - (1*3600) - (43*60) - 52, # 1:43:52
   'any_unix_timestamp proper timestamp without hh:mm:ss'
);

require '../DSNParser.pm';
require '../Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');
SKIP: {
   skip 'Cannot connect to sandbox master', 1 unless $dbh;
   my $now = $dbh->selectall_arrayref('SELECT NOW()')->[0]->[0];
   my $callback = sub {
      my ( $sql ) = @_;
      return $dbh->selectall_arrayref($sql)->[0]->[0];
   };
   is(
      any_unix_timestamp('SELECT 42', $callback),
      '42',
      'any_unix_timestamp MySQL expression'
   );

   $dbh->disconnect();
};

is(
   any_unix_timestamp('SELECT 42'),
   undef,
   'any_unix_timestamp MySQL expression but no callback given'
);

is(
   any_unix_timestamp("SELECT '2009-07-27 11:30:00'"),
   undef,
   'any_unix_timestamp MySQL expression that looks like another type'
);


# #############################################################################
# Done.
# #############################################################################
exit;
