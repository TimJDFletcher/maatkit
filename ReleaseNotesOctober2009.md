Apart from every script getting a --pid option, this month focused
largely on three scripts: mk-table-sync, mk-slave-prefetch and mk-
upgrade.

mk-table-sync has been significantly refactored.  Except for a few
changes to options (like --algorithm to --algorithms and what it
does), everything else should function as it did and hopefully a
little better, too.  If you use mk-table-sync regularly, be sure to
read its changelog below and test this month's release before you rely
on it.  The internal code changes were made as part of efforts to
further improve the script's reliability, safeness and testability.
Several people have reported bugs recently, some of which are fixed in
this release, others are still pending.

mk-slave-prefetch came into the spotlight thanks to generous
sponsorship.  It too was completely refactored and whereas before it
was mostly untested, its core module has 80%+ test coverage.  Still,
real world testing is needed so if you've been using it or thinking
about using it, you definitely want to use this month's version
because while refactoring it I found and fixed several bugs.  Its
changelog doesn't really reflect all the work it underwent because so
much of the code is new that it's essentially an initial (re-)release.

mk-upgrade continues receive sponsorship and thus continues to be
worked on and improved.  A couple of bugs were fixed and new features
were added.  It's worth upgrading to this version if you use it, too.

Added to this release are two scripts: mk-kill and mk-loadavg.  You
should read their PODs; they're pretty cool.  As irony would have it,
though, just after packaging this release Baron found two bugs in mk-
loadavg (Google Code issues 621 and 622).  These scripts are fully
functional but this is still their debut in the real world.

Below is the changelog for all scripts for this release:

```
Changelog for mk-deadlock-logger:

2009-09-30: version 1.0.17

  * Added --pid (issue 391).

Changelog for mk-heartbeat:

2009-09-30: version 1.0.18

  * Added --pid (issue 391).

Changelog for mk-kill:

2009-09-30: version 0.9.0

  * Initial release.

Changelog for mk-loadavg:

2009-09-30: version 0.9.0

  * Initial release.

Changelog for mk-query-digest:

2009-09-30: version 0.9.10

  * Added --pid (issue 391).

Changelog for mk-slave-delay:

2009-09-30: version 1.0.17

  * Added --pid (issue 391).

Changelog for mk-slave-prefetch:

2009-09-30: version 1.0.12

  * Added --pid (issue 391).

Changelog for mk-slave-restart:

2009-09-30: version 1.0.17

  * Added --pid (issue 391).

Changelog for mk-table-sync:

2009-09-30: version 1.0.19

  * Fixed an infinite loop with the Nibble algorithm (issue 96).
  * Fixed incorrect INSERT values (issue 616).
  * Changed --algorithm to --algorithms and changed what it does.
  * Changed --[no]slave-check to --[no]check-slave.
  * Changed --with-triggers to --[no]check-triggers.
  * Changed --buffer-results to --[no]buffer-to-client.
  * Changed --no-use-index to --[no]index-hint.
  * Added --[no]check-privileges.
  * Added --chunk-index.
  * Added --chunk-column.
  * Added --float-precision (issue 410).
  * Made --verbose cumulative.
  * Master-master sync did not require --no-slave-check.

Changelog for mk-upgrade:

2009-09-30: version 0.9.2

  * Tables from some multi-line queries could not be parsed.
  * CHECKSUM TABLE did not always work.
  * Added --single-host.
  * Added --only-failed-queries.
  * Added --pid (issue 391).

Changelog for mk-visual-explain:

2009-09-30: version 1.0.18

  * Added --pid (issue 391).
```