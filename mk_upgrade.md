  * [issues](http://code.google.com/p/maatkit/issues/list?q=label:Tool-mk_upgrade)


This tool is under active development in milestone 2.  **Your sponsorship and testing are sought**.  An initial implementation of this tool is done, and we need to continue development.

This tool executes a set of queries against servers, and compares the results and query plans.  This is useful for finding problems before an upgrade, or verifying that any other change does not cause adverse effects (converting a table to InnoDB, for example; or changing a server or client configuration setting).  There is discussion in [this mailing list thread](http://groups.google.com/group/maatkit-discuss/browse_thread/thread/49f4564111c78a2f) and [issue 422](https://code.google.com/p/maatkit/issues/detail?id=422).

## Feature Prioritization ##

A lot of the features or proposed features are harder than others.  For example, it's easier to do stateless SELECTs than anything else.  Order of priority:

  1. First milestone is done.
  1. Second milestone:
    1. Checksum the results of SELECTs; use SET TIMESTAMP and USE only to handle non-determinism
    1. Fingerprint EXPLAIN plans and report how many there are, and whether they match
    1. Add to score: result differences, number and match of EXPLAIN fingerprints
    1. Make it easier to run the tool when only one server is available: output a diff-able format and/or make a helper tool to diff the output of one server against another.
  1. Third milestone:
    1. Handle more non-deterministic things in queries (wait and see what they are)
    1. Transform non-SELECTs to SELECTs and checksum the results
    1. Try to analyze the shape of distributions (such as execution time)
    1. Rank query execution plans.
    1. Capture before/after counter differences.
    1. Add the above to the score.

Features we'll put off at first, but which are still important:

  1. Handle difficult statefulness, such as replaying queries in different connections so each session is reconstructed; temporary tables; etc
  1. Handle stored procedures
  1. Use `SHOW PROFILES`

## Assumptions ##

  * Both servers are otherwise unused; everything we can measure about the servers and queries is due to the known workload.

## Overall Strategy ##

Connect to both servers.  Read queries from a slow query log, or any other source for which we have a parser (see [issue 172](https://code.google.com/p/maatkit/issues/detail?id=172), [issue 426](https://code.google.com/p/maatkit/issues/detail?id=426)).  For each query,

  1. Apply any desired transformations to the query.
  1. Set any necessary settings such as `SET TIMESTAMP`.
  1. `EXPLAIN` and/or execute the query on both servers.
  1. Capture the results and aggregate them.
  1. When finished (end-of-file, --run-time exceeded etc), print out the report.

## Settings and Transformations ##

Possible settings we'll need to set:

  1. `SET TIMESTAMP`
  1. `USE` the correct database

We will need to transform queries in many cases to work around non-determinism.  Here are some specific cases:

  * Date and time functions.  These can be solved by using `SET TIMESTAMP` in some cases.
    * For cases where it cannot, we will need to do a string substitution to inject a constant into the query.  This includes `SYSDATE`.
  * Floating-point precision differences.  How we work around this depends on which strategy we use to compare results.
  * Non-deterministic functions CONNECTION\_ID(), USER(), CURRENT\_USER(), UUID(), VERSION().  The USER ones should actually be okay unless one connects to the servers with different usernames.
  * Server variables such as @@server\_id, @@hostname, @@version, @@version\_comment may differ.  We probably just need to always do a string substitution: select the value from the first server and string-replace it into the query text on both servers.
  * Queries against INFORMATION\_SCHEMA tables.
  * The RAND() function.  We can make it deterministic by using rand() in the perl code to choose a seed, and string-replacing that seed into the query.

## Failures and warnings ##

Failures and warnings to capture:

  1. Run `SHOW WARNINGS` after each query.  If a new enough DBD::mysql is installed, we can check $sth->{mysql\_warning\_count} after the query, which will be more efficient.
  1. Capture parse errors.
  1. Capture execution errors: deadlock, lock wait timeout, and any other execution errors.

## Differences in results ##

This should be an optional measurement.  There are a couple of different ways we could do this.

  1. The simplest is to `SET storage_engine=MyISAM` and prepend `CREATE TEMPORARY TABLE mk_upgrade AS` to SELECT statements, then execute `CHECKSUM TABLE mk_upgrade`.  We can also execute `SHOW CREATE TABLE mk_upgrade` and checksum that, then see if there are differences.
    * More complex ways would involve wrapping the statement in a checksum SQL statement similar to those mk-table-checksum creates, but this will be difficult and time-consuming to get right, and might not even be possible.
  1. Capture the row count.
  1. Checksum all tables involved in statements that modify data.  (We have code to discover those tables already.)

Depending on the query and the changes in the server, we could see differences in:

  * row count
  * row data
  * row sort order
  * column count (ex: changes in `NATURAL JOIN`)
  * column data type
  * table data (after a data modification query)

Some of these are hard to analyze exactly, such as differences in sort order.  (Will `CHECKSUM TABLE` capture that?  If not, we need to use mk-table-checksum queries against the temp table.  This is TODO.)  It is also much harder to deal with modifications.

## Differences in execution time ##

This is probably the simplest thing to measure.  One thing I'm interested in is measuring the shape of the distribution.  I don't think that the standard deviation is a good enough metric, although it's better than nothing.  I'd like to know if there are differences in

  * Average, min and max
  * Standard deviation
  * Number and placement of peaks in the distribution
  * Shape of the distribution overall (e.g. long-tail?  normal?)

## Differences in execution plan ##

Execution plan is difficult.  I think we need to come up with a way to "fingerprint" an `EXPLAIN` plan (see also [issue 201](https://code.google.com/p/maatkit/issues/detail?id=201)).  We can also consider using `SHOW PROFILES`, but I will put that off for the future -- it is not yet at a high adoption rate, so it will not be useful enough of the time.

I think not only do we need to fingerprint an execution plan, but we need to rank an execution plan's efficiency, so we can tell the difference between plans that are the same but will not execute as efficiently (example: rows is much different, key\_len changes).

Here are the differences that should make an EXPLAIN fingerprint differ from another:

  * tables mentioned
  * table order
  * for a given table, in order of decreasing importance:
    * type column.  We should rank the types and assign a numeric score to each.  We can start with [the way the MySQL manual ranks them](http://dev.mysql.com/doc/refman/5.0/en/using-explain.html), but it's not as simple as 1-2-3.
    * key column
    * The 'diff' of the Extra column (after splitting it into parts around ';').  These need to be ranked and scored too.
    * rows column.
      * These numbers are significant: 0 and 1.  If the before is 0 or 1 and the after isn't, that's significant; vice versa too.  Beyond that, I think we need to look for logarithmic increases, perhaps letting the user specify the base of the logarithm.  For example, the ranking factor is C times log-base-B of the rows column, where C and B are user-specifiable and might be 1 and 2 by default.  TODO: this doesn't seem right, it'll give false positives for small values.
      * With 5.1, `LIMIT` is respected in the estimate, so when comparing queries with a `LIMIT` pre-5.1 to 5.1 or newer, it is only significant if this column increases.
    * key\_len column.  Rank and score by normalizing to 1.
    * possible\_keys column
    * if the type and key are the same, then a different ref is significant.

I think we should

  * Record each execution plan found, and report the histogram of them, as well as differences in the "shape" of the histogram (see above).
  * Report how many distinct plans there are.
  * Report the aggregate score difference of serverA versus serverB.

## Differences in counters ##

Capture key differences in `SHOW STATUS` and aggregate them.  I think the following are interesting.  When displaying these, zeroes/non-differences should be suppressed.  These should also be ranked so we can score the difference in cost of the query yet another way.

  * Created\_tmp\_disk\_tables
  * Created\_tmp\_files
  * Created\_tmp\_tables
  * Handler\_delete
  * Handler\_read\_first
  * Handler\_read\_key
  * Handler\_read\_next
  * Handler\_read\_prev
  * Handler\_read\_rnd
  * Handler\_read\_rnd\_next
  * Handler\_update
  * Handler\_write
  * Innodb\_data\_written
  * Innodb\_data\_read
  * Innodb\_rows\_deleted
  * Innodb\_rows\_inserted
  * Innodb\_rows\_read
  * Innodb\_rows\_updated
  * Key\_read\_requests
  * Key\_reads
  * Key\_write\_requests
  * Key\_writes
  * Last\_query\_cost
  * Qcache\_hits
  * Qcache\_inserts
  * Qcache\_lowmem\_prunes
  * Qcache\_not\_cached
  * Select\_full\_join
  * Select\_full\_range\_join
  * Select\_range
  * Select\_range\_check
  * Select\_scan
  * Sort\_merge\_passes
  * Sort\_range
  * Sort\_rows
  * Sort\_scan

## Related reading ##

See also

  * http://pgtap.projects.postgresql.org/