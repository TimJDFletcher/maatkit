This release is a great one and you should really update to it, imho.
Last month's release introduced a completely refactored mk-table-sync
which naturally incurred some bugs.  Undeterred, however, several
people from the community lent a lot of help, time, test cases, etc.
and now mk-table-sync is better than it's ever been.

Many scripts received bug fixes and new features; I'll leave it to you
to peruse the changelogs below.

Apart from mk-table-sync, mk-parallel-dump and mk-parallel-restore are
the highlight of this release.  They have been stripped down, cleaned
up and more thoroughly tested.  These scripts were never meant to do
backups, but they had crept into that role anyway.  So this month we
refocused them, making them simpler, less bug-prone and more reliable
and resilient.  If you use either of these scripts you **must** read
their changelogs and PODs.

Also of note is that this is the first release done entirely by me.
Baron had always helped with past releases, but this one is 100% my
doing, from the download files on Google Code to the documents on
maatkit.org.  Therefore, if something looks amiss, do not hesitate to
contact me.

Thanks again to the many people who submitted bugs.  You can contact
us via several means: create an issue on Google Code, join the Maatkit
discussion list, email me directly, or chat with us on Freenode at
#maatkit.

```
Changelog for mk-archiver:

2009-10-30: version 1.0.20

  * Added --sleep-coef (issue 540).
  * --primary-key-only on table without a primary key caused error
(issue 655).
  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-audit:

2009-10-30: version 0.9.11

  * --set-vars did not work (issue 597).

Changelog for mk-deadlock-logger:

2009-10-30: version 1.0.18

  * Added --create-dest-table (issue 386).
  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-duplicate-key-checker:

2009-10-30: version 1.2.8

  * Printing duplicate key with prefixed column caused crash (issue
663).
  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-fifo-split:

2009-10-30: version 1.0.6

  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-find:

2009-10-30: version 0.9.20

  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-heartbeat:

2009-10-30: version 1.0.19

  * Removed the --time long option.  Use --run-time instead.
  * --set-vars did not work (issue 597).

Changelog for mk-kill:

2009-10-30: version 0.9.1

  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-loadavg:

2009-10-30: version 0.9.1

  * --watch Processlist did not work.
  * Changed --sleep to --interval.
  * --execute-command created zombies/defunct processes (issue 643).
  * --set-vars did not work (issue 597).
  * Actions were not triggered properly (issue 621).
  * A database connection was required when not need (issue 622).
  * Changed default vmstat command to "vmstat 1 2" (issue 621).
  * Command line options did not override config file options (issue
617).

Changelog for mk-log-player:

2009-10-30: version 1.0.2

  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-parallel-dump:

2009-10-30: version 1.0.18

  * Removed sets and all set-related options (issue 637).
  * Removed --since (issue 636).
  * Removed dump file compression and --[no]gzip (issue 639).
  * Removed ability to "write your own command line" (issue 638).
  * Removed ability to dump triggers and views (issue 316).
  * Removed all statements except CREATE TABLE and INSERT from dump
files.
  * Did not dump tables with spaces in their names (issue 446).
  * Added --[no]resume (issue 495).
  * Added --mysqldump.
  * --progress did not respect --ignore-engines (issue 573).
  * --progress was incorrect with --chunk-size (issue 642).
  * --set-vars did not work (issue 597).
  * Changed output format of --verbose and --progress.
  * Command line options did not override config file options (issue
617).

Changelog for mk-parallel-restore:

2009-10-30: version 1.0.17

  * Removed ability to restore triggers and views (issue 316).
  * Older versions of mysqldump caused "Query was empty" errors
(issue 625).
  * Tool caused a slave error in some cases (issue 506).
  * --create-databases did not respect --no-bin-log.
  * --set-vars did not work (issue 597).
  * --databases did not work with --database (issue 624).
  * Added --fast-index for fast InnoDB index creation.
  * Added --only-empty-databases (issue 300).
  * Added --[no]create-tables.
  * Added --[no]drop-tables.
  * SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" was not set by default.
  * Tables were not explicitly unlocked.
  * Command line options did not override config file options (issue
617).

Changelog for mk-query-digest:

2009-10-30: version 0.9.11

  * Gathering RSS and VSZ didn't work on Solaris (issue 619).
  * Tool died on unknown binary log event types (issue 606).
  * Binlogs could cause "unintended interpolation of string" error
(issue 607).
  * --set-vars did not work (issue 597).
  * Added /*!50100 PARTITIONS */ for --explain (issue 611).
  * Added --table-access (issue 661).
  * Added --unique-table-access (issue 661).
  * Command line options did not override config file options (issue
617).

Changelog for mk-query-profiler:

2009-10-30: version 1.1.19

  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-show-grants:

2009-10-30: version 1.0.20

  * Added ability to do --only foo for foo grants on all hosts (issue
551).
  * Added --[no]header.
  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-slave-delay:

2009-10-30: version 1.0.18

  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-slave-find:

2009-10-30: version 1.0.9

  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-slave-move:

2009-10-30: version 0.9.9

  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-slave-prefetch:

2009-10-30: version 1.0.13

  * Tool died on unknown binary log event types (issue 606).
  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-slave-restart:

2009-10-30: version 1.0.18

  * --monitor --stop caused error Option maxlength does not exist
(issue 662).
  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-table-checksum:

2009-10-30: version 1.2.9

  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-table-sync:

2009-10-30: version 1.0.21

  * Fixed an infinite loop with the Nibble algorithm (issue 644).
  * Nibble could fail to sync small tables (issue 634).
  * --set-vars did not work (issue 597).
  * Column order was not preserved in SQL statments (issue 371).
  * GroupBy and Stream algorithms did not reset after first table
(issue 631).
  * Command line options did not override config file options (issue
617).

Changelog for mk-upgrade:

2009-10-30: version 0.9.3

  * Added --[no]compare-query-times.
  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).

Changelog for mk-visual-explain:

2009-10-30: version 1.0.19

  * --set-vars did not work (issue 597).
  * Command line options did not override config file options (issue
617).
```