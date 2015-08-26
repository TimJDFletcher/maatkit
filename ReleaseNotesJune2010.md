Maatkit version 6457 has been released: http://code.google.com/p/maatkit/

mk-table-checksum received the most attention with numerous fixes and
enhancements.  A few fixes were made to mk-table-sync, too.  And mk-
slave-prefetch got three new options.

A fix was applied to all tools that stops them from clobbering server
SQL modes.  This means the tools now respect and append to whatever
server SQL modes are set when the tool connects.

A new tool was added to the release: mk-index-usage.  It reads queries
from slowlogs and analyzes how they use indexes, suggesting which
unused indexes can be dropped.  It's new and more work, features and
enhancements are planned.

In May we developed new tools for monitoring and failover of a
specific replication topology using row-based idempotent mode
replication.  These tools are currently in Maatkit trunk/util/mysql-
rmf/ because they were created with Maatkit modules, but eventually
they will be moved to their own project.

Following is the full changelog for this release.

```
Changelog for mk-archiver:

2010-06-08: version 1.0.23

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-deadlock-logger:

2010-06-08: version 1.0.21

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-duplicate-key-checker:

2010-06-08: version 1.2.13

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-find:

2010-06-08: version 0.9.23

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-heartbeat:

2010-06-08: version 1.0.22

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-index-usage:

2010-06-08: version 0.9.0

   * Initial release.

Changelog for mk-kill:

2010-06-08: version 0.9.6

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-loadavg:

2010-06-08: version 0.9.6

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-log-player:

2010-06-08: version 1.0.8

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-parallel-dump:

2010-06-08: version 1.0.25

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-parallel-restore:

2010-06-08: version 1.0.23

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-query-digest:

2010-06-08: version 0.9.18

   * Connections did not preserve server SQL modes (issue 801).
   * Added percent of class count to string attribute values (issue 1026).

Changelog for mk-query-profiler:

2010-06-08: version 1.1.22

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-show-grants:

2010-06-08: version 1.0.23

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-slave-delay:

2010-06-08: version 1.0.21

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-slave-find:

2010-06-08: version 1.0.12

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-slave-move:

2010-06-08: version 0.9.12

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-slave-prefetch:

2010-06-08: version 1.0.18

   * Connections did not preserve server SQL modes (issue 801).
   * Added --[no]inject-columns (issue 1003).
   * Added --relay-log-dir (issue 288).
   * Added --sleep.

Changelog for mk-slave-restart:

2010-06-08: version 1.0.22

   * Connections did not preserve server SQL modes (issue 801).
   * Sleep time reported by --verbose might have been incorrect.

Changelog for mk-table-checksum:

2010-06-08: version 1.2.15

   * Chunking did not work with invalid dates (issue 602).
   * --replicate with InnoDB checksum table didn't work with --wait (issue 51).
   * Connections did not preserve server SQL modes (issue 801).
   * --empty-replicate-table did not work with replication filters (issue 982).
   * --replicate-check=0 did not skip the checksumming step (issue 1020).
   * MySQL 5.1 and --replicate need REPEATABLE READ isolation level (issue 720).
   * The --replicate table was not required to specify a database (issue 982).
   * Added --[no]check-replication-filters for --replicate sanity (issue 993).
   * Added --replicate-database to select a single default database (issue 982).
   * Added --chunk-column and --chunk-index (issue 519).

Changelog for mk-table-sync:

2010-06-08: version 1.0.28

   * Chunking failed on invalid dates (issue 602).
   * --replicate caused chunking parameters to be ignored (issue 996).
   * "0x" was used instead of "" for empty blob and text values (issue 1052).
   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-upgrade:

2010-06-08: version 0.9.8

   * Connections did not preserve server SQL modes (issue 801).

Changelog for mk-visual-explain:

2010-06-08: version 1.0.22

   * Connections did not preserve server SQL modes (issue 801).
```