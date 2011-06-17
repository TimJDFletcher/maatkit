#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 10;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use MaatkitTest;
use OptionParser;
use DSNParser;
use Quoter;
use TableParser;
use FileIterator;
use Schema;
use SchemaIterator;
use ForeignKeyIterator;
use ColumnMap;

my $q  = new Quoter;
my $tp = new TableParser(Quoter => $q);

my $o  = new OptionParser(description => 'SchemaIterator');
@ARGV = qw();
$o->get_specs("$trunk/mk-table-checksum/mk-table-checksum");
$o->get_opts();

my $in = "$trunk/common/t/samples/mysqldump-no-data/";
my $schema;
my $column_map;

sub make_column_map {
   my ( %args ) = @_;

   my $fi       = new FileIterator();
   my $file_itr = $fi->get_file_itr(@{$args{files}});
   
   $schema = new Schema();

   my $schema_itr;
   my $si       = new SchemaIterator(
      file_itr     => $file_itr,
      OptionParser => $o,
      Quoter       => $q,
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

   $column_map = new ColumnMap(
      src_tbl         => $schema->get_table($args{src_db}, $args{src_tbl}),
      Schema          => $schema,
      constant_values => $args{constant_values},
      ignore_columns  => $args{ignore_columns},
   );
}

make_column_map(
   files           => ["$in/dump002.txt"],
   src_db          => 'test',
   src_tbl         => 'raw_data',
   foreign_keys    => 1,
   constant_values => {
      posted   => 'NOW()',
      acquired => '',
   },
);

is_deeply(
   $column_map->mapped_columns($schema->get_table('test', 'raw_data')),
   [qw(date hour entity_property_1 entity_property_2 data_1 data_2)],
   "Map source table columns, raw_data"
);

is_deeply(
   $column_map->mapped_columns($schema->get_table('test', 'data_report')),
   [qw(date posted acquired)],
   "Map dest table columns, data_report"
);

is_deeply(
   $column_map->mapped_columns($schema->get_table('test', 'entity')),
   [qw(entity_property_1 entity_property_2)],
   "Map dest table columns, entity"
);

is_deeply(
   $column_map->mapped_columns($schema->get_table('test', 'data')),
   [qw(data_report hour entity data_1 data_2)],
   "Map dest table columns, data"
);

my $data_report_tbl = $schema->get_table('test', 'data_report');
my $entity_tbl      = $schema->get_table('test', 'entity');
is_deeply(
   $column_map->mapped_values($schema->get_table('test', 'data')),
   [
      {
         cols  => { data_report => 'id' },
         tbl   => $data_report_tbl,
         where => 'last_insert_id',
      },
      '?',
      {
         cols  => { entity => 'id' },
         tbl   => $entity_tbl,
         where => 'last_insert_id',
      },
      '?',
      '?',
   ],
   "Mapped values with fk fetch backs"
);

is_deeply(
   $column_map->mapped_values($schema->get_table('test', 'data_report')),
   [
      '?',      # date, from raw_data.date
      'NOW()',  # posted, from constant value
      '?',      # acquired, from constant value
   ],
   "Mapped constant values"
);

# ############################################################################
# Ignore columns, i.e. don't map them.
# ############################################################################
make_column_map(
   files           => ["$in/dump002.txt"],
   src_db          => 'test',
   src_tbl         => 'raw_data',
   foreign_keys    => 1,
   constant_values => {
      posted   => 'NOW()',
      acquired => '',
   },
   ignore_columns  => { date => 1 },
);

# Unlike similar tests above, date is no longer mapped.
is_deeply(
   $column_map->mapped_columns($schema->get_table('test', 'raw_data')),
   [qw(hour entity_property_1 entity_property_2 data_1 data_2)],
   "Ignored column not mapped from source table"
);

is_deeply(
   $column_map->mapped_columns($schema->get_table('test', 'data_report')),
   [qw(posted acquired)],
   "Ignored column not mapped to dest table"
);

is_deeply(
   $column_map->mapped_values($schema->get_table('test', 'data_report')),
   [
      'NOW()',  # posted, from constant value
      '?',      # acquired, from constant value
   ],
   "No value placeholder for ignored column"
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $column_map->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
