#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

use Transformers;
use QueryReview;
use QueryRewriter;
use MySQLDump;
use TableParser;
use Quoter;
use SlowLogParser;
use OptionParser;
use DSNParser;
use Sandbox;
use MaatkitTest;

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
$sb->create_dbs($dbh, ['test']);
$sb->load_file('master', "common/t/samples/query_review.sql");

my $qr = new QueryRewriter();
my $lp = new SlowLogParser;
my $q  = new Quoter();
my $tp = new TableParser(Quoter => $q);
my $du = new MySQLDump();
my $opt_parser = new OptionParser( description => 'hi' );
my $tbl_struct = $tp->parse(
   $du->get_create_table($dbh, $q, 'test', 'query_review'));

my $qv = new QueryReview(
   dbh        => $dbh,
   db_tbl     => '`test`.`query_review`',
   tbl_struct => $tbl_struct,
   ts_default => '"2009-01-01"',
   quoter     => $q,
);

isa_ok($qv, 'QueryReview');

my $callback = sub {
   my ( $event ) = @_;
   my $fp = $qr->fingerprint($event->{arg});
   $qv->set_review_info(
      fingerprint => $fp,
      sample      => $event->{arg},
      first_seen  => $event->{ts},
      last_seen   => $event->{ts},
   );
};

my $event       = {};
my $more_events = 1;
my $log;
open $log, '<', "$trunk/common/t/samples/slow006.txt" or die $OS_ERROR;
while ( $more_events ) {
   $event = $lp->parse_event(
      next_event => sub { return <$log>;    },
      tell       => sub { return tell $log; },
      oktorun    => sub { $more_events = $_[0]; },
   );
   $callback->($event) if $event;
}
close $log;
$more_events = 1;
open $log, '<', "$trunk/common/t/samples/slow021.txt" or die $OS_ERROR;
while ( $more_events ) {
   $event = $lp->parse_event(
      next_event => sub { return <$log>;    },
      tell       => sub { return tell $log; },
      oktorun    => sub { $more_events = $_[0]; },
   );
   $callback->($event) if $event;
}
close $log;

my $res = $dbh->selectall_arrayref(
   'SELECT checksum, first_seen, last_seen FROM query_review order by checksum',
   { Slice => {} });
is_deeply(
   $res,
   [  {  checksum   => '4222630712410165197',
         last_seen  => '2007-10-15 21:45:10',
         first_seen => '2007-10-15 21:45:10'
      },
      {  checksum   => '9186595214868493422',
         last_seen  => '2009-01-01 00:00:00',
         first_seen => '2009-01-01 00:00:00'
      },
      {  checksum   => '11676753765851784517',
         last_seen  => '2007-12-18 11:49:30',
         first_seen => '2007-12-18 11:48:27'
      },
      {  checksum   => '15334040482108055940',
         last_seen  => '2007-12-18 11:49:07',
         first_seen => '2005-12-19 16:56:31'
      }
   ],
   'Updates last_seen'
);

$event = {
   arg => "UPDATE foo SET bar='nada' WHERE 1",
   ts  => '081222 13:13:13',
};
my $fp = $qr->fingerprint($event->{arg});
my $checksum = Transformers::make_checksum($fp);
$qv->set_review_info(
   fingerprint => $fp,
   sample      => $event->{arg},
   first_seen  => $event->{ts},
   last_seen   => $event->{ts},
);

$res = $qv->get_review_info($fp);
is_deeply(
   $res,
   {
      checksum_conv => 'D3A1C1CD468791EE',
      first_seen    => '2008-12-22 13:13:13',
      last_seen     => '2008-12-22 13:13:13',
      reviewed_by   => undef,
      reviewed_on   => undef,
      comments      => undef,
   },
   'Stores a new event with default values'
);

is_deeply([$qv->review_cols],
   [qw(first_seen last_seen reviewed_by reviewed_on comments)],
   'review columns');

# ##############################################################################
# Test review history stuff
# ##############################################################################
my $pat = $opt_parser->read_para_after("$trunk/mk-query-digest/mk-query-digest",
   qr/MAGIC_history_cols/);
$pat =~ s/\s+//g;
my $create_table = $opt_parser->read_para_after(
   "$trunk/mk-query-digest/mk-query-digest", qr/MAGIC_create_review_history/);
$create_table =~ s/query_review_history/test.query_review_history/;
$dbh->do($create_table);
my $hist_struct = $tp->parse(
   $du->get_create_table($dbh, $q, 'test', 'query_review_history'));

$qv->set_history_options(
   table      => 'test.query_review_history',
   dbh        => $dbh,
   quoter     => $q,
   tbl_struct => $hist_struct,
   col_pat    => qr/^(.*?)_($pat)$/,
);

$qv->set_review_history(
   'foo',
   'foo sample',
   Query_time => {
      pct    => 1/3,
      sum    => '0.000682',
      cnt    => 1,
      min    => '0.000682',
      max    => '0.000682',
      avg    => '0.000682',
      median => '0.000682',
      stddev => 0,
      pct_95 => '0.000682',
   },
   ts => {
      min => '090101 12:39:12',
      max => '090101 13:19:12',
      cnt => 1,
   },
);

$res = $dbh->selectall_arrayref(
   'SELECT * FROM test.query_review_history',
   { Slice => {} });
is_deeply(
   $res,
   [  {  checksum          => '17145033699835028696',
         sample            => 'foo sample',
         ts_min            => '2009-01-01 12:39:12',
         ts_max            => '2009-01-01 13:19:12',
         ts_cnt            => 1,
         Query_time_sum    => '0.000682',
         Query_time_min    => '0.000682',
         Query_time_max    => '0.000682',
         Query_time_median => '0.000682',
         Query_time_stddev => 0,
         Query_time_pct_95 => '0.000682',
         Lock_time_sum        => undef,
         Lock_time_min        => undef,
         Lock_time_max        => undef,
         Lock_time_pct_95     => undef,
         Lock_time_stddev     => undef,
         Lock_time_median     => undef,
         Rows_sent_sum        => undef,
         Rows_sent_min        => undef,
         Rows_sent_max        => undef,
         Rows_sent_pct_95     => undef,
         Rows_sent_stddev     => undef,
         Rows_sent_median     => undef,
         Rows_examined_sum    => undef,
         Rows_examined_min    => undef,
         Rows_examined_max    => undef,
         Rows_examined_pct_95 => undef,
         Rows_examined_stddev => undef,
         Rows_examined_median => undef,
      },
   ],
   'Review history information is in the DB',
);

eval {
   $qv->set_review_history(
      'foo',
      'foo sample',
      ts => {
         min => undef,
         max => undef,
         cnt => 1,
      },
   );
};
is($EVAL_ERROR, '', 'No error on undef ts_min and ts_max');

$sb->wipe_clean($dbh);
