#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use constant MKDEBUG => $ENV{MKDEBUG} || 0;
use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use Test::More tests => 12;

use ExplainAnalyzer;
use QueryRewriter;
use QueryParser;
use DSNParser;
use Sandbox;
use MaatkitTest;

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
$dbh->do('use sakila');

my $qr  = new QueryRewriter();
my $qp  = new QueryParser();
my $exa = new ExplainAnalyzer(QueryRewriter => $qr, QueryParser => $qp);

# #############################################################################
# Tests for getting an EXPLAIN from a database.
# #############################################################################

is_deeply(
   $exa->explain_query(
      dbh => $dbh,
      sql => 'select * from actor where actor_id = 5',
   ),
   [
      { id            => 1,
        select_type   => 'SIMPLE',
        table         => 'actor',
        type          => 'const',
        possible_keys => 'PRIMARY',
        key           => 'PRIMARY',
        key_len       => 2,
        ref           => 'const',
        rows          => 1,
        Extra         => '',
      },
   ],
   'Got a simple EXPLAIN result',
);

is_deeply(
   $exa->explain_query(
      dbh => $dbh,
      sql => 'delete from actor where actor_id = 5',
   ),
   [
      { id            => 1,
        select_type   => 'SIMPLE',
        table         => 'actor',
        type          => 'const',
        possible_keys => 'PRIMARY',
        key           => 'PRIMARY',
        key_len       => 2,
        ref           => 'const',
        rows          => 1,
        Extra         => '',
      },
   ],
   'Got EXPLAIN result for a DELETE',
);

# #############################################################################
# NOTE: EXPLAIN will vary between versions, so rely on the database as little as
# possible for tests.  Most things that need an EXPLAIN in the tests below
# should be using a hard-coded data structure.  Thus the following, intended to
# help prevent $dbh being used too much.
# #############################################################################
# XXX $dbh->disconnect;

# #############################################################################
# Tests for normalizing raw EXPLAIN into a format that's easier to work with.
# #############################################################################
is_deeply(
   $exa->normalize(
      [
         { id            => 1,
           select_type   => 'SIMPLE',
           table         => 'film_actor',
           type          => 'index_merge',
           possible_keys => 'PRIMARY,idx_fk_film_id',
           key           => 'PRIMARY,idx_fk_film_id',
           key_len       => '2,2',
           ref           => undef,
           rows          => 34,
           Extra         => 'Using union(PRIMARY,idx_fk_film_id); Using where',
         },
      ],
   ),
   [
      { id            => 1,
        select_type   => 'SIMPLE',
        table         => 'film_actor',
        type          => 'index_merge',
        possible_keys => [qw(PRIMARY idx_fk_film_id)],
        key           => [qw(PRIMARY idx_fk_film_id)],
        key_len       => [2,2],
        ref           => [qw()],
        rows          => 34,
        Extra         => {
           'Using union' => [qw(PRIMARY idx_fk_film_id)],
           'Using where' => 1,
        },
      },
   ],
   'Normalizes an EXPLAIN',
);

# #############################################################################
# Tests for trimming indexes out of possible_keys.
# #############################################################################
is_deeply(
   $exa->get_alternate_indexes(
      [qw(index1 index2)],
      [qw(index1 index2 index3 index4)],
   ),
   [qw(index3 index4)],
   'Normalizes alternate indexes',
);

# #############################################################################
# Tests for translating aliased names back to their real names.
# #############################################################################

# Putting it all together: given a query and an EXPLAIN, determine which indexes
# the query used.
is_deeply(
   $exa->get_index_usage(
      sql => "select * from film_actor as fa inner join sakila.actor as a "
           . "on a.actor_id = fa.actor_id and a.last_name is not null "
           . "where a.actor_id = 5 or film_id = 5",
      db  => 'sakila',
      explain => $exa->normalize(
         [
            { id            => 1,
              select_type   => 'SIMPLE',
              table         => 'fa',
              type          => 'index_merge',
              possible_keys => 'PRIMARY,idx_fk_film_id',
              key           => 'PRIMARY,idx_fk_film_id',
              key_len       => '2,2',
              ref           => undef,
              rows          => 34,
              Extra         => 'Using union(PRIMARY,idx_fk_film_id); Using where',
            },
            { id            => 1,
              select_type   => 'SIMPLE',
              table         => 'a',
              type          => 'eq_ref',
              possible_keys => 'PRIMARY,idx_actor_last_name',
              key           => 'PRIMARY',
              key_len       => '2',
              ref           => 'sakila.fa.actor_id',
              rows          => 1,
              Extra         => 'Using where',
            },
         ],
      ),
   ),
   [  {  db  => 'sakila',
         tbl => 'film_actor',
         idx => [qw(PRIMARY idx_fk_film_id)],
         alt => [],
      },
      {  db  => 'sakila',
         tbl => 'actor',
         idx => [qw(PRIMARY)],
         alt => [qw(idx_actor_last_name)],
      },
   ],
   'Translate an EXPLAIN and a query into simplified index usage',
);

# #############################################################################
# Done.
# #############################################################################
exit;
