Various fixes were made to mk-query-digest.  One in particular
involves administrator commands and changed how these types of
commands are fingerprinted.  Therefore, beware that query IDs for
admin commands have changed.  A performance regression introduced in
v0.9.12/[r5240](https://code.google.com/p/maatkit/source/detail?r=5240) was fixed.

Several tools now accept a DSN on the command line (where previously
you had to use options like -h and -P): mk-duplicate-key-checker, mk-
heartbeat, etc.

Important bugs where fixed in mk-table-sync, mk-table-checksum, mk-
parallel-restore, mk-slave-prefetch and mk-upgrade.

We've been trying to address older issues.  In that effort we finally
did [issue 55](https://code.google.com/p/maatkit/issues/detail?id=55) which puts a tool's available DSN keys/parts in the POD
so when you tool --help the DSN keys listed there are up-to-date and
authoritative (e.g. mk-archiver).  Some enhancements were made to mk-
find to make it find more stuff.  And "SHOW GRANTS" has been handled
in way that should increase compatibility with MySQL 4.

Maatkit has a booth in the DotOrg Pavilion at the MySQL Conference &
Expo, so if you're attending stop by and see us!

Here's the full list of changes for this release:

```
Changelog for mk-archiver:

2010-04-01: version 1.0.22

  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-deadlock-logger:

2010-04-01: version 1.0.20

  * The same deadlock was reprinted with --interval (issue 943).
  * --clear-deadlocks did not work with --interval (issue 942).
  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-duplicate-key-checker:

2010-04-01: version 1.2.12

  * Added ability to specify a DSN on the command line.
  * Added DSN OPTIONS section to POD (issue 55).
  * Stopped caching SHOW CREATE TABLE info.

Changelog for mk-error-log:

2010-04-01: version 1.0.2

  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-find:

2010-04-01: version 0.9.22

  * Added --column-type test (issue 25).
  * Added ability to test for NULL size (issue 344).
  * --ask-pass didn't work if --password was specified.
  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-heartbeat:

2010-04-01: version 1.0.21

  * Added ability to specify DSN on the command line.
  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-kill:

2010-04-01: version 0.9.4

  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-loadavg:

2010-04-01: version 0.9.5

  * Added ability to specify a DSN on the command line.
  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-log-player:

2010-04-01: version 1.0.7

  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-parallel-dump:

2010-04-01: version 1.0.23

  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-parallel-restore:

2010-04-01: version 1.0.21

  * --fast-index was case-sensitive (issue 956).
  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-query-digest:

2010-04-01: version 0.9.16

  * Admin commands were not always distilled (issue 676).
  * Admin commands were not fingerprinted correctly (issue 676).
  * General log parsing failed sometimes (issue 926).
  * Some general log timestamps were not parsed (issue 972).
  * IP addresses were truncated (issue 744).
  * Some options could fail to parse (issue 940).
  * InnoDB_*_wait attributes were not formatted as times (issue 948).
  * Added --show-all (issue 744).
  * Added DSN OPTIONS section to POD (issue 55).
  * Fixed performance regression introduced in v0.9.12/r5240 (issue
954).
  * Queries with tables in parentheses did not distill correctly
(issue 781).

Changelog for mk-query-profiler:

2010-04-01: version 1.1.21

  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-show-grants:

2010-04-01: version 1.0.22

  * Added ability to specify a DSN on the command line.
  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-slave-delay:

2010-04-01: version 1.0.20

  * Privileges needed for operation weren't documented (issue 939).
  * --ask-pass crashed if h DSN part wasn't specified (issue 949).
  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-slave-find:

2010-04-01: version 1.0.11

  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-slave-move:

2010-04-01: version 0.9.11

  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-slave-prefetch:

2010-04-01: version 1.0.16

  * --secondary-indexes did not work (issue 932).
  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-slave-restart:

2010-04-01: version 1.0.21

  * Added ability to specify a DSN on the command line.
  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-table-checksum:

2010-04-01: version 1.2.13

  * Checksum queries caused fatal warnings on MySQL 5.1 (issue 186).
  * Added DSN OPTIONS section to POD (issue 55).
  * Tool crashed if no DSN h part was specified (issue 947).

Changelog for mk-table-sync:

2010-04-01: version 1.0.26

  * --trim caused impossible WHERE and invalid SQL (issue 965).
  * Tool crashed using --ask-pass if no DSN h part was specified
(issue 947).
  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-upgrade:

2010-04-01: version 0.9.6

  * --compare-results-method=rows did not use default database (issue
951).
  * --compare-results-method=rows did not use --temp-database (issue
951).
  * Added DSN OPTIONS section to POD (issue 55).

Changelog for mk-visual-explain:

2010-04-01: version 1.0.21

  * Added DSN OPTIONS section to POD (issue 55).
```