#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 24;
use English qw(-no_match_vars);

require "../TableParser.pm";
require "../Quoter.pm";

my $tp = new TableParser();
my $q = new Quoter();

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}
use Data::Dumper;
my $dupes;
my $callback = sub {
   push @$dupes, $_[0];
};

my $opt = { version => '004001000' };
my $ddl;
my $tbl;

$ddl   = load_file('samples/one_key.sql');
$dupes = [];
$tp->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [
   ],
   'One key, no dupes'
);

$ddl   = load_file('samples/dupe_key.sql');
$dupes = [];
$tp->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'a',
         'duplicate_of' => 'a_2',
         'reason'       => 'a (`a`) is a left-prefix of a_2 (`a`,`b`)',
      }
   ],
   'Two dupe keys on table dupe_key'
);

$ddl   = load_file('samples/dupe_key_reversed.sql');
$dupes = [];
$tp->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'a',
         'duplicate_of' => 'a_2',
         'reason'       => 'a (`a`) is a left-prefix of a_2 (`a`,`b`)',
      }
   ],
   'Two dupe keys on table dupe_key in reverse'
);

# This test might fail if your system sorts a_3 before a_2, because the
# keys are sorted by columns, not name. If this happens, then a_3 will
# duplicate a_2.
$ddl   = load_file('samples/dupe_keys_thrice.sql');
$dupes = [];
$tp->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'a',
         'duplicate_of' => 'a_2',
         'reason'       => 'a (`a`) is a left-prefix of a_2 (`a`,`b`)',
      },
      {
         'key'          => 'a_2',
         'duplicate_of' => 'a_3',
         'reason'       => 'a_2 (`a`,`b`) is a duplicate of a_3 (`a`,`b`)',
      }
   ],
   'Dupe keys only output once'
);

$ddl   = load_file('samples/nondupe_fulltext.sql');
$dupes = [];
$tp->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [
   ],
   'No dupe keys b/c of fulltext'
);
$dupes = [];
$tp->get_duplicate_keys(
   ignore_type => 1,
   keys        => $tp->get_keys($ddl, $opt),
   callback    => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'a',
         'duplicate_of' => 'a_2',
         'reason'       => 'a (`a`) is a left-prefix of a_2 (`a`,`b`)',
      },
   ],
   'Dupe keys when ignoring type'
);

$ddl   = load_file('samples/nondupe_fulltext_not_exact.sql');
$dupes = [];
$tp->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [
   ],
   'No dupe keys b/c fulltext requires exact match (issue 10)'
);

$ddl   = load_file('samples/dupe_fulltext_exact.sql');
$dupes = [];
$tp->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'ft_idx_a_b_1',
         'duplicate_of' => 'ft_idx_a_b_2',
         'reason'       => 'ft_idx_a_b_1 (`a`,`b`) is a duplicate of ft_idx_a_b_2 (`a`,`b`)',
      }
   ],
   'Dupe exact fulltext keys (issue 10)'
);

$ddl   = load_file('samples/dupe_fulltext_reverse_order.sql');
$dupes = [];
$tp->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'ft_idx_a_b',
         'duplicate_of' => 'ft_idx_b_a',
         'reason'       => 'ft_idx_a_b (`a`,`b`) is a duplicate of ft_idx_b_a (`a`,`b`)',
      }
   ],
   'Dupe reverse order fulltext keys (issue 10)'
);

$ddl   = load_file('samples/dupe_key_unordered.sql');
$dupes = [];
$tp->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [
   ],
   'No dupe keys because of order'
);
$dupes = [];
$tp->get_duplicate_keys(
   ignore_order => 1,
   keys         => $tp->get_keys($ddl, $opt),
   callback     => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'a',
         'duplicate_of' => 'a_2',
         'reason'       => 'a (`a`,`b`) is a duplicate of a_2 (`a`,`b`)',
      }
   ],
   'Two dupe keys when ignoring order'
);

# #############################################################################
# Clustered key tests.
# #############################################################################
$ddl   = load_file('samples/innodb_dupe.sql');
$dupes = [];
$tp->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);

is_deeply(
   $dupes,
   [],
   'No duplicate keys with ordinary options'
);
$dupes = [];
$tp->get_duplicate_keys(
   clustered => 1,
   engine    => 'InnoDB',
   keys      => $tp->get_keys($ddl, $opt),
   callback  => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'b',
         'duplicate_of' => 'PRIMARY',
         'reason'       => 'Clustered key b (`b`,`a`) is a duplicate of PRIMARY (`a`)',
      }
   ],
   'Duplicate keys with cluster options'
);

$ddl = load_file('samples/dupe_if_it_were_innodb.sql');
$dupes = [];
$tp->get_duplicate_keys(
   clustered => 1,
   engine    => 'MyISAM',
   keys      => $tp->get_keys($ddl, $opt),
   callback  => $callback);
is_deeply(
   $dupes,
   [],
   'No cluster-duplicate keys because not InnoDB'
);

# This table is a test case for an infinite loop I ran into while writing the
# cluster stuff
$ddl = load_file('samples/mysql_db.sql');
$dupes = [];
$tp->get_duplicate_keys(
   clustered => 1,
   engine    => 'InnoDB',
   keys      => $tp->get_keys($ddl, $opt),
   callback  => $callback);
is_deeply(
   $dupes,
   [
   ],
   'No cluster-duplicate keys in mysql.db'
);

# #############################################################################
# Duplicate FOREIGN KEY tests.
# #############################################################################
$ddl   = load_file('samples/dupe_fk_one.sql');
$dupes = [];
$tp->get_duplicate_fks(
   keys     => $tp->get_fks($ddl, {database => 'test'}),
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 't1_ibfk_2',
         'duplicate_of' => 't1_ibfk_1',
         'reason'       => 'FOREIGN KEY t1_ibfk_2 (`b`, `a`) REFERENCES `test`.`t2` (`b`, `a`) is a duplicate of FOREIGN KEY t1_ibfk_1 (`a`, `b`) REFERENCES `test`.`t2` (`a`, `b`)',
      },
   ],
   'Two duplicate foreign keys'
);

$ddl   = load_file('samples/sakila_film.sql');
$dupes = [];
$tp->get_duplicate_fks(
   keys     => $tp->get_fks($ddl, {database => 'sakila'}),
   callback => $callback);
is_deeply(
   $dupes,
   [
   ],
   'No duplicate foreign keys in sakila_film.sql'
);
exit;
# TODO: update tests below

# #############################################################################
# Issue 9: mk-duplicate-key-checker should treat unique and FK indexes specially
# #############################################################################

$ddl = load_file('samples/issue_9-1.sql');
is_deeply(
   $tp->get_duplicate_keys($tp->get_keys($ddl, $opt)),
   [
   ],
   'Unique and non-unique keys with common prefix not dupes (issue 9)'
);

$ddl = load_file('samples/issue_9-2.sql');
is_deeply(
   $tp->get_duplicate_keys($tp->get_keys($ddl, $opt)),
   [
   ],
   'PRIMARY and non-unique keys with common prefix not dupes (issue 9)'
);

$ddl = load_file('samples/issue_9-3.sql');
is_deeply(
   $tp->get_duplicate_keys($tp->get_keys($ddl, $opt)),
   [
      {
         'key'          => 'j',
         'duplicate_of' => 'i',
         'reason'       => 'j (`a`,`b`) is a duplicate of i (`a`,`b`)',
      }
   ],
   'Non-unique key dupes unique key with same col cover (issue 9)'
);

$ddl = load_file('samples/issue_9-4.sql');
is_deeply(
   $tp->get_duplicate_keys($tp->get_keys($ddl, $opt)),
   [
      {
         'key'          => 'j',
         'duplicate_of' => 'PRIMARY',
         'reason'       => 'j (`a`,`b`) is a duplicate of PRIMARY (`a`,`b`)',
      }
   ],
   'Non-unique key dupes PRIMARY key same col cover (issue 9)'
);

$ddl = load_file('samples/issue_9-5.sql');
is_deeply(
   $tp->get_duplicate_keys($tp->get_keys($ddl, $opt)),
   [
      {
         'key'          => 'j',
         'duplicate_of' => 'i',
         'reason'       => 'j (`a`) is a left-prefix of i (`a`,`b`)',
      }
   ],
   'Two unique keys with common prefix are dupes (issue 9)'
);


$ddl = load_file('samples/issue_9-7.sql');
is_deeply(
   $tp->get_duplicate_keys($tp->get_keys($ddl, $opt)),
   [
      {
         'key'          => 'ua_b',
         'duplicate_of' => 'PRIMARY',
         'reason'       => 'ua_b (`a`,`b`) is an unnecessary UNIQUE constraint for a_b_c (`a`,`b`,`c`) because PRIMARY (`a`) alone preserves key column uniqueness',
      }
   ],
   'Dupe unique prefix of non-unique with PRIMARY constraint (issue 9)'
);

$ddl = load_file('samples/issue_9-6.sql');
is_deeply(
   $tp->get_duplicate_keys($tp->get_keys($ddl, $opt)),
   [
      {
       'key'          => 'ua',
       'duplicate_of' => 'PRIMARY',
       'reason'       => 'ua (`a`) is a left-prefix of PRIMARY (`a`,`b`)',
      },
      {
       'key'          => 'ua_b',
       'duplicate_of' => 'PRIMARY',
       'reason'       => 'ua_b (`a`,`b`) is a duplicate of PRIMARY (`a`,`b`)',
      },
      {
       'key'          => 'ua_b2',
       'duplicate_of' => 'PRIMARY',
       'reason'       => 'ua_b2 (`a`,`b`) is a duplicate of PRIMARY (`a`,`b`)',
      },
      {
       'key'          => 'a',
       'duplicate_of' => 'PRIMARY',
       'reason'       => 'a (`a`) is a left-prefix of PRIMARY (`a`,`b`)',
      },
      {
       'key'          => 'a_b',
       'duplicate_of' => 'PRIMARY',
       'reason'       => 'a_b (`a`,`b`) is a duplicate of PRIMARY (`a`,`b`)',
      }
   ],
   'Very pathological case',
);

exit;
