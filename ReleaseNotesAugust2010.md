There are two new tools in this release: mk-query-advisor and
mk-variable-advisor.  We're still adding rules (i.e. things that get
checked); contact us if you'd like to add a rule or if you find a
false-positive.

mk-table-checksum got two new options: --chunk-size-limit and
--unchunkable-tables which make it safer.  These options help avoid
checksumming tables that will be too costly.

mk-query-digest had a bug fix and some enhancements to its output.

After finishing the Retry module we were able to make several tools
(like mk-table-sync and mk-slave-delay) retry certain key operations.
mk-table-sync, for example, handles MASTER\_POS\_WAIT better now (for --
wait).

It may not be of interest to the user but we've begun documenting the
entire Maatkit code base with Natural Docs: http://maatkit.googlecode.com/svn/docs/code/index.html

Following is the entire changelog for this release.

```
Changelog for mk-query-advisor:

2010-08-01: version 1.0.0

  * Initial release.

Changelog for mk-query-digest:

2010-08-01: version 0.9.20

  * --outliers did not work (issue 1087).
  * Profile did not show actual query ranks (issue 1087).
  * Made header and query_report outputs easier to read (issue 699).
  * Certain queries with subqueries were converted incorrectly (issue 347).

Changelog for mk-slave-delay:

2010-08-01: version 1.0.22

  * The tool did not reconnect to the slave (issue 991).

Changelog for mk-slave-find:

2010-08-01: version 1.0.13

  * Added "InnoDB version" to summary report format (issue 1079).

Changelog for mk-slave-prefetch:

2010-08-01: version 1.0.20

  * mysqlbinlog was not killed before closing relay log file.
  * Tool crashed if server did not have query cache (issue 992).

Changelog for mk-table-checksum:

2010-08-01: version 1.2.17

  * Added --chunk-size-limit (issue 796).
  * Added --unchunkable-tables (issue 796).
  * Use optimizer preferred index as --chunk-index for --where (issue 378).

Changelog for mk-table-sync:

2010-08-01: version 1.0.30

  * The tool did not retry MASTER_POS_WAIT for --wait (issue 748).

Changelog for mk-variable-advisor:

2010-08-01: version 1.0.0

  * Initial release.
```