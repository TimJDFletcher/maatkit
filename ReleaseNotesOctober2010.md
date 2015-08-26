Maatkit version 6960 has been released: http://code.google.com/p/maatkit/

Since it has only been a few weeks since the last release, not much has changed.  In fact, only two things have changed.  The default mk-query-digest review history table now has all the major Percona extended slowlog attributes (http://www.percona.com/docs/wiki/patches:slow_extended).  And mk-index-usage received several new options, the most important of which was --save-results-database.  This new feature allows information about indexes, tables, queries and their usage to be stored in tables for later analysis.  This feature works but is still in development.

Here is the full changelog for this release:
```
Changelog for mk-index-usage:

2010-10-09: version 0.9.2

   * Added --save-results-database option (issue 1015).
   * Added --create-save-results-database option (issue 1015).
   * Added --empty-save-results-tables option (issue 1015).
   * Added --[no]report option (issue 1015).
   * Added --report-format option (issue 1015).
   * Added standard schema object filter options (--databases, --tables, etc).

Changelog for mk-query-digest:

2010-10-09: version 0.9.22

   * Added extended slowlog attribs to query review history table (issue 1149).
```