In February we fixed a number of important bugs in various scripts--
see the Changelog summary below.  Work for mk-query-advisor began; see
http://code.google.com/p/maatkit/wiki/mk_query_advisor or
http://code.google.com/p/maatkit/issues/detail?id=861.  Testing and
test coverage is still a priority.  I increased test coverage over
some poorly covered scripts.  No big surprises in this release so it's
a good time to upgrade if you haven't done so recently (unless you're
running a really old version, in which case you may find surprises).

While writing this I realized that mk-table-sync Changelog doesn't
mention a big addition: --bidirectional.  That feature was kindly
sponsored and developed in February.  It's pretty cool but still
experimental.  If you want to try it, be sure to read the POD section
"BIDIRECTIONAL SYNCING" first, then let us know how it works for you!

As noted on the mailing list, Dario Minnucci is going to keep the
official Debian repo up to date with our latest releases.  Thanks
Dario!

```
Changelog for mk-duplicate-key-checker:

2010-03-01: version 1.2.11

  * Duplicate clustered index names were not preserved (issue 901).
  * Multi-column clustered indexes were not handled correctly (issue
904).

Changelog for mk-error-log:

2010-03-01: version 1.0.1

  * Added --resume (issue 841).

Changelog for mk-log-player:

2010-03-01: version 1.0.6

  * --only-select did not handle leading /* comments */ (issue 903).
  * Not all sessions were assigned/played in some cases.
  * Added --dry-run.
  * Made --quiet disable --verbose.

Changelog for mk-parallel-dump:

2010-03-01: version 1.0.22

  * Added --client-side-buffering (issue 837).
  * Enabled mysql_use_result by default (issue 837).

Changelog for mk-parallel-restore:

2010-03-01: version 1.0.20

  * --fast-index failed to restore some keys (issue 833).

Changelog for mk-query-digest:

2010-03-01: version 0.9.15

  * --explain did not report failures.
  * --ask-pass did not work (issue 795).
  * Made D part of --execute DSN as default database (issue 727).
  * --tcpdump didn't work if dumped packet header had extra info
(issue 906).
  * Added --type pglog for parsing Postgres logs (issue 535).

Changelog for mk-table-checksum:

2010-03-01: version 1.2.12

  * --engines did not work (issue 891).
  * Index names with commas caused a crash (issue 388).

Changelog for mk-table-sync:

2010-03-01: version 1.0.25

  * Row-based replication prevented some changes (issue 95).
```