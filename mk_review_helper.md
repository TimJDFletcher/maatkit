[issues](http://code.google.com/p/maatkit/issues/list?q=label:Tool-mk_review_helper)

This tool does not yet exist.  It will be a companion program to [mk\_query\_digest](mk_query_digest.md), and will have two broad categories of functionality:

  1. Manipulate and analyze the information mk-query-digest has stored in review and review-history tables.
  1. Manipulate the textual output from mk-query-digest's report.

The roadmap is as follows:

  * Build functionality to look at queries stored in --review-history tables and find queries whose execution plan, frequency, or performance has changed in a statistically significant way.  These need to be reviewed.
  * Produce textual reports on arbitrary queries from the same, according to user preferences; by default, the queries that look important will print out a report in the same format as mk-query-digest's default report.  See [issue 739](https://code.google.com/p/maatkit/issues/detail?id=739).
  * Less important: see [issue 204](https://code.google.com/p/maatkit/issues/detail?id=204), [issue 193](https://code.google.com/p/maatkit/issues/detail?id=193), and [issue 194](https://code.google.com/p/maatkit/issues/detail?id=194) comment 8.