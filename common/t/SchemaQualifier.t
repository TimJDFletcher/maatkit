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

use MaatkitTest;
use MysqldumpParser;
use Quoter;
use TableParser;
use SchemaQualifier;

my $in = "$trunk/common/t/samples/mysqldump-no-data/";

my $p  = new MysqldumpParser();
my $q  = new Quoter;
my $tp = new TableParser(Quoter => $q);
my $sq = new SchemaQualifier(TableParser => $tp, Quoter => $q);

my $dump = $p->parse_create_tables(
   file => "$in/dump001.txt",
);

$sq->set_schema_from_mysqldump(dump => $dump);
is_deeply(
   $sq->schema,
   {
      test => {
         a => { c1 => 1, c2 => 1,          },
         b => { c1 => 1, c2 => 1, c3 => 1, }
      },
      test2 => {
         a => { c1 => 1, c2 => 1,          },
      },
   },
   "Schema from dump001.txt"
);

is_deeply(
   [ sort $sq->get_duplicate_column_names() ],
   [qw(c1 c2)],
   "Duplicate column names in dump001.txt"
);

is_deeply(
   [ $sq->get_duplicate_table_names() ],
   ['a'],
   "Duplicate table names in dump001.txt"
);

is_deeply(
   $sq->qualify_column(column => 'c3'),
   { db  => 'test', tbl => 'b', col => 'c3', },
   "Qualify column c3"
);

is_deeply(
   $sq->qualify_column(column => 'b.c3'),
   { db  => 'test', tbl => 'b', col => 'c3', },
   "Qualify column b.c3"
);

is_deeply(
   $sq->qualify_column(column => 'test.b.c3'),
   { db  => 'test', tbl => 'b', col => 'c3', },
   "Qualify column test.b.c3"
);

is_deeply(
   $sq->qualify_column(column => 'c1'),
   { db  => undef, tbl => undef, col => 'c1', },
   "Cannot qualify duplicate column name"
);

is_deeply(
   $sq->qualify_column(column => 'xyz'),
   { db  => undef, tbl => undef, col => 'xyz', },
   "Cannot qualify nonexistent column name"
);

is_deeply(
   $sq->qualify_column(column => 'a.c1'),
   { db  => undef, tbl => 'a', col => 'c1', },
   "Cannot database-qualify duplicate table name"
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
