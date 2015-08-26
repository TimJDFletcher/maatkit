New in this release are mk-upgrade and mk-log-player.  These are not
actually new scripts--they've been around for a month or more--but
they just got added to the release packages.  mk-upgrade is in active
development and continues to need real-world feedback.  Check out
http://code.google.com/p/maatkit/wiki/mk_upgradae to learn all about
it.  At present, we've implement up to most of milestone 2.1 (plus
checking the number and types of columns).  mk-log-player was recently
revamped to be simpler and faster.  If you used mk-log-player in the
past, you'll definitely want to read the new version's POD.

mk-query-digest received a lot of attention and several new features
including memcached parsing, binary log parsing and --since and --
until.  Those last two options are really cool because they allow you
to quickly parse a very precise (down to the second) period of time in
the log; previously, this was difficult to accomplish (it required
advanced --filter skills).

mk-find also got new tests: --column-name, --view, --procedure, --
function, --trigger and --trigger-table.

Common to all scripts are two updates: a fix for Windows and a RISKS
section in the POD.  The scripts are not extensively tested on Windows
and we do not currently have plans to port them completely, but they
at least run now without crashing immediately due to trying to access
Unix environment variables.  mk-query-digest, for example, now works
on Windows (parsing logs at least).  And the RISKS section gives a
brief overview of what risks, if any, the script might pose to your
data and a summary of critical bugs at the time of release (i.e.
today).  Our intention is to make the user more aware of the risks in
using the scripts--most are harmless, but others can cause problems if
not used correctly and carefully.

Here's a summary of all the scripts' changes:

```
Changelog for mk-archiver:

2009-07-31: version 1.0.18

  * Added RISKS section to POD (issue 538).
  * --dry-run did not respect --no-delete (issue 524).
  * The script crashed immediately on Windows (issue 531).

Changelog for mk-audit:

2009-07-31: version 0.9.9

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).

Changelog for mk-deadlock-logger:

2009-07-31: version 1.0.16

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).

Changelog for mk-duplicate-key-checker:

2009-07-31: version 1.2.6

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).

Changelog for mk-fifo-split:

2009-07-31: version 1.0.5

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).

Changelog for mk-find:

2009-07-31: version 0.9.18

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).
  * Added tests --column-name, --view, --procedure, --function, --
trigger
    and --trigger-table.
  * Converted script to runnable module (issue 315).

Changelog for mk-heartbeat:

2009-07-31: version 1.0.16

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).
  * Added --recursion-method option (issue 181).

Changelog for mk-log-player:

2009-07-31: version 1.0.0

  * Initial release.

Changelog for mk-parallel-dump:

2009-07-31: version 1.0.17

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).
  * --threads was ignored if /proc/cpuinfo could be read (issue 534).
  * --default-set with --sets did not work properly (issue 527).
  * Script died on broken tables (issue 170).

Changelog for mk-parallel-restore:

2009-07-31: version 1.0.16

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).
  * --threads was ignored if /proc/cpuinfo could be read (issue 534).

Changelog for mk-query-digest:

2009-07-31: version 0.9.8

  * Added RISKS section to POD (issue 538).
  * Added --since, --until and --aux-dsn (issue 154).
  * Added binary log parsing; --type binlog (issue 476).
  * The script crashed immediately on Windows (issue 531).
  * The rusage report crashed on Windows (issue 531).
  * Added memcached parsing; --type memcached (issue 525).
  * Some boolean attributes didn't print correctly in the report.
  * Added --[no]zero-bool option to suppress 0% bool vals.
  * Improved tcpdump/MySQL protocol parsing (--type tcpdump).
  * Made --continue-on-error negatable and on by default.
  * Changed --attribute-limit to --attribute-value-limit.
  * Added --check-attributes-limit (issue 514).

Changelog for mk-query-profiler:

2009-07-31: version 1.1.18

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).

Changelog for mk-show-grants:

2009-07-31: version 1.0.18

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).

Changelog for mk-slave-delay:

2009-07-31: version 1.0.16

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).

Changelog for mk-slave-find:

2009-07-31: version 1.0.8

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).
  * Added --recursion-method option (issue 181).

Changelog for mk-slave-move:

2009-07-31: version 0.9.8

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).

Changelog for mk-slave-prefetch:

2009-07-31: version 1.0.10

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).
  * Updates to shared code.

Changelog for mk-slave-restart:

2009-07-31: version 1.0.16

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).
  * Added --recursion-method option (issue 181).

Changelog for mk-table-checksum:

2009-07-31: version 1.2.7

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).
  * Added --recursion-method option (issue 181).
  * Added modulo and offset to list of overridable arguments (issue
467).

Changelog for mk-table-sync:

2009-07-31: version 1.0.17

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).
  * Added --recursion-method option (issue 181).
  * Could not sync table to different db or table on different host
(issue 40).
  * Script needlessly checked for triggers on servers <5.0.2 (issue
294).

Changelog for mk-upgrade:

2009-07-31: version 0.9.0

  * Initial release.

Changelog for mk-visual-explain:

2009-07-31: version 1.0.17

  * Added RISKS section to POD (issue 538).
  * The script crashed immediately on Windows (issue 531).
```