Important in this month's release is bug fixes to mk-parallel-dump and
mk-parallel-restore.  mk-parallel-dump did not work on MySQL 4.0 or
4.1, and mk-parallel-restore did not restore InnoDB tables or tables
with foreign key constraints, and its syntax for InnoDB plugin fast
index creation was incorrect.  The failure to restore InnoDB tables is
not a newly introduced bug; it was present in prior releases.

Speaking of mk-parallel-restore, a serious bug was discovered today
while I was making the release: it can allow DELETE statements to
replicate even if --no-bin-log is specified.  The workaround is to
specify --no-resume because this bug is related to its resume feature
which is enabled by default.  See http://code.google.com/p/maatkit/issues/detail?id=726.

On the positive side of things, mk-query-digest now parses general
logs and HTTP traffic.  mk-log-player now also splits general logs,
too.  mk-loadavg tries really hard to stay connected/get reconnected
to the MySQL server.  And mk-query-digest has new --statistics which
can be very insightful (more will be added later).

mk-upgrade was also completely re-engineered.  It's able to digest
large input and do aggregation.  It was refocused on the concept of
"differences", and its output is much more pleasing to the eye.  Real-
world testing/feedback is still requested.

Do not hesitate to contact us with questions or bug reports via this
list, on Freenode IRC #maatkit, or create an issue at
http://code.google.com/p/maatkit/issues/list.

Here's the full changelog for the release:

```
Changelog for mk-duplicate-key-checker:

2009-12-02: version 1.2.9

  * Added key definitions to report (issue 693).

Changelog for mk-loadavg:

2009-12-02: version 0.9.2

  * The script did not attempt to reconnect to MySQL (issue 692).
  * Added --wait for attempts to reconnect to MySQL (issue 692).

Changelog for mk-log-player:

2009-12-02: version 1.0.3

  * Added general log splitting; --type genlog (issue 172).

Changelog for mk-parallel-dump:

2009-12-02: version 1.0.19

  * Tables were not dumped on MySQL 4.
  * Added --ignore-tables-regex (issue 152).
  * Added --ignore-databases-regex (issue 152).

Changelog for mk-parallel-restore:

2009-12-02: version 1.0.18

  * Failed to restore InnoDB tables (issue 683).
  * Failed to restore tables with foreign key constraints (issue
703).
  * --fast-index caused an error with two or more indexes.
  * Changed --commit to --[no]commit, enabled by default.

Changelog for mk-query-digest:

2009-12-02: version 0.9.12

  * Certain very large queries segfaulted (issue 687).
  * Removed --unique-table-access (issue 675).
  * Added general log parsing; --type genlog (issue 172).
  * Added HTTP protocol parsing; --type http (issue 679).
  * memcached queries were not distilled.
  * DBI was required when not needed (issue 148).
  * Profile report was misaligned.
  * Added --execute-throttle (issue 702).
  * Added --statistics.
  * Added --pipeline-profile.

Changelog for mk-slave-restart:

2009-12-02: version 1.0.19

  * --quiet caused a "Use of uninitialized value" error (issue 673).

Changelog for mk-table-checksum:

2009-12-02: version 1.2.10

  * Removed REPLACE INTO for checking replicate table (issue 365).

Changelog for mk-table-sync:

2009-12-02: version 1.0.22

  * Added note to output when using --dry-run (issue 691).

Changelog for mk-upgrade:

2009-12-02: version 0.9.4

  * Completely redesigned the tool.
```