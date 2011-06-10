#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

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
use SchemaIterator;
use Schema;
use ColumnMap;

my $q  = new Quoter;
my $tp = new TableParser(Quoter => $q);
my $fi = new FileIterator();

my $o  = new OptionParser(description => 'SchemaIterator');
@ARGV = qw();
$o->get_specs("$trunk/mk-table-checksum/mk-table-checksum");
$o->get_opts();

my $in = "$trunk/common/t/samples/mysqldump-no-data/";

my $file_itr = $fi->get_file_itr("$in/dump002.txt");
my $schema   = new Schema();
my $si       = new SchemaIterator (
   file_itr     => $file_itr,
   OptionParser => $o,
   Quoter       => $q,
   TableParser  => $tp,
   Schema       => $schema,
);

# Init the schema qualifier.
1 while(defined $si->next_schema_object());

my $column_map = new ColumnMap(
   tbl    => $schema->get_table('test', 'raw_data'),
   Schema => $schema,
);

is_deeply(
   [ $column_map->mapped_columns() ],
   [qw(date hour entity_property_1 entity_property_2 data_1 data_2)],
   "Mapped columns"
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
