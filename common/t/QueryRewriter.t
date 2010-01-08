#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 150;

use QueryRewriter;
use QueryParser;
use MaatkitTest;

my $qp = new QueryParser();
my $qr  = new QueryRewriter(QueryParser=>$qp);

is(
   $qr->strip_comments("select \n--bar\n foo"),
   "select \n\n foo",
   'Removes one-line comments',
);

is(
   $qr->strip_comments("select foo--bar\nfoo"),
   "select foo\nfoo",
   'Removes one-line comments without running them together',
);

is(
   $qr->strip_comments("select foo -- bar"),
   "select foo ",
   'Removes one-line comments at end of line',
);

is(
   $qr->fingerprint(
      q{UPDATE groups_search SET  charter = '   -------3\'\' XXXXXXXXX.\n    \n    -----------------------------------------------------', show_in_list = 'Y' WHERE group_id='aaaaaaaa'}),
   'update groups_search set charter = ?, show_in_list = ? where group_id=?',
   'complex comments',
);

is(
   $qr->fingerprint("SELECT /*!40001 SQL_NO_CACHE */ * FROM `film`"),
   "mysqldump",
   'Fingerprints all mysqldump SELECTs together',
);

is(
   $qr->distill("SELECT /*!40001 SQL_NO_CACHE */ * FROM `film`"),
   "SELECT film",
   'Distills mysqldump SELECTs to selects',
);

is(
   $qr->fingerprint("CALL foo(1, 2, 3)"),
   "call foo",
   'Fingerprints stored procedure calls specially',
);

is(
   $qr->distill("CALL foo(1, 2, 3)"),
   "CALL foo",
   'Distills stored procedure calls specially',
);

is(
   $qr->fingerprint('# administrator command: Init DB'),
   '# administrator command: Init DB',
   'Fingerprints admin commands as themselves',
);

is(
   $qr->fingerprint(
      q{REPLACE /*foo.bar:3/3*/ INTO checksum.checksum (db, tbl, }
      .q{chunk, boundaries, this_cnt, this_crc) SELECT 'foo', 'bar', }
      .q{2 AS chunk_num, '`id` >= 2166633', COUNT(*) AS cnt, }
      .q{LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `id`, `created_by`, }
      .q{`created_date`, `updated_by`, `updated_date`, `ppc_provider`, }
      .q{`account_name`, `provider_account_id`, `campaign_name`, }
      .q{`provider_campaign_id`, `adgroup_name`, `provider_adgroup_id`, }
      .q{`provider_keyword_id`, `provider_ad_id`, `foo`, `reason`, }
      .q{`foo_bar_bazz_id`, `foo_bar_baz`, CONCAT(ISNULL(`created_by`), }
      .q{ISNULL(`created_date`), ISNULL(`updated_by`), ISNULL(`updated_date`), }
      .q{ISNULL(`ppc_provider`), ISNULL(`account_name`), }
      .q{ISNULL(`provider_account_id`), ISNULL(`campaign_name`), }
      .q{ISNULL(`provider_campaign_id`), ISNULL(`adgroup_name`), }
      .q{ISNULL(`provider_adgroup_id`), ISNULL(`provider_keyword_id`), }
      .q{ISNULL(`provider_ad_id`), ISNULL(`foo`), ISNULL(`reason`), }
      .q{ISNULL(`foo_base_foo_id`), ISNULL(`fooe_foo_id`)))) AS UNSIGNED)), 10, }
      .q{16)) AS crc FROM `foo`.`bar` USE INDEX (`PRIMARY`) WHERE }
      .q{(`id` >= 2166633); }),
   'maatkit',
   'Fingerprints mk-table-checksum queries together',
);

is(
   $qr->distill(
      q{REPLACE /*foo.bar:3/3*/ INTO checksum.checksum (db, tbl, }
      .q{chunk, boundaries, this_cnt, this_crc) SELECT 'foo', 'bar', }
      .q{2 AS chunk_num, '`id` >= 2166633', COUNT(*) AS cnt, }
      .q{LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `id`, `created_by`, }
      .q{`created_date`, `updated_by`, `updated_date`, `ppc_provider`, }
      .q{`account_name`, `provider_account_id`, `campaign_name`, }
      .q{`provider_campaign_id`, `adgroup_name`, `provider_adgroup_id`, }
      .q{`provider_keyword_id`, `provider_ad_id`, `foo`, `reason`, }
      .q{`foo_bar_bazz_id`, `foo_bar_baz`, CONCAT(ISNULL(`created_by`), }
      .q{ISNULL(`created_date`), ISNULL(`updated_by`), ISNULL(`updated_date`), }
      .q{ISNULL(`ppc_provider`), ISNULL(`account_name`), }
      .q{ISNULL(`provider_account_id`), ISNULL(`campaign_name`), }
      .q{ISNULL(`provider_campaign_id`), ISNULL(`adgroup_name`), }
      .q{ISNULL(`provider_adgroup_id`), ISNULL(`provider_keyword_id`), }
      .q{ISNULL(`provider_ad_id`), ISNULL(`foo`), ISNULL(`reason`), }
      .q{ISNULL(`foo_base_foo_id`), ISNULL(`fooe_foo_id`)))) AS UNSIGNED)), 10, }
      .q{16)) AS crc FROM `foo`.`bar` USE INDEX (`PRIMARY`) WHERE }
      .q{(`id` >= 2166633); }),
   'REPLACE SELECT checksum.checksum foo.bar',
   'Distills mk-table-checksum query',
);

is(
   $qr->fingerprint("use `foo`"),
   "use ?",
   'Removes identifier from USE',
);

is(
   $qr->distill("use `foo`"),
   "USE",
   'distills USE',
);

is(
   $qr->fingerprint("select \n--bar\n foo"),
   "select foo",
   'Removes one-line comments in fingerprints',
);

is(
   $qr->distill("select \n--bar\n foo"),
   "SELECT",
   'distills queries from DUAL',
);

is(
   $qr->fingerprint("select foo--bar\nfoo"),
   "select foo foo",
   'Removes one-line comments in fingerprint without mushing things together',
);

is(
   $qr->fingerprint("select foo -- bar\n"),
   "select foo ",
   'Removes one-line EOL comments in fingerprints',
);

# This one is too expensive!
#is(
#   $qr->fingerprint(
#      "select a,b ,c , d from tbl where a=5 or a = 5 or a=5 or a =5"),
#   "select a, b, c, d from tbl where a=? or a=? or a=? or a=?",
#   "Normalizes commas and equals",
#);

is(
   $qr->fingerprint("select null, 5.001, 5001. from foo"),
   "select ?, ?, ? from foo",
   "Handles bug from perlmonks thread 728718",
);

is(
   $qr->distill("select null, 5.001, 5001. from foo"),
   "SELECT foo",
   "distills simple select",
);

is(
   $qr->fingerprint("select 'hello', '\nhello\n', \"hello\", '\\'' from foo"),
   "select ?, ?, ?, ? from foo",
   "Handles quoted strings",
);

is(
   $qr->distill("select 'hello', '\nhello\n', \"hello\", '\\'' from foo"),
   "SELECT foo",
   "distills with quoted strings",
);

is(
   $qr->fingerprint("select 'hello'\n"),
   "select ?",
   "Handles trailing newline",
);

# This is a known deficiency, fixes seem to be expensive though.
is(
   $qr->fingerprint("select '\\\\' from foo"),
   "select '\\ from foo",
   "Does not handle all quoted strings",
);

is(
   $qr->fingerprint("select   foo"),
   "select foo",
   'Collapses whitespace',
);

is(
   $qr->strip_comments("select /*\nhello!*/ 1"),
   'select  1',
   'Stripped star comment',
);

is(
   $qr->strip_comments('select /*!40101 hello*/ 1'),
   'select /*!40101 hello*/ 1',
   'Left version star comment',
);

is(
   $qr->fingerprint('SELECT * from foo where a = 5'),
   'select * from foo where a = ?',
   'Lowercases, replaces integer',
);

is(
   $qr->fingerprint('select 0e0, +6e-30, -6.00 from foo where a = 5.5 or b=0.5 or c=.5'),
   'select ?, ?, ? from foo where a = ? or b=? or c=?',
   'Floats',
);

is(
   $qr->fingerprint("select 0x0, x'123', 0b1010, b'10101' from foo"),
   'select ?, ?, ?, ? from foo',
   'Hex/bit',
);

is(
   $qr->fingerprint(" select  * from\nfoo where a = 5"),
   'select * from foo where a = ?',
   'Collapses whitespace',
);

is(
   $qr->fingerprint("select * from foo where a in (5) and b in (5, 8,9 ,9 , 10)"),
   'select * from foo where a in(?+) and b in(?+)',
   'IN lists',
);

is(
   $qr->fingerprint("select foo_1 from foo_2_3"),
   'select foo_? from foo_?_?',
   'Numeric table names',
);

is(
   $qr->distill("select foo_1 from foo_2_3"),
   'SELECT foo_?_?',
   'distills numeric table names',
);

# 123f00 => ?oo because f "looks like it could be a number".
is(
   $qr->fingerprint("select 123foo from 123foo", { prefixes => 1 }),
   'select ?oo from ?oo',
   'Numeric table name prefixes',
);

is(
   $qr->fingerprint("select 123_foo from 123_foo", { prefixes => 1 }),
   'select ?_foo from ?_foo',
   'Numeric table name prefixes with underscores',
);

is(
   $qr->fingerprint("insert into abtemp.coxed select foo.bar from foo"),
   'insert into abtemp.coxed select foo.bar from foo',
   'A string that needs no changes',
);

is(
   $qr->distill("insert into abtemp.coxed select foo.bar from foo"),
   'INSERT SELECT abtemp.coxed foo',
   'distills insert/select',
);

is(
   $qr->fingerprint('insert into foo(a, b, c) values(2, 4, 5)'),
   'insert into foo(a, b, c) values(?+)',
   'VALUES lists',
);

is(
   $qr->distill('insert into foo(a, b, c) values(2, 4, 5)'),
   'INSERT foo',
   'distills value lists',
);

is(
   $qr->fingerprint('insert into foo(a, b, c) values(2, 4, 5) , (2,4,5)'),
   'insert into foo(a, b, c) values(?+)',
   'VALUES lists with multiple ()',
);

is(
   $qr->fingerprint('insert into foo(a, b, c) value(2, 4, 5)'),
   'insert into foo(a, b, c) value(?+)',
   'VALUES lists with VALUE()',
);

is(
   $qr->fingerprint('select * from foo limit 5'),
   'select * from foo limit ?',
   'limit alone',
);

is(
   $qr->fingerprint('select * from foo limit 5, 10'),
   'select * from foo limit ?',
   'limit with comma-offset',
);

is(
   $qr->fingerprint('select * from foo limit 5 offset 10'),
   'select * from foo limit ?',
   'limit with offset',
);

is(
   $qr->fingerprint('select 1 union select 2 union select 4'),
   'select ? /*repeat union*/',
   'union fingerprints together',
);

is(
   $qr->distill('select 1 union select 2 union select 4'),
   'SELECT UNION',
   'union distills together',
);

is(
   $qr->fingerprint('select 1 union all select 2 union all select 4'),
   'select ? /*repeat union all*/',
   'union all fingerprints together',
);

is(
   $qr->fingerprint(
      q{select * from (select 1 union all select 2 union all select 4) as x }
      . q{join (select 2 union select 2 union select 3) as y}),
   q{select * from (select ? /*repeat union all*/) as x }
      . q{join (select ? /*repeat union*/) as y},
   'union all fingerprints together',
);

is($qr->convert_to_select(), undef, 'No query');

is(
   $qr->convert_to_select(
      'replace into foo select * from bar',
   ),
   'select * from bar',
   'replace select',
);

is(
   $qr->convert_to_select(
      'replace into foo select`faz` from bar',
   ),
   'select`faz` from bar',
   'replace select',
);

is(
   $qr->convert_to_select(
      'insert into foo(a, b, c) values(1, 3, 5)',
   ),
   'select * from  foo where a=1 and  b= 3 and  c= 5',
   'insert',
);

is(
   $qr->convert_to_select(
      'insert ignore into foo(a, b, c) values(1, 3, 5)',
   ),
   'select * from  foo where a=1 and  b= 3 and  c= 5',
   'insert ignore',
);

is(
   $qr->convert_to_select(
      'insert into foo(a, b, c) value(1, 3, 5)',
   ),
   'select * from  foo where a=1 and  b= 3 and  c= 5',
   'insert with VALUE()',
);

is(
   $qr->convert_to_select(
      'replace into foo(a, b, c) values(1, 3, 5) on duplicate key update foo=bar',
   ),
   'select * from  foo where a=1 and  b= 3 and  c= 5',
   'replace with ODKU',
);

is(
   $qr->distill(
      'replace into foo(a, b, c) values(1, 3, 5) on duplicate key update foo=bar',
   ),
   'REPLACE UPDATE foo',
   'distills ODKU',
);

is(
   $qr->convert_to_select(
      'replace into foo(a, b, c) values(now(), "3", 5)',
   ),
   'select * from  foo where a=now() and  b= "3" and  c= 5',
   'replace with complicated expressions',
);

is(
   $qr->convert_to_select(
      'replace into foo(a, b, c) values(current_date - interval 1 day, "3", 5)',
   ),
   'select * from  foo where a=current_date - interval 1 day and  b= "3" and  c= 5',
   'replace with complicated expressions',
);

is(
   $qr->convert_to_select(
      'insert into foo select * from bar join baz using (bat)',
   ),
   'select * from bar join baz using (bat)',
   'insert select',
);

is(
   $qr->distill(
      'insert into foo select * from bar join baz using (bat)',
   ),
   'INSERT SELECT foo bar baz',
   'distills insert select',
);

is(
   $qr->convert_to_select(
      'insert into foo select * from bar where baz=bat on duplicate key update',
   ),
   'select * from bar where baz=bat',
   'insert select on duplicate key update',
);

is(
   $qr->convert_to_select(
      'update foo set bar=baz where bat=fiz',
   ),
   'select  bar=baz from foo where  bat=fiz',
   'update set',
);

is(
   $qr->distill(
      'update foo set bar=baz where bat=fiz',
   ),
   'UPDATE foo',
   'distills update',
);

is(
   $qr->convert_to_select(
      'update foo inner join bar using(baz) set big=little',
   ),
   'select  big=little from foo inner join bar using(baz) ',
   'delete inner join',
);

is(
   $qr->distill(
      'update foo inner join bar using(baz) set big=little',
   ),
   'UPDATE foo bar',
   'distills update-multi',
);

is(
   $qr->convert_to_select(
      'update foo set bar=baz limit 50',
   ),
   'select  bar=baz  from foo  limit 50 ',
   'update with limit',
);

is(
   $qr->convert_to_select(
q{UPDATE foo.bar
SET    whereproblem= '3364', apple = 'fish'
WHERE  gizmo='5091'}
   ),
   q{select     whereproblem= '3364', apple = 'fish' from foo.bar where   gizmo='5091'},
   'unknown issue',
);

is(
   $qr->convert_to_select(
      'delete from foo where bar = baz',
   ),
   'select * from  foo where bar = baz',
   'delete',
);

is(
   $qr->distill(
      'delete from foo where bar = baz',
   ),
   'DELETE foo',
   'distills delete',
);

# Insanity...
is(
   $qr->convert_to_select('
update db2.tbl1 as p
   inner join (
      select p2.col1, p2.col2
      from db2.tbl1 as p2
         inner join db2.tbl3 as ba
            on p2.col1 = ba.tbl3
      where col4 = 0
      order by priority desc, col1, col2
      limit 10
   ) as chosen on chosen.col1 = p.col1
      and chosen.col2 = p.col2
   set p.col4 = 149945'),
   'select  p.col4 = 149945 from db2.tbl1 as p
   inner join (
      select p2.col1, p2.col2
      from db2.tbl1 as p2
         inner join db2.tbl3 as ba
            on p2.col1 = ba.tbl3
      where col4 = 0
      order by priority desc, col1, col2
      limit 10
   ) as chosen on chosen.col1 = p.col1
      and chosen.col2 = p.col2 ',
   'SELECT in the FROM clause',
);

is(
   $qr->distill('
update db2.tbl1 as p
   inner join (
      select p2.col1, p2.col2
      from db2.tbl1 as p2
         inner join db2.tbl3 as ba
            on p2.col1 = ba.tbl3
      where col4 = 0
      order by priority desc, col1, col2
      limit 10
   ) as chosen on chosen.col1 = p.col1
      and chosen.col2 = p.col2
   set p.col4 = 149945'),
   'UPDATE SELECT db?.tbl?',
   'distills complex subquery',
);

is(
   $qr->convert_to_select(q{INSERT INTO foo.bar (col1, col2, col3)
       VALUES ('unbalanced(', 'val2', 3)}),
   q{select * from  foo.bar  where col1='unbalanced(' and  }
   . q{col2= 'val2' and  col3= 3},
   'unbalanced paren inside a string in VALUES',
);

is(
   $qr->convert_to_select(q{delete foo.bar b from foo.bar b left join baz.bat c on a=b where nine>eight}),
   'select 1 from  foo.bar b left join baz.bat c on a=b where nine>eight',
   'Do not select * from a join',
);

is(
   $qr->distill(q{delete foo.bar b from foo.bar b left join baz.bat c on a=b where nine>eight}),
   'DELETE foo.bar baz.bat',
   'distills and then collapses same tables',
);

is (
   $qr->convert_to_select(q{
REPLACE DELAYED INTO
`db1`.`tbl2`(`col1`,col2)
VALUES ('617653','2007-09-11')}),
   qq{select * from \n`db1`.`tbl2` where `col1`='617653' and col2='2007-09-11'},
   'replace delayed',
);

is (
   $qr->distill(q{
REPLACE DELAYED INTO
`db1`.`tbl2`(`col1`,col2)
VALUES ('617653','2007-09-11')}),
   'REPLACE db?.tbl?',
   'distills replace-delayed',
);

is(
   $qr->convert_to_select(
      'select * from tbl where id = 1'
   ),
   'select * from tbl where id = 1',
   'Does not convert select to select',
);

is($qr->wrap_in_derived(), undef, 'Cannot wrap undef');

is(
   $qr->wrap_in_derived(
      'select * from foo',
   ),
   'select 1 from (select * from foo) as x limit 1',
   'wrap in derived table',
);

is(
   $qr->wrap_in_derived('set timestamp=134'),
   'set timestamp=134',
   'Do not wrap non-SELECT queries',
);

is(
   $qr->distill('set timestamp=134'),
   'SET',
   'distills set',
);

is(
   $qr->convert_select_list('select * from tbl'),
   'select 1 from tbl',
   'Star to one',
);

is(
   $qr->convert_select_list('select a, b, c from tbl'),
   'select isnull(coalesce( a, b, c )) from tbl',
   'column list to isnull/coalesce'
);

is(
   $qr->convert_to_select("UPDATE tbl SET col='wherex'WHERE crazy=1"),
   "select  col='wherex' from tbl where  crazy=1",
   "update with SET col='wherex'WHERE"
);

is($qr->convert_to_select(
   q{UPDATE GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU SET }
   . q{GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME=}
   . q{'Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59'WHERE}
   . q{ PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.}
   . q{APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1}
   . q{ AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0}
   . q{ AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )}),
   "select  GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME='Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59' from GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU where  PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1 AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0 AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )",
   'update with no space between quoted string and where (issue 168)'
);

is($qr->distill(
   q{UPDATE GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU SET }
   . q{GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME=}
   . q{'Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59'WHERE}
   . q{ PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.}
   . q{APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1}
   . q{ AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0}
   . q{ AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )}),
   'UPDATE GARDEN_CLUPL GARDENJOB APLTRACT_GARDENPLANT',
   'distills where there is alias and comma-join',
);

is(
   $qr->distill(q{SELECT STRAIGHT_JOIN distinct foo, bar FROM A, B, C}),
   'SELECT A B C',
   'distill with STRAIGHT_JOIN',
);

is(
   $qr->distill(
      'replace into checksum.checksum select `last_update`, `foo` from foo.foo'),
   'REPLACE SELECT checksum.checksum foo.foo',
   'distill with reserved words');

is($qr->distill('SHOW STATUS'), 'SHOW STATUS', 'distill SHOW STATUS');

is($qr->distill('commit'), 'COMMIT', 'distill COMMIT');

is($qr->distill('FLUSH TABLES WITH READ LOCK'), 'FLUSH', 'distill FLUSH');

is($qr->distill('BEGIN'), 'BEGIN', 'distill BEGIN');

is($qr->distill('start'), 'START', 'distill START');

is($qr->distill('ROLLBACK'), 'ROLLBACK', 'distill ROLLBACK');

is(
   $qr->shorten("insert into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
   "insert into t(a,b,c) values(a,b,c) /*... omitted ...*/",
   "shorten simple insert",
);

is(
   $qr->shorten("insert low_priority into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
   "insert low_priority into t(a,b,c) values(a,b,c) /*... omitted ...*/",
   "shorten low_priority simple insert",
);

is(
   $qr->shorten("insert delayed into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
   "insert delayed into t(a,b,c) values(a,b,c) /*... omitted ...*/",
   "shorten delayed simple insert",
);

is(
   $qr->shorten("insert high_priority into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
   "insert high_priority into t(a,b,c) values(a,b,c) /*... omitted ...*/",
   "shorten high_priority simple insert",
);

is(
   $qr->shorten("insert ignore into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
   "insert ignore into t(a,b,c) values(a,b,c) /*... omitted ...*/",
   "shorten ignore simple insert",
);

is(
   $qr->shorten("insert high_priority ignore into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
   "insert high_priority ignore into t(a,b,c) values(a,b,c) /*... omitted ...*/",
   "shorten high_priority ignore simple insert",
);

is(
   $qr->shorten("replace low_priority into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
   "replace low_priority into t(a,b,c) values(a,b,c) /*... omitted ...*/",
   "shorten replace low_priority",
);

is(
   $qr->shorten("replace delayed into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
   "replace delayed into t(a,b,c) values(a,b,c) /*... omitted ...*/",
   "shorten replace delayed",
);

is(
   $qr->shorten("insert into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i) on duplicate key update a = b"),
   "insert into t(a,b,c) values(a,b,c) /*... omitted ...*/on duplicate key update a = b",
   "shorten insert ... odku",
);

is(
   $qr->shorten(
      "select * from a where b in(" . join(',', 1..60) . ") and "
         . "a in(" . join(',', 1..5000) . ")", 1),
   "select * from a where b in(" . join(',', 1..20) . "/*... omitted 40 items ...*/)"
      . " and a in(" . join(',', 1..20) . "/*... omitted 4980 items ...*/)",
   "shorten two IN() lists of numbers",
);

is(
   $qr->shorten("select * from a", 1),
   "select * from a",
   "Does not shorten strings it does not match",
);

is(
   $qr->shorten("select * from a where b in(". join(',', 1..100) . ")", 1024),
   "select * from a where b in(". join(',', 1..100) . ")",
   "shorten IN() list numbers but not those that are already short enough",
);

is(
   $qr->shorten("select * from a where b in(" . join(',', 1..100) . "'a,b')", 1),
   "select * from a where b in(" . join(',', 1..20) . "/*... omitted 81 items ...*/)",
   "Test case to document that commas are expected to mess up omitted count",
);

is(
   $qr->shorten("select * from a where b in(1, 'a)b', " . join(',', 1..100) . ")", 1),
   "select * from a where b in(1, 'a)b', " . join(',', 1..100) . ")",
   "Test case to document that parens are expected to prevent shortening",
);

is(
   $qr->distill('create database foo'),
   'CREATE DATABASE foo',
   'distills create database'
);
is(
   $qr->distill('create table foo'),
   'CREATE TABLE foo',
   'distills create table'
);
is(
   $qr->distill('alter database foo'),
   'ALTER DATABASE foo',
   'distills alter database'
);
is(
   $qr->distill('alter table foo'),
   'ALTER TABLE foo',
   'distills alter table'
);
is(
   $qr->distill('drop database foo'),
   'DROP DATABASE foo',
   'distills drop database'
);
is(
   $qr->distill('drop table foo'),
   'DROP TABLE foo',
   'distills drop table'
);
is(
   $qr->distill('rename database foo'),
   'RENAME DATABASE foo',
   'distills rename database'
);
is(
   $qr->distill('rename table foo'),
   'RENAME TABLE foo',
   'distills rename table'
);
is(
   $qr->distill('truncate table foo'),
   'TRUNCATE TABLE foo',
   'distills truncate table'
);

# Test generic distillation for memcached, http, etc.
my $trf = sub {
   my ( $query ) = @_;
   $query =~ s/(\S+ \S+?)(?:[?;].+)/$1/;
   return $query;
};

is(
   $qr->distill('get percona.com/', generic => 1, trf => $trf),
   'GET percona.com/',
   'generic distill HTTP get'
);

is(
   $qr->distill('get percona.com/page.html?some=thing', generic => 1, trf => $trf),
   'GET percona.com/page.html',
   'generic distill HTTP get with args'
);

is(
   $qr->distill('put percona.com/contacts.html', generic => 1, trf => $trf),
   'PUT percona.com/contacts.html',
   'generic distill HTTP put'
);

# #############################################################################
# Issue 322: mk-query-digest segfault before report
# #############################################################################
is(
   $qr->fingerprint( load_file('common/t/samples/huge_replace_into_values.txt') ),
   q{replace into `film_actor` values(?+)},
   'huge replace into values() (issue 322)',
);
is(
   $qr->fingerprint( load_file('common/t/samples/huge_insert_ignore_into_values.txt') ),
   q{insert ignore into `film_actor` values(?+)},
   'huge insert ignore into values() (issue 322)',
);
is(
   $qr->fingerprint( load_file('common/t/samples/huge_explicit_cols_values.txt') ),
   q{insert into foo (a,b,c,d,e,f,g,h) values(?+)},
   'huge insert with explicit columns before values() (issue 322)',
);

# Those ^ aren't huge enough.  This one is 1.2M large. 
my $huge_insert = `zcat $trunk/common/t/samples/slow039.txt.gz | tail -n 1`;
is(
   $qr->fingerprint($huge_insert),
   q{insert into the_universe values(?+)},
   'truly huge insert 1/2 (issue 687)'
);
$huge_insert = `zcat $trunk/common/t/samples/slow040.txt.gz | tail -n 2`;
is(
   $qr->fingerprint($huge_insert),
   q{insert into the_universe values(?+)},
   'truly huge insert 2/2 (issue 687)'
);

# #############################################################################
# Issue 563: Lock tables is not distilled
# #############################################################################
is(
   $qr->distill('LOCK TABLES foo WRITE'),
   'LOCK foo',
   'distills lock tables'
);
is(
   $qr->distill('LOCK TABLES foo READ, bar WRITE'),
   'LOCK foo bar',
   'distills lock tables (2 tables)'
);
is(
   $qr->distill('UNLOCK TABLES'),
   'UNLOCK',
   'distills unlock tables'
);

# #############################################################################
#  Issue 712: Queries not handled by "distill"
# #############################################################################
is(
   $qr->distill('XA START 0x123'),
   'XA_START',
   'distills xa start'
);
is(
   $qr->distill('XA PREPARE 0x123'),
   'XA_PREPARE',
   'distills xa prepare'
);
is(
   $qr->distill('XA COMMIT 0x123'),
   'XA_COMMIT',
   'distills xa commit'
);
is(
   $qr->distill('XA END 0x123'),
   'XA_END',
   'distills xa end'
);

is(
   $qr->distill("/* mysql-connector-java-5.1-nightly-20090730 ( Revision: \${svn.Revision} ) */SHOW VARIABLES WHERE Variable_name ='language' OR Variable_name =
   'net_write_timeout' OR Variable_name = 'interactive_timeout' OR
   Variable_name = 'wait_timeout' OR Variable_name = 'character_set_client' OR
   Variable_name = 'character_set_connection' OR Variable_name =
   'character_set' OR Variable_name = 'character_set_server' OR Variable_name
   = 'tx_isolation' OR Variable_name = 'transaction_isolation' OR
   Variable_name = 'character_set_results' OR Variable_name = 'timezone' OR
   Variable_name = 'time_zone' OR Variable_name = 'system_time_zone' OR
   Variable_name = 'lower_case_table_names' OR Variable_name =
   'max_allowed_packet' OR Variable_name = 'net_buffer_length' OR
   Variable_name = 'sql_mode' OR Variable_name = 'query_cache_type' OR
   Variable_name = 'query_cache_size' OR Variable_name = 'init_connect'"),
   'SHOW VARIABLES',
   'distills /* comment */SHOW VARIABLES'
);

is(
   $qr->distill('SHOW SLAVE STATUS'),
   'SHOW SLAVE STATUS',
   'distills SHOW SLAVE STATUS'
);
is(
   $qr->distill('SHOW INNODB STATUS'),
   'SHOW INNODB STATUS',
   'distills SHOW INNODB STATUS'
);
is(
   $qr->distill('SHOW CREATE TABLE'),
   'SHOW CREATE TABLE',
   'distills SHOW CREATE TABLE'
);

my @show = qw(COLUMNS GRANTS INDEX STATUS TABLES TRIGGERS WARNINGS);
foreach my $show ( @show ) {
   is(
      $qr->distill("SHOW $show"),
      "SHOW $show",
      "distills SHOW $show"
   );
}

# #############################################################################
#  Issue 735: mk-query-digest doesn't distill query correctly
# #############################################################################

is( 
	$qr->distill('SHOW /*!50002 GLOBAL */ STATUS'),
	'SHOW STATUS',
	"distills SHOW STATUS"
);

is( 
	$qr->distill('SHOW /*!50002 ENGINE */ INNODB STATUS'),
	'SHOW INNODB STATUS',
	"distills SHOW INNODB STATUS"
);

is( 
	$qr->distill('SHOW MASTER LOGS'),
	'SHOW MASTER LOGS',
	"distills SHOW MASTER LOGS"
);

is( 
	$qr->distill('SHOW GLOBAL STATUS'),
	'SHOW GLOBAL STATUS',
	"distills SHOW GLOBAL STATUS"
);

is( 
	$qr->distill('SHOW GLOBAL VARIABLES'),
	'SHOW VARIABLES',
	"distills SHOW VARIABLES"
);

is( 
	$qr->distill('# administrator command: Statistics'),
	'ADMIN STATISTICS',
	"distills ADMIN STATISTICS"
);

# #############################################################################
# Issue 781: mk-query-digest doesn't distill or extract tables properly
# #############################################################################

is( 
	$qr->distill("SELECT `id` FROM (`field`) WHERE `id` = '10000016228434112371782015185031'"),
	'SELECT field',
	'distills SELECT clm from (`tbl`)'
);

exit;
