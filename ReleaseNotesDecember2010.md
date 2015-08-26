Maatkit version 7119 has been released: http://code.google.com/p/maatkit/

This month, mk-query-digest received two new sparklines: for --report-histogram and --explain.  See its documentation for how these sparklines work.  mk-kill was updated so that its behavior with respect to --run-time is like other tools (i.e. it runs forever by default now); as a result, --iterations was removed.  We double-checked all tools' options and fixed a few inconsistencies (e.g. mk-archiver --quiet didn't have standard short form -q).  Further improvements were made to mk-variable-advisor.

Several new options were added to mk-kill, but they're not yet in its Changelog because they're still works in progress (but they're tested and working actually).  The new options are --all-but-oldest, --group-by, --each-busy-time and --query-count.  These are parts of a feature that allow "cache stampedes" to be detected and killed.  See http://code.google.com/p/maatkit/issues/detail?id=1181 for more information.  If you try this feature, please provide us feedback.

And you may notice that all tools' SYNOPSIS sections in the POD are different.  This is because that text is now used to created the --help output (formerly, --help output and whatever was in SYNOPSIS weren't the same).  This helps to make the tools' behavior and documentation more consistent.

Here is the full changelog for all tools...
```
Changelog for mk-archiver:

2010-12-11: version 1.0.26

   * Added -q short form for --quiet option.

Changelog for mk-kill:

2010-12-11: version 0.9.8

   * Removed --iterations option.
   * Changed --run-time behavior to match other tools.
   * Added options --sentinel and --stop.
   * Added more --heartbeat messages.

Changelog for mk-loadavg:

2010-12-11: version 0.9.7

   * Added short form -w for option --wait.

Changelog for mk-log-player:

2010-12-11: version 1.0.9

   * --charset (-A) did not work (issue 1177).
   * Added -q short form for --quiet option.

Changelog for mk-query-advisor:

2010-12-11: version 1.0.3

   * Fixed false-positive ARG.001 matches (issue 1163).
   * Added rule CLA.007 to detect different ORDER BY directions (issue 1158).

Changelog for mk-query-digest:

2010-12-11: version 0.9.24

   * Added sparkline of --report-histogram (issue 1141).
   * Added EXPLAIN sparkline (issue 1141).

Changelog for mk-slave-delay:

2010-12-11: version 1.0.23

   * The tool ran even if the SQL thread was not running (issue 1169).

Changelog for mk-slave-find:

2010-12-11: version 1.0.15

   * --database option did not work.

Changelog for mk-table-checksum:

2010-12-11: version 1.2.19

   * Added --progress option (1151).
   * Added short form -c for option --columns.
```