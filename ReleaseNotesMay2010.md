Developments in this release include a new look/order to mk-query-
digest's output.  Previously it was "(global) header, query\_report,
profile, prepared" now it's "rusage, date, files, header, profile,
query\_report, prepared", and you can customize that order.

mk-kill has a new option, --all, and by default it no longer matches
replication threads, so you can say "mk-kill --kill --all" to kill
every non-replication thread.

mk-table-checksum has a new option:  --throttle-method which becomes
"=slavelag" when used with "--replicate" to automatically throttle
checksumming by the worst lagged slave.

mk-table-sync has --[no](no.md)hex-blob and converts blob data to hex by
default now.

It's not in the release but mk-merge-mqd-results exists (http://
maatkit.googlecode.com/svn/trunk/mk-query-digest/mk-merge-mqd-results)
which processes files saved by a new mk-query-digest option: --save-
results.  This allows you to save, aggregate and report on results
from several machines.  It works but it's new and still in
development.

Hopefully you won't notice but code that handles output formatting in
several tools was enhanced.  If something looks wrong (column too
short, values truncated, runaway values, etc.), let us know.

Here's the full list of changes for this release:

```
Changelog for mk-error-log:

2010-05-03: version 1.0.3

  * Extended Message column to 78 character line width.

Changelog for mk-kill:

2010-05-03: version 0.9.5

  * Replication threads were allowed to match by default (issue 853).
  * Added --replication-threads (issue 853).
  * Added --all (issue 853).

Changelog for mk-parallel-dump:

2010-05-03: version 1.0.24

  * Added ability to specify a DSN on the command line.

Changelog for mk-parallel-restore:

2010-05-03: version 1.0.22

  * Added ability to specify a DSN on the command line.

Changelog for mk-query-digest:

2010-05-03: version 0.9.17

  * Made --report-format order configurable (issue 990).
  * Changed order of --report-format (issue 935).
  * Added "files" to --report-format (issue 955).
  * Added "date" to --report-format (issue 756).
  * Added --save-results and --[no]gzip (issue 990).
  * --order-by changed the Query_time distribution graph (issue 984).
  * Added --report-histogram (issue 984).
  * Tool crashed immediately on some older versions of Perl (issue 957).

Changelog for mk-slave-prefetch:

2010-05-03: version 1.0.17

  * Made --secondary-indexes use --database db if necessary (issue 998).

Changelog for mk-table-checksum:

2010-05-03: version 1.2.14

  * Added --throttle-method, permit throttling by lag of all slaves (issue 67).
  * Checksum queries still caused fatal warnings on MySQL 5.1 (issue 186).

Changelog for mk-table-sync:

2010-05-03: version 1.0.27

  * Added --[no]hex-blob to HEX() BLOB data by default (issue 641).
  * Tool crashed on MySQL 4.0 due to "SHOW GRANTS" (issue 285).

Changelog for mk-upgrade:

2010-05-03: version 0.9.7

  * Shortened hostname column headers.
```