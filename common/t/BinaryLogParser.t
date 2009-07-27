#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

require "../BinaryLogParser.pm";

my $p = new BinaryLogParser();

sub run_test {
   my ( $def ) = @_;
   map     { die "What is $_ for?" }
      grep { $_ !~ m/^(?:misc|file|result|num_events)$/ }
      keys %$def;
   my @e;
   my $num_events = 0;
   eval {
      open my $fh, "<", $def->{file} or die $OS_ERROR;
      $num_events++ while $p->parse_event($fh, $def->{misc}, sub { push @e, @_ });
      close $fh;
   };
   is($EVAL_ERROR, '', "No error on $def->{file}");
   if ( defined $def->{result} ) {
      is_deeply(\@e, $def->{result}, $def->{file})
         or print "Got: ", Dumper(\@e);
   }
   if ( defined $def->{num_events} ) {
      is($num_events, $def->{num_events}, "$def->{file} num_events");
   }
}

run_test({
   file => 'samples/binlog001.txt',
   result => [
  {
    '@@session.character_set_client' => '8',
    '@@session.collation_connection' => '8',
    '@@session.collation_server' => '8',
    '@@session.foreign_key_checks' => '1',
    '@@session.sql_auto_is_null' => '1',
    '@@session.sql_mode' => '0',
    '@@session.time_zone' => '\'system\'',
    '@@session.unique_checks' => '1',
    Query_time => '20664',
    Thread_id => '104168',
    arg => 'BEGIN',
    bytes => 5,
    cmd => 'Query',
    end_log_pos => '498006652',
    error_code => '0',
    offset => '498006722',
    pos_in_log => 146,
    server_id => '21',
    timestamp => '1197046970',
    ts => '071207 12:02:50'
  },
  {
    Query_time => '20675',
    Thread_id => '104168',
    arg => 'update test3.tblo as o
         inner join test3.tbl2 as e on o.animal = e.animal and o.oid = e.oid
      set e.tblo = o.tblo,
          e.col3 = o.col3
      where e.tblo is null',
    bytes => 179,
    cmd => 'Query',
    db => 'test1',
    end_log_pos => '278',
    error_code => '0',
    offset => '498006789',
    pos_in_log => 605,
    server_id => '21',
    timestamp => '1197046927',
    ts => '071207 12:02:07'
  },
  {
    Query_time => '20704',
    Thread_id => '104168',
    arg => 'replace into test4.tbl9(tbl5, day, todo, comment)
 select distinct o.tbl5, date(o.col3), \'misc\', right(\'foo\', 50)
      from test3.tblo as o
         inner join test3.tbl2 as e on o.animal = e.animal and o.oid = e.oid
      where e.tblo is not null
         and o.col1 > 0
         and o.tbl2 is null
         and o.col3 >= date_sub(current_date, interval 30 day)',
    bytes => 363,
    cmd => 'Query',
    end_log_pos => '836',
    error_code => '0',
    offset => '498007067',
    pos_in_log => 953,
    server_id => '21',
    timestamp => '1197046928',
    ts => '071207 12:02:08'
  },
  {
    Query_time => '20664',
    Thread_id => '104168',
    arg => 'update test3.tblo as o inner join test3.tbl2 as e
 on o.animal = e.animal and o.oid = e.oid
      set o.tbl2 = e.tbl2,
          e.col9 = now()
      where o.tbl2 is null',
    bytes => 170,
    cmd => 'Query',
    end_log_pos => '1161',
    error_code => '0',
    offset => '498007625',
    pos_in_log => 1469,
    server_id => '21',
    timestamp => '1197046970',
    ts => '071207 12:02:50'
  },
  {
    Xid => '4584956',
    arg => 'COMMIT',
    bytes => 6,
    cmd => 'Query',
    end_log_pos => '498007840',
    offset => '498007950',
    pos_in_log => 1793,
    server_id => '21',
    ts => '071207 12:02:50'
  },
  {
    Query_time => '20661',
    Thread_id => '103374',
    arg => 'insert into test1.tbl6
      (day, tbl5, misccol9type, misccol9, metric11, metric12, secs)
      values
      (convert_tz(current_timestamp,\'EST5EDT\',\'PST8PDT\'), \'239\', \'foo\', \'bar\', 1, \'1\', \'16.3574378490448\')
      on duplicate key update metric11 = metric11 + 1,
         metric12 = metric12 + values(metric12), secs = secs + values(secs)',
    bytes => 341,
    cmd => 'Query',
    end_log_pos => '417',
    error_code => '0',
    offset => '498007977',
    pos_in_log => 1889,
    server_id => '21',
    timestamp => '1197046973',
    ts => '071207 12:02:53'
  },
  {
    Xid => '4584964',
    arg => 'COMMIT',
    bytes => 6,
    cmd => 'Query',
    end_log_pos => '498008284',
    offset => '498008394',
    pos_in_log => 2383,
    server_id => '21',
    ts => '071207 12:02:53'
  },
  {
    Query_time => '20661',
    Thread_id => '103374',
    arg => 'update test2.tbl8
      set last2metric1 = last1metric1, last2time = last1time,
         last1metric1 = last0metric1, last1time = last0time,
         last0metric1 = ondeckmetric1, last0time = now()
      where tbl8 in (10800712)',
    bytes => 228,
    cmd => 'Query',
    end_log_pos => '314',
    error_code => '0',
    offset => '498008421',
    pos_in_log => 2479,
    server_id => '21',
    timestamp => '1197046973',
    ts => '071207 12:02:53'
  },
  {
    Xid => '4584965',
    arg => 'COMMIT',
    bytes => 6,
    cmd => 'Query',
    end_log_pos => '498008625',
    offset => '498008735',
    pos_in_log => 2860,
    server_id => '21',
    ts => '071207 12:02:53'
  },
  {
    arg => 'ROLLBACK /* added by mysqlbinlog */;
/*!50003 SET COMPLETION_TYPE=@OLD_COMPLETION_TYPE*/',
    bytes => 88,
    cmd => 'Query',
    pos_in_log => 3066,
    ts => undef
  }
]
});

# #############################################################################
# Done.
# #############################################################################
exit;
