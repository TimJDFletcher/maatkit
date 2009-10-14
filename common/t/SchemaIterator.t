#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 22;

use List::Util qw(max);

require "../SchemaIterator.pm";
require "../Quoter.pm";
require "../DSNParser.pm";
require "../Sandbox.pm";
require "../OptionParser.pm";
require "../VersionParser.pm";

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

my $q   = new Quoter();
my $vp  = new VersionParser();
my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $si = new SchemaIterator(
   Quoter        => $q,
   VersionParser => $vp,
);
isa_ok($si, 'SchemaIterator');

sub get_all {
   my ( $itr ) = @_;
   my @objs;
   while ( my $obj = $itr->() ) {
      MKDEBUG && SchemaIterator::_d('Iterator returned', Dumper($obj));
      push @objs, $obj;
   }
   @objs = sort @objs;
   return \@objs;
}

# ###########################################################################
# Test simple, unfiltered get_db_itr().
# ###########################################################################

$sb->load_file('master', 'samples/SchemaIterator.sql');
my @dbs = sort map { $_->[0] } @{ $dbh->selectall_arrayref('show databases') };

my $next_db = $si->get_db_itr(dbh=>$dbh);
is(
   ref $next_db,
   'CODE',
   'get_db_iter() returns a subref'
);

is_deeply(
   get_all($next_db),
   \@dbs,
   'get_db_iter() found the databases'
);

# ###########################################################################
# Test simple, unfiltered get_tbl_itr().
# ###########################################################################

my $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is(
   ref $next_tbl,
   'CODE',
   'get_tbl_iter() returns a subref'
);

is_deeply(
   get_all($next_tbl),
   [qw(t1 t2 t3)],
   'get_tbl_itr() found the db1 tables'
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d2');
is_deeply(
   get_all($next_tbl),
   [qw(t1)],
   'get_tbl_itr() found the db2 table'
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d3');
is_deeply(
   get_all($next_tbl),
   [],
   'get_tbl_itr() found no db3 tables'
);


# #############################################################################
# Test make_filter().
# #############################################################################
my $o = new OptionParser(
   description => 'SchemaIterator'
);
$o->get_specs('../../mk-parallel-dump/mk-parallel-dump');
$o->get_opts();

my $filter = $si->make_filter($o);
is(
   ref $filter,
   'CODE',
   'make_filter() returns a coderef'
);

$si->set_filter($filter);

$next_db = $si->get_db_itr(dbh=>$dbh);
is_deeply(
   get_all($next_db),
   \@dbs,
   'Database not filtered',
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   [qw(t1 t2 t3)],
   'Tables not filtered'
);

# Filter by --databases (-d).
@ARGV=qw(--d d1);
$o->get_opts();
$filter = $si->make_filter($o);
$si->set_filter($filter);

$next_db = $si->get_db_itr(dbh=>$dbh);
is_deeply(
   get_all($next_db),
   ['d1'],
   '--databases'
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   [qw(t1 t2 t3)],
   '--database filter does not affect tables'
);

# Filter by --databases (-d) and --tables (-t).
@ARGV=qw(-d d1 -t t2);
$o->get_opts();
$filter = $si->make_filter($o);
$si->set_filter($filter);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   ['t2'],
   '--database and --tables'
);

# Ignore some dbs and tbls.
@ARGV=('--ignore-databases', 'mysql,sakila,information_schema,d1,d3');
$o->get_opts();
$filter = $si->make_filter($o);
$si->set_filter($filter);

$next_db = $si->get_db_itr(dbh=>$dbh);
is_deeply(
   get_all($next_db),
   ['d2'],
   '--ignore-databases'
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d2');
is_deeply(
   get_all($next_tbl),
   ['t1'],
   '--ignore-databases filter does not affect tables'
);

@ARGV=('--ignore-databases', 'mysql,sakila,information_schema,d2,d3',
       '--ignore-tables', 't1,t2');
$o->get_opts();
$filter = $si->make_filter($o);
$si->set_filter($filter);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   ['t3'],
   '--ignore-databases and --ignore-tables'
);

# Select some dbs but ignore some tables.
@ARGV=('-d', 'd1', '--ignore-tables', 't1,t3');
$o->get_opts();
$filter = $si->make_filter($o);
$si->set_filter($filter);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   ['t2'],
   '--databases and --ignore-tables'
);

# Filter by engines, which requires extra work: SHOW TABLE STATUS.
@ARGV=qw(--engines InnoDB);
$o->get_opts();
$filter = $si->make_filter($o);
$si->set_filter($filter);

$next_db = $si->get_db_itr(dbh=>$dbh);
is_deeply(
   get_all($next_db),
   \@dbs,
   '--engines does not affect databases'
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   ['t2'],
   '--engines'
);

@ARGV=qw(--ignore-engines MEMORY);
$o->get_opts();
$filter = $si->make_filter($o);
$si->set_filter($filter);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   [qw(t1 t2)],
   '--ignore-engines'
);

SKIP: {
   skip 'Sandbox master does not have the sakila database', 2
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   my @sakila_tbls = map { $_->[0] } grep { $_->[1] eq 'BASE TABLE' } @{ $dbh->selectall_arrayref('show /*!50002 FULL*/ tables from sakila') };

   my @all_sakila_tbls = map { $_->[0] } @{ $dbh->selectall_arrayref('show /*!50002 FULL*/ tables from sakila') };

   @ARGV=();
   $o->get_opts();
   $filter = $si->make_filter($o);
   $si->set_filter($filter);

   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'sakila');
   is_deeply(
      get_all($next_tbl),
      \@sakila_tbls,
      'Table itr does not return views by default'
   );

   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'sakila', views=>1);
   is_deeply(
      get_all($next_tbl),
      \@all_sakila_tbls,
      'Table itr returns views if specified'
   );
};

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
