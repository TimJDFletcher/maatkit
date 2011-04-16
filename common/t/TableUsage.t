#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 11;

use MaatkitTest;
use QueryParser;
use SQLParser;
use TableUsage;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $qp = new QueryParser();
my $sp = new SQLParser();
my $ta = new TableUsage(QueryParser => $qp, SQLParser => $sp);
isa_ok($ta, 'TableUsage');

sub test_get_table_usage {
   my ( $query, $cats, $desc ) = @_;
   my $got = $ta->get_table_usage(query=>$query);
   is_deeply(
      $got,
      $cats,
      $desc,
   ) or print Dumper($got);
   return;
}

test_get_table_usage(
   "SELECT * FROM d.t WHERE id>100",
   [
      [
         { context => 'SELECT',
           table   => 'd.t',
         },
         { context => 'WHERE',
           table   => 'd.t',
         },
      ],
   ],
   "SELECT FROM one table"
); 

test_get_table_usage(
   "SELECT t1.* FROM d.t1 LEFT JOIN d.t2 USING (id) WHERE d.t2.foo IS NULL",
   [
      [
         { context => 'SELECT',
           table   => 'd.t1',
         },
         { context => 'JOIN',
           table   => 'd.t1',
         },
         { context => 'JOIN',
           table   => 'd.t2',
         },
         { context => 'WHERE',
           table   => 'd.t2',
         },
      ],
   ],
   "SELECT JOIN two tables"
); 

test_get_table_usage(
   "DELETE FROM d.t WHERE type != 'D' OR type IS NULL",
   [
      [
         { context => 'DELETE',
           table   => 'd.t',
         },
         { context => 'WHERE',
           table   => 'd.t',
         },
      ],
   ],
   "DELETE one table"
); 

test_get_table_usage(
   "INSERT INTO d.t (col1, col2) VALUES ('a', 'b')",
   [
      [
         { context => 'INSERT',
           table   => 'd.t',
         },
         { context => 'SELECT',
           table   => 'DUAL',
         },
      ],
   ],
   "INSERT VALUES, no SELECT"
); 

test_get_table_usage(
   "INSERT INTO d.t SET col1='a', col2='b'",
   [
      [
         { context => 'INSERT',
           table   => 'd.t',
         },
         { context => 'SELECT',
           table   => 'DUAL',
         },
      ],
   ],
   "INSERT SET, no SELECT"
); 

test_get_table_usage(
   "UPDATE d.t SET foo='bar' WHERE foo IS NULL",
   [
      [
         { context => 'UPDATE',
           table   => 'd.t',
         },
         { context => 'SELECT',
           table   => 'DUAL',
         },
         { context => 'WHERE',
           table   => 'd.t',
         },
      ],
   ],
   "UPDATE one table"
); 

test_get_table_usage(
   "SELECT * FROM zn.edp
      INNER JOIN zn.edp_input_key edpik     ON edp = edp.id
      INNER JOIN `zn`.`key`       input_key ON edpik.input_key = input_key.id
      WHERE edp.id = 296",
   [
      { context => 'SELECT',
        usage  => 'read',
        table   => 'zn.edp',
      },
      { context => 'JOIN',
        access  => 'read',
        table   => 'zn.edp_input_key',
      },
      { context => 'JOIN',
        access  => 'read',
        table   => 'zn.key',
      },
      { context => 'WHERE',
        access  => 'read',
        table   => 'edp',
      },
   ],
   "SELECT with 2 JOIN and WHERE"
);

test_get_table_access(
   "REPLACE INTO db.tblA (dt, ncpc)
      SELECT dates.dt, scraped.total_r
        FROM tblB          AS dates
        LEFT JOIN dbF.tblC AS scraped
          ON dates.dt = scraped.dt AND dates.version = scraped.version",
   [
      { context => 'REPLACE',
        access  => 'write',
        table   => 'db.tblA',
      },
      { context => 'REPLACE',
        access  => 'read',
        table   => 'tblB',
      },
      { context => 'REPLACE',
        access  => 'read',
        table   => 'dbF.tblC',
      },
   ],
   "REPLACE SELECT JOIN"
);

test_get_table_access(
   "ALTER TABLE tt.ks ADD PRIMARY KEY(`d`,`v`)",
   [
      { context => 'ALTER',
        access  => 'write',
        table   => 'tt.ks',
      },
   ],
   "ALTER TABLE"
);

test_get_table_access(
   'UPDATE t1 AS a JOIN t2 AS b USING (id) SET a.foo="bar" WHERE b.foo IS NOT NULL',
   [
      { context => 'UPDATE',
        access  => 'write',
        table   => 't1',
      },
      { context => 'UPDATE',
        access  => 'read',
        table   => 't1',
      },
      { context => 'JOIN',
        access  => 'read',
        table   => 't2',
      },
      { context => 'WHERE',
        access  => 'read',
        table   => 't2',
      },
   ],
   "UPDATE joins 2 tables, writes to 1, filters by 1"
);

test_get_table_access(
   'UPDATE t1 INNER JOIN t2 USING (id) SET t1.foo="bar" WHERE t1.id>100 AND t2.id>200',
   [
      { context => 'UPDATE',
        access  => 'write',
        table   => 't1',
      },
      { context => 'UPDATE',
        access  => 'read',
        table   => 't1',
      },
      { context => 'JOIN',
        access  => 'read',
        table   => 't2',
      },
      { context => 'WHERE',
        access  => 'read',
        table   => 't1',
      },
      { context => 'WHERE',
        access  => 'read',
        table   => 't2',
      },
   ],
   "UPDATE joins 2 tables, writes to 2, filters by 2"
);

test_get_table_access(
   'UPDATE t1 AS a JOIN t2 AS b USING (id) SET a.foo="bar", b.foo="bat" WHERE a.id=1',
   [
      { context => 'UPDATE',
        access  => 'write',
        table   => 't1',
      },
      { context => 'UPDATE',
        access  => 'write',
        table   => 't2',
      },
      { context => 'UPDATE',
        access  => 'read',
        table   => 't1',
      },
      { context => 'JOIN',
        access  => 'read',
        table   => 't2',
      },
      { context => 'WHERE',
        access  => 'read',
        table   => 't1',
      },
   ],
   "UPDATE joins 2 tables, writes to 2, filters by 1"
);

test_get_table_access(
   'insert into t1 (a, b, c) select x, y, z from t2 where x is not null',
   [
      { context => 'INSERT',
        access  => 'write',
        table   => 't1',
      },
      { context => 'INSERT',
        access  => 'read',
        table   => 't2',
      },
      { context => 'WHERE',
        access  => 'read',
        table   => 't2',
      },
   ],
   "INSERT INTO t1 SELECT FROM t2",
);

test_get_table_access(
   'insert into t (a, b, c) select a.x, a.y, b.z from a, b where a.id=b.id',
   [
      { context => 'INSERT',
        access  => 'write',
        table   => 't',
      },
      { context => 'INSERT',
        access  => 'read',
        table   => 'a',
      },
      { context => 'INSERT',
        access  => 'read',
        table   => 'b',
      },
      { context => 'WHERE',
        access  => 'read',
        table   => 'a',
      },
   ],
   "INSERT INTO t SELECT FROM a, b"
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $ta->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
