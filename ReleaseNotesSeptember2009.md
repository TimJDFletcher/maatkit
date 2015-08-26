This month's release has a number of good bug fixes.  For mk-table-
checksum, --arg-table was not used to determine the algorithm.  If you
use mk-table-checksum --arg-table you should definitely upgrade.  For
mk-table-sync, --lock 3 did not work.  If you've been using this, you
should upgrade, too.  --ask-pass didn't work in mk-heartbeat, mk-show-
grants or mk-slave-prefetch.  And for mk-archiver, --dest did not
inherit the password from --source.

For all scripts the interaction/inheritance between DSNs and the
standard connection options like --host, --port, etc. was fixed or
improved.  Now the connection options always act as defaults for
missing DSN values.

We continued working on and improving mk-query-digest as well as mk-
upgrade.  For this later, a lot of work was done actually; see the new
--compare-results-method option.  The output is still rough, but it
shows missing rows, different rows, and at what column different rows
begin differing.

Below is a list of all scripts' changes for this release:

```
Changelog for mk-archiver:

2009-08-31: version 1.0.19

  * --dest did not inherit password from --source (issue 460).
  * Added standard connection options like --host, --port, etc.(issue
248).

Changelog for mk-audit:

2009-08-31: version 0.9.10

  * The script crashed if mysql.proc is missing (issue 187).

Changelog for mk-duplicate-key-checker:

2009-08-31: version 1.2.7

  * "DROP FOREIGN KEY" was not printed for foreign keys (issue 548).
  * Enhanced rules for clustered keys (issue 295).
  * Changed "key" to "index" in output where appropriate (issue 548).

Changelog for mk-find:

2009-08-31: version 0.9.19

  * No tables were printed if no tests were given (issue 549).

Changelog for mk-heartbeat:

2009-08-31: version 1.0.17

  * --ask-pass did not work.

Changelog for mk-log-player:

2009-08-31: version 1.0.1

  * Added --filter for --split (issue 571).
  * Added support for splitting binary logs; --type binlog (issue
570).
  * Added --type option (issue 570).

Changelog for mk-query-digest:

2009-08-31: version 0.9.9

  * LOCK and UNLOCK TABLES were not distilled (issue 563).
  * Large MySQL packets were not handled.
  * The script crashed on queries with MySQL reserved words as column
names.
  * The script crashed on empty input to --type tcpdump|memcached
(issue 564).
  * --filter did not always compile correctly (issue 565).
  * Added standard connection options like --host, --port, etc.(issue
248).
  * --processlist didn't set first_seen and last_seen for --review
(issue 360).
  * --daemonize caused --processlist to fail with "server has gone
away".
  * Could not parse vebose tcpdump output with ASCII dump (issue
544).
  * Changed --[no]zero-bool to --zero-bool.
  * Added --inherit-attirbutes (issue 479).
  * Changed the --report option to only control if report is printed.
  * Removed string attributes from global report header (issue 478).

Changelog for mk-show-grants:

2009-08-31: version 1.0.19

  * --ask-pass did not work.

Changelog for mk-slave-prefetch:

2009-08-31: version 1.0.11

  * --ask-pass did not work.

Changelog for mk-table-checksum:

2009-08-31: version 1.2.8

  * --arg-table was not used to determine algorithm (issue 509).

Changelog for mk-table-sync:

2009-08-31: version 1.0.18

  * Added --[no]check-master (issue 110).
  * --lock 3 did not work (issue 86).
  * The script did not work with MySQL replicate-do-db (issue 533).
  * Removed --[no]utf8.  Pass the C<A> option in a DSN instead.
  * Added standard connection options like --host, --port, etc.(issue
248).
  * --databases was not honored when using --replicate (issue 367).

Changelog for mk-upgrade:

2009-08-31: version 0.9.1

  * The printed value for Host2_Query_time was incorrect.
```