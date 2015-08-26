No big surprises in this release, just some enhancements and bug
fixes.  A bug affecting all scripts on some OS (like CentOS and Red
Hat) was fixed.  A bug in mk-parallel-restore was fixed: DELETE
statements replicated despite --no-bin-log ([issue 726](https://code.google.com/p/maatkit/issues/detail?id=726)).  mk-query-
digest tcpdump parsing was improved to handle more difficult inputs.
mk-query-digest now understands server-side prepared statements using
the binary protocol.  And mk-upgrade received a number of
enhancements.  The full changelog for all scripts follows.

A lot of time in December was spent improving the Maatkit test
environment.  More time in January is being spent towards this end.
Want to fully test Maatkit on your server?  Checkout
http://code.google.com/p/maatkit/wiki/Testing and come chat with on in
#maatkit on Freenode IRC.

```
Changelog for mk-archiver:

2010-01-06: version 1.0.21

  * The script crashed immediately on some OS or versions of Perl
(issue 733).
  * Added --check-interval, --check-slave-lag and --max-lag (issue
758).

Changelog for mk-deadlock-logger:

2010-01-06: version 1.0.19

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-duplicate-key-checker:

2010-01-06: version 1.2.10

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-fifo-split:

2010-01-06: version 1.0.7

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-find:

2010-01-06: version 0.9.21

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-heartbeat:

2010-01-06: version 1.0.20

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-kill:

2010-01-06: version 0.9.2

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-loadavg:

2010-01-06: version 0.9.3

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-log-player:

2010-01-06: version 1.0.4

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-parallel-dump:

2010-01-06: version 1.0.20

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-parallel-restore:

2010-01-06: version 1.0.19

  * DELETE statements replicated despite --no-bin-log (issue 726).
  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-query-digest:

2010-01-06: version 0.9.13

  * Missing packets caused mutant queries (issue 761).
  * Tcpdump parsing did not always get the complete query (issue
760).
  * The script crashed immediately on some OS or versions of Perl
(issue 733).
  * Added support for prepared statements (issue 740).
  * Added "prepared" report to default --report-format (issue 740).
  * Added --read-time (issue 226).
  * Error_no attribute was not numeric (issue 669).

Changelog for mk-query-profiler:

2010-01-06: version 1.1.20

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-show-grants:

2010-01-06: version 1.0.21

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-slave-delay:

2010-01-06: version 1.0.19

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-slave-find:

2010-01-06: version 1.0.10

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-slave-move:

2010-01-06: version 0.9.10

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-slave-prefetch:

2010-01-06: version 1.0.14

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-slave-restart:

2010-01-06: version 1.0.20

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-table-checksum:

2010-01-06: version 1.2.11

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-table-sync:

2010-01-06: version 1.0.23

  * The script crashed immediately on some OS or versions of Perl
(issue 733).

Changelog for mk-upgrade:

2010-01-06: version 0.9.5

  * The script crashed immediately on some OS or versions of Perl
(issue 733).
  * Changed output to print sample query instead of fingerprints.
  * Added --fingerprints.
  * Added --convert-to-select (issue 747).
  * Added --shorten.
  * Script crashed when subreport query IDs were too long.

Changelog for mk-visual-explain:

2010-01-06: version 1.0.20

  * The script crashed immediately on some OS or versions of Perl
(issue 733).
```