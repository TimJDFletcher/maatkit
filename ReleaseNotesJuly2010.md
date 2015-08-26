Maatkit version 6652 has been released: http://code.google.com/p/maatkit/

Several bug fixes and enhancements were made in this release, notably work on "zero chunk" in mk-table-checksum and mk-table-sync which finishes a long-running issue about how to handle invalid and zero-equivalent values for chunking.  mk-query-digest was enhanced: progress reports by default every 30 seconds (to STDERR), a MISC item in the profile for all non-reported queries, and a tweak to the "Response time %" to make it match the percents reported in the global report.

Transactions are handled better in mk-table-sync, setting the appropriate tx isolation level and using START TRANSACTION WITH CONSISTENT SNAPSHOT.  Also, its write statements have a bunch of info added in a /**comment**/ for tracing their origins when dumped from binlogs.

Two non-backwards compatible changes in mk-table-checksum: --no-use-index is now --[no](no.md)use-index, and --chunk-index is only used if a chunkable column uses it.

On the developer side of things, we've begun to use branches so more people can develop without interfering with one another.  Releases, starting with this one, are copied into https://maatkit.googlecode.com/svn/releases/ to maintain historical snapshots of the code.  And issues are created for releases (e.g. http://code.google.com/p/maatkit/issues/detail?id=1085) if you care to see what little things go on behind the scenes.  Eventually I'll update the http://code.google.com/p/maatkit/wiki/Developers wiki for all these changes.

Here is the full changelog for July's release:
```
Changelog for mk-parallel-dump:

2010-07-01: version 1.0.26

   * The tool crashed if only empty databases were dumped (issue 1034).
   * Added --[no]zero-chunk (issue 941).

Changelog for mk-purge-logs:

2010-07-01: version 0.9.0

   * Initial release.

Changelog for mk-query-digest:

2010-07-01: version 0.9.19

   * Profile response time % did not match query pct (issue 1073).
   * Added --progress (169).
   * ORDER BY with ASC fingerprinted differently than without ASC (issue 1030).
   * Added MISC items to profile report (issue 1043).

Changelog for mk-slave-prefetch:

2010-07-01: version 1.0.19

   * Relay log file changes could cause tool to wait forever (issue 1075).

Changelog for mk-table-checksum:

2010-07-01: version 1.2.16

   * Changed --no-use-index to --[no]use-index.
   * --schema did not allow --[no]check-replication-filters (issue 1060).
   * --chunk-index is only used if a chunkable column uses it (issue 519).
   * Added --[no]zero-chunk (issue 941).

Changelog for mk-table-sync:

2010-07-01: version 1.0.29

   * Empty result set with MySQL 4.0 could caused a crash (issue 672).
   * Added trace messages to write statements (issue 387).
   * --algorithms was case-sensitive (issue 1065).
   * Hex-like stings were not quoted (issue 1019).
   * The tool didn't set its transaction isolation level (issue 652).
   * Added --[no]zero-chunk (issue 941).
```