#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 15;

use MaatkitTest;
use Quoter;
use TableParser;
use FileIterator;
use SchemaIterator;
use SchemaQualifier;
use OptionParser;
use DSNParser;

my $in = "$trunk/common/t/samples/mysqldump-no-data/";

my $q  = new Quoter;
my $tp = new TableParser(Quoter => $q);
my $fi = new FileIterator();

my $o  = new OptionParser(description => 'SchemaIterator');
@ARGV = qw();
$o->get_specs("$trunk/mk-table-checksum/mk-table-checksum");
$o->get_opts();

my $file_itr = $fi->get_file_itr("$in/dump001.txt");
my $sq       = new SchemaQualifier();
my $si       = new SchemaIterator (
   file_itr       => $file_itr,
   OptionParser   => $o,
   Quoter         => $q,
   TableParser    => $tp,
   SchemaQualifier=> $sq,
);

# Init the schema qualifier.
1 while(defined $si->next_schema_object());

ok(
   $sq->is_duplicate_column('c1')
   && $sq->is_duplicate_column('c2'),
   "Duplicate columns in dump001.txt"
);

ok(
   $sq->is_duplicate_table('a'),
   "Duplicate tables in dump001.txt"
);

is_deeply(
   $sq->qualify_column('c3'),
   { db  => 'test', tbl => 'b', col => 'c3', },
   "Qualify column c3"
);

is_deeply(
   $sq->qualify_column('b.c3'),
   { db  => 'test', tbl => 'b', col => 'c3', },
   "Qualify column b.c3"
);

is_deeply(
   $sq->qualify_column('test.b.c3'),
   { db  => 'test', tbl => 'b', col => 'c3', },
   "Qualify column test.b.c3"
);

is_deeply(
   $sq->qualify_column('c1'),
   { db  => undef, tbl => undef, col => 'c1', },
   "Cannot qualify duplicate column name"
);

is_deeply(
   $sq->qualify_column('xyz'),
   { db  => undef, tbl => undef, col => 'xyz', },
   "Cannot qualify nonexistent column name"
);

is_deeply(
   $sq->qualify_column('a.c1'),
   { db  => undef, tbl => 'a', col => 'c1', },
   "Cannot database-qualify duplicate table name"
);

# ############################################################################
# Qualify with duplicates.
# ############################################################################
$file_itr = $fi->get_file_itr("$in/dump001.txt");
$sq       = new SchemaQualifier(allow_duplicate_columns => 1);
$si       = new SchemaIterator (
   file_itr        => $file_itr,
   OptionParser    => $o,
   Quoter          => $q,
   TableParser     => $tp,
   SchemaQualifier => $sq,
);

# Init the schema qualifier.
1 while(defined $si->next_schema_object());

ok(
   !$sq->is_duplicate_column('c1'),
   "No duplicate columns when allowed"
);

ok(
   $sq->is_duplicate_table('a'),
   "Duplicate tables with duplicate columns allowed",
);

is_deeply(
   $sq->qualify_column('c3'),
   [ { db  => 'test', tbl => 'b', col => 'c3', } ],
   "Qualify column c3 with duplicate columns allowed"
);

is_deeply(
   $sq->qualify_column('b.c3'),
   [ { db  => 'test', tbl => 'b', col => 'c3', } ],
   "Qualify column b.c3 with duplicate columns allowed"
);

is_deeply(
   $sq->qualify_column('test.b.c3'),
   [ { db  => 'test', tbl => 'b', col => 'c3', } ],
   "Qualify column test.b.c3 with duplicate columns allowed"
);

is_deeply(
   $sq->qualify_column('c1'),
   [
      { db  => 'test',  tbl => 'a', col => 'c1', },
      { db  => 'test',  tbl => 'b', col => 'c1', },
      { db  => 'test2', tbl => 'a', col => 'c1', },
   ],
   "Qualify duplicate column c1"
);

# ############################################################################
# Set schema with pre-created schema struct.
# ############################################################################


# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $sq->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
