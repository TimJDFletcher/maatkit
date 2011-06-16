#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-insert-normalized/mk-insert-normalized";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 7;
}

my $in  = "mk-insert-normalized/t/samples/";
my $out = "mk-insert-normalized/t/samples/";
my $output;
my $cnf = '/tmp/12345/my.sandbox.cnf';

$sb->create_dbs($dbh, ['test']);
$sb->load_file('master', "common/t/samples/mysqldump-no-data/dump002.txt", "test");
$sb->load_file('master', "$in/raw-data.sql", "test");

$dbh->do('use test');

my $rows = $dbh->selectall_arrayref('select * from data_report, entity, data');
is_deeply(
   $rows,
   [],
   'Dest tables data_report, entity, and data are empty'
);

$rows = $dbh->selectall_arrayref('select * from raw_data order by date');
is_deeply(
   $rows,
   [
      ['2011-06-01', 101, 'ep1-1', 'ep2-1', 'd1-1', 'd2-1'],
      ['2011-06-02', 102, 'ep1-2', 'ep2-2', 'd1-2', 'd2-2'],
      ['2011-06-03', 103, 'ep1-3', 'ep2-3', 'd1-3', 'd2-3'],
      ['2011-06-04', 104, 'ep1-4', 'ep2-4', 'd1-4', 'd2-4'],
      ['2011-06-05', 105, 'ep1-5', 'ep2-5', 'd1-5', 'd2-5'],
   ],
   'Source table raw_data has data'
);

ok(
   no_diff(
      sub { mk_insert_normalized::main(
         '--source', "F=$cnf,D=test,t=raw_data",
         '--dest',   "t=data",
         '--constant-values', "$trunk/mk-insert-normalized/t/samples/raw-data-const-vals.txt",
         qw(--print --execute)) },
      "$out/raw-data.txt",
      sed => [
         "-e 's/pid:[0-9]*/pid:0/g' -i.bak",
         "-e 's/user:[a-z]*/user:test/g' -i.bak",
      ],
   ),
   "Normalize raw_data"
);

is_deeply(
   $dbh->selectall_arrayref('select * from raw_data order by date'),
   $rows,
   "Source table not modified"
);

$rows = $dbh->selectall_arrayref('select * from data_report order by id');
is_deeply(
   $rows,
   [
      [1, '2011-06-01', '2011-06-15 00:00:00', '2011-06-14 00:00:00'],
      [2, '2011-06-02', '2011-06-15 00:00:00', '2011-06-14 00:00:00'],
      [3, '2011-06-03', '2011-06-15 00:00:00', '2011-06-14 00:00:00'],
      [4, '2011-06-04', '2011-06-15 00:00:00', '2011-06-14 00:00:00'],
      [5, '2011-06-05', '2011-06-15 00:00:00', '2011-06-14 00:00:00'],
   ],
   'data_report rows'
);

$rows = $dbh->selectall_arrayref('select * from entity order by id');
is_deeply(
   $rows,
   [
      [1, 'ep1-1', 'ep2-1'],
      [2, 'ep1-2', 'ep2-2'],
      [3, 'ep1-3', 'ep2-3'],
      [4, 'ep1-4', 'ep2-4'],
      [5, 'ep1-5', 'ep2-5'],
   ],
   'entity rows'
);

$rows = $dbh->selectall_arrayref('select * from data order by data_report');
is_deeply(
   $rows,
   [
      [1, 101, 1, 'd1-1', 'd2-1'],
      [2, 102, 2, 'd1-2', 'd2-2'],
      [3, 103, 3, 'd1-3', 'd2-3'],
      [4, 104, 4, 'd1-4', 'd2-4'],
      [5, 105, 5, 'd1-5', 'd2-5'],
   ],
   'data row'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
