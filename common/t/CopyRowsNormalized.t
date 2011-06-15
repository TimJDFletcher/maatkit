#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use DSNParser;
use Sandbox;
use OptionParser;
use Quoter;
use TableParser;
use MySQLDump;
use MaatkitTest;
use Schema;
use SchemaIterator;
use ForeignKeyIterator;
use ColumnMap;
use TableNibbler;
use CopyRowsNormalized;

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $src_dbh = $sb->get_dbh_for('master');
my $dst_dbh = $sb->get_dbh_for('master');

if ( !$src_dbh ) {
   plan skip_all => 'Cannot connect to MySQL';
}
else {
   plan tests => 22;
}

my $dbh    = $src_dbh;  # src, dst, doesn't matter for checking the tables
my $output = '';

my $q  = new Quoter;
my $tp = new TableParser(Quoter => $q);
my $du = new MySQLDump();
my $o  = new OptionParser(description => 'SchemaIterator');
$o->get_specs("$trunk/mk-table-checksum/mk-table-checksum");

my $stats = {};

sub make_copier {
   my ( %args ) = @_;

   my $schema   = new Schema();

   my $schema_itr;
   my $si       = new SchemaIterator(
      dbh          => $src_dbh,
      OptionParser => $o,
      Quoter       => $q,
      MySQLDump    => $du,
      TableParser  => $tp,
      Schema       => $schema,
      keep_ddl     => $args{foreign_keys} ? 1 : 0,
   );
   if ( $args{foreign_keys} ) {
      $schema_itr = new ForeignKeyIterator(
         db             => $args{src_db},
         tbl            => $args{src_tbl},
         reverse        => 1,
         SchemaIterator => $si,
         Quoter         => $q,
         TableParser    => $tp,
         Schema         => $schema,
      );
   }
   else {
      $schema_itr = $si;
   }

   # Init the schema qualifier.
   1 while(defined $schema_itr->next_schema_object());

   my $column_map = new ColumnMap(
      src_tbl         => $schema->get_table($args{src_db}, $args{src_tbl}),
      Schema          => $schema,
      constant_values => $args{constant_values},
   );

   my $src = {
      dbh   => $src_dbh,
      tbl   => $schema->get_table($args{src_db}, $args{src_tbl}),
      index => $args{index} || 'PRIMARY',
   };

   my @dst_tbls;
   foreach my $dst_tbl ( @{$args{dst_tbls}} ) {
      push @dst_tbls, $schema->get_table(@$dst_tbl);
   }
   my $dst = {
      dbh  => $dst_dbh,
      tbls => \@dst_tbls,
   };

   $stats = {};

   my $copy_rows = new CopyRowsNormalized(
      src          => $src,
      dst          => $dst,
      ColumnMap    => $column_map,
      Quoter       => $q,
      TableNibbler => new TableNibbler(TableParser => $tp, Quoter => $q),
      stats        => $stats,
      txn_size     => $args{txn_size} || 1,
      foreign_keys => $args{foreign_keys},
   );

   return $copy_rows;
}

# ###########################################################################
# Just a simple table, osc.t, with col id=PK, col c=varchar, and
# a duplicate table osc.__new_t, so all columns map.
# ###########################################################################
$sb->load_file("master", "common/t/samples/osc/tbl001.sql");
@ARGV = qw(-d osc);
$o->get_opts();
my $copy_rows = make_copier(
   src_db   => 'osc',
   src_tbl  => 't',
   dst_tbls => [['osc', '__new_t']],
   txn_size => 2,
);

my $rows = $dbh->selectall_arrayref('select * from osc.__new_t');
is_deeply(
   $rows,
   [],
   'Dest table is empty'
);

$rows = $dbh->selectall_arrayref('select * from osc.t order by id');
is_deeply(
   $rows,
   [ [qw(1 a)], [qw(2 b)], [qw(3 c)], [qw(4 d)], [qw(5 e)] ],
   'Source table has rows'
);

# Copy all rows from osc.t --> osc.__new_t.
$copy_rows->copy();

is_deeply(
   $dbh->selectall_arrayref('select * from osc.t order by id'),
   $rows,
   'Source table not modified'
);

is_deeply(
   $dbh->selectall_arrayref('select * from osc.__new_t'),
   $rows,
   'Dest table has rows'
);

is(
   $stats->{rows_selected},
   5,
   '5 rows selected'
);

is(
   $stats->{rows_inserted},
   5,
   '5 rows inserted'
);

is(
   $stats->{start_transaction},
   3,
   '3 transactions started',
);

is(
   $stats->{commit},
   3,
   '3 transactions commmitted'
);

is(
   $stats->{chunks},
   4,
   '4 chunks'
);

# ###########################################################################
# Copying table a rows to 2 tables: b and c.  a.id doesn't map, so b.b_id
# and c.c_id should auto-inc.  There should be more inserts than fetched rows.
# ###########################################################################
$sb->load_file("master", "common/t/samples/CopyRowsNormalized/tbls001.sql");
@ARGV = qw(-d test);
$o->get_opts();
$copy_rows = make_copier(
   src_db   => 'test',
   src_tbl  => 'a',
   dst_tbls => [['test', 'b'], ['test', 'c']],
   txn_size => 2,
);

$rows = $dbh->selectall_arrayref('select * from test.a order by id');
is_deeply(
   $rows,
   [ [qw(1 a)], [qw(2 b)], [qw(3 c)], [qw(4 d)], [qw(5 e)] ],
   'Source table has rows'
);

# Copy all rows from osc.t --> osc.__new_t.
$copy_rows->copy();

is_deeply(
   $dbh->selectall_arrayref('select * from osc.t order by id'),
   $rows,
   'Source table not modified'
);

is_deeply(
   $dbh->selectall_arrayref('select * from test.b order by b_id'),
   $rows,
   '1st dest table has rows'
);

is_deeply(
   $dbh->selectall_arrayref('select * from test.c order by c_id'),
   $rows,
   '2nd dest table has rows'
);

is(
   $stats->{rows_selected},
   5,
   '5 rows selected'
);

is(
   $stats->{rows_inserted},
   10,
   '10 rows inserted'
);

# ###########################################################################
# Normalize a table with foreign key columns that map by fetching back the
# last insert id.
# ###########################################################################
$dbh->do('drop database if exists test');
$dbh->do('create database test');
$sb->load_file("master", "common/t/samples/mysqldump-no-data/dump002.txt", "test");
$sb->load_file("master", "mk-insert-normalized/t/samples/raw-data.sql", "test");
@ARGV = qw(-d test);
$o->get_opts();
$copy_rows = make_copier(
   foreign_keys => 1,
   src_db       => 'test',
   src_tbl      => 'raw_data',
   txn_size     => 3,
   dst_tbls     => [
      ['test', 'data_report'], # child2
      ['test', 'entity'     ], # child1
      ['test', 'data'       ], # parent
   ],
   constant_values => {
      posted   => '2011-06-15',
      acquired => '2011-06-14',
   },
);

$rows = $dbh->selectall_arrayref('select * from data_report, entity, data');
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

$copy_rows->copy();

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
$output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $copy_rows->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
$sb->wipe_clean($dbh);
exit;
