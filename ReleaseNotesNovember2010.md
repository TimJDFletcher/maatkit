Maatkit version 7041 has been released: http://code.google.com/p/maatkit/

This month's release of Maatkit is a short but significant Changelog.  Firstly, mk-query-digest has new information and a cleaner output.  The new information is a "Scores" line for each query event/class that includes a variance-to-mean ratio and an Apdex score.  The output has been regrouped so numeric, bool and string values are all together, and InnoDB attribute values are together, too.

mk-index-usage's --save-results option has been improved and Baron wrote into the POD several examples on how to query the saved results to answer very interesting questions about index usage.

And mk-archiver has two new features.  The first automatically removes "LIMIT 1" from DELETE statements when it's safe to do so.  This avoids needless warning messages in the MySQL error log.  The second is an advanced option that also allows the LIMIT clause to be removed from bulk delete operations (also to avoid needless error messages in the log).  This is for advanced users who know when and where it's ok to enable this option.

Following is the full changelog:
```
Changelog for mk-archiver:

2010-11-08: version 1.0.25

   * Removed LIMIT 1 from DELETE only when index is unique (issue 1166).
   * Added --[no]bulk-delete-limit option (issue 1170).

Changelog for mk-index-usage:

2010-11-08: version 0.9.3

   * Changed --save-results to save results at end of run.
   * Added progress reports to the schema & table inventory (issue 1174).

Changelog for mk-query-advisor:

2010-11-08: version 1.0.2

   * Added rule CLA.006 to detect mixed table GROUP/ORDER BY (issue 1137).

Changelog for mk-query-digest:

2010-11-08: version 0.9.23

   * Rearranged and regrouped query event output (issue 696).
   * Added variance-to-mean ratio (V/M) to output (issue 1124).
   * Added --apdex-threshold option and Apdex score to output (issue 1054).
```