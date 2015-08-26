Maatkit version 6926 has been released: http://code.google.com/p/maatkit/

All sorts of fixes and enhancements were made in this month's
release.  mk-index-usage had two bug fixes and a new option, --
database (-D).  A bug in mk-kill was fixed to keep it from killing
slave replication threads in certain cases.  Two new rules were added
to mk-query-advisor (released last month), as well as two new
options.  One interesting feature new to mk-query-digest this month is
that it now gets the error message from tcpdump events.  A long-
standing issue with mk-table-checksum and how it does or does not
delete checksums was resolved, and it also got several new filtering
options.  And a bug was fixed in mk-variable-advisor (also released
last month).

Full changelog for this release follows.

```
Changelog for mk-archiver:

2010-09-11: version 1.0.24

   * The DSN documentation was ambiguous and redundant.
   * Added filename argument to before_bulk_insert() and
custom_sth_bulk().

Changelog for mk-index-usage:

2010-09-11: version 0.9.1

   * Default database was changed by iterating schema (issue 1140).
   * Added --database (-D) option (issue 1118).
   * UPDATE LOW_PRIORITY was not parsed correctly (issue 1111).

Changelog for mk-kill:

2010-09-11: version 0.9.7

   * Slave replication threads in "init" or "end" state were killed
(issue 1121)

Changelog for mk-query-advisor:

2010-09-11: version 1.0.1

   * Add rules JOI.003 and JOI.004 (issue 950).
   * Added --[no]show-create-table (issue 950).
   * Added --database (issue 950).

Changelog for mk-query-digest:

2010-09-11: version 0.9.21

   * Empty Schema attribute was not parsed correctly in some cases
(issue 1104).
   * Added /*!50100 PARTITIONS*/ to EXPLAIN line (issue 1114).
   * Added hostname to --report-format (issue 1117).
   * Added MySQL error messages from tcpdump events (issue 670).

Changelog for mk-slave-find:

2010-09-11: version 1.0.14

   * Added "is [not] read_only" to summary report format (issue 1132).

Changelog for mk-table-checksum:

2010-09-11: version 1.2.18

   * Existing checksums were deleted before resuming (issue 304).
   * Lock timeouts were not retried (issue 345).
   * Added --databases-regex (issue 1112).
   * Added --tables-regex (issue 1112).
   * Added --ignore-databases-regex (issue 1112).
   * Added --ignore-tables-regex (issue 1112).

Changelog for mk-variable-advisor:

2010-09-11: version 1.0.1

   * The --source-of-variables filename was made lowercase (issue
1115).
   * Parsing tab-separated output failed (issue 1116).
```