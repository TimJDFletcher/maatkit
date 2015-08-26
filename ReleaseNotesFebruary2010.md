In this release we added mk-error-log and made relatively minor changes to several other tools.  We put a lot of effort into improving our testing infrastructure.  The full changelog for individual tools follows:

```
Changelog for mk-error-log:

2010-02-01: version 1.0.0

   * Initial release.

Changelog for mk-kill:

2010-02-01: version 0.9.3

   * Added --kill-query (issue 750).

Changelog for mk-loadavg:

2010-02-01: version 0.9.4

   * Using non-integer --wait value caused a crash (issue 803).
   * Undefined Time value from processlist caused a crash (issue 777).

Changelog for mk-log-player:

2010-02-01: version 1.0.5

   * Added --split-random (issue 798).
   * Added --[no]results.

Changelog for mk-parallel-dump:

2010-02-01: version 1.0.21

   * Database-qualified --tables filters did not work (issue 806).
   * Added --[no]gzip (issue 814).
   * Removed shell calls to mysqldump.

Changelog for mk-query-digest:

2010-02-01: version 0.9.14

   * memcached replace commands were not handled (issue 818).
   * Not all SHOW statements were distilled correctly (issue 735).
   * Tcpdump parsing crashed on certain fragmented queries (issue 832).

Changelog for mk-slave-prefetch:

2010-02-01: version 1.0.15

   * --secondary-indexes queries did not use current database (issue 844).
   * Thread failed to start (issue 680).

Changelog for mk-table-sync:

2010-02-01: version 1.0.24

   * Nibble did not case-insensitively check its index (issue 804).
```