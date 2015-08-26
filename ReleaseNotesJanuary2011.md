Maatkit version 7207 has been released: http://code.google.com/p/maatkit/

The biggest change in this release is "char chunking" for mk-table-
checksum.  Previously, mk-table-checksum could not chunk character-
based columns (i.e. CHAR/VARCHAR).  After much development effort,
char chunking is now possible and works automatically.  Char chunking
works best for latin1 character sets with evenly distributed data
(e.g. not every value starts with "a").  It's not as precise as
numerical chunking, but it's a lot better than no chunking at all.

mk-query-advisor output was changed.  It now defaults to grouping
results by rule ID (see its new --group-by option) and an mk-query-
digest-like profile was added.

Bugs in mk-duplicate-key-checker, mk-slave-prefetch and mk-query-
digest were fixed.  Given the GA release of MySQL v5.5,
performance\_schema was added to several tools as an automatically
skipped database.  mk-table-sync output also received some tweaks/
additions.

Following is the full changelog...
```
Changelog for mk-duplicate-key-checker:

2011-01-06: version 1.2.14

   * Uppercase index names caused incorrect ALTER TABLE (issue 1192).
   * Made performance_schema an always ignored database (issue 1193).

Changelog for mk-index-usage:

2011-01-06: version 0.9.4

   * Made performance_schema an always ignored database (issue 1193).

Changelog for mk-parallel-dump:

2011-01-06: version 1.0.27

   * Made performance_schema an always ignored database (issue 1193).

Changelog for mk-query-advisor:

2011-01-06: version 1.0.4

   * Added --group-by and changed default to rule_id (issue 1156).
   * Added profile to output (issue 1156).

Changelog for mk-query-digest:

2011-01-06: version 0.9.25

   * EXPLAIN sparklines sometimes did not work or caused errors (issue 1196).
   * Item column in profile was incorrectly truncated to "It" (issue 1196).

Changelog for mk-slave-prefetch:

2011-01-06: version 1.0.21

   * --secondary-indexes did not work for some converted DELETE statements.

Changelog for mk-table-checksum:

2011-01-06: version 1.2.20

   * Character-based columns were not chunkable (issue 568).
   * Added --chunk-range option (issue 1182).
   * Made performance_schema an always ignored database (issue 1193).

Changelog for mk-table-sync:

2011-01-06: version 1.0.31

   * Made performance_schema an always ignored database (issue 1193).
   * Added START and END times to verbose output (issue 377).
   * Added CURRENT_USER() to insufficient privileges error message (issue 1167). 
```