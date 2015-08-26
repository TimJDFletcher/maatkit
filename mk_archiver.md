[issues](http://code.google.com/p/maatkit/issues/list?q=tool-mk_archiver)

This tool is mature and stable.  However, there are a couple of things we can consider improving in the future.

  * Use LOCK TABLES to defer key writes to MyISAM tables.  This can make it more efficient for both a source and a destination table.  LOCK TABLES should mimic the transactional behavior, e.g. lock should be acquired at the point a transaction is opened and released when a transaction would be committed.
  * Add an option to expand a list of columns into an ON DUPLICATE KEY UPDATE clause on the destination table.
  * Make --purge without --file more efficient.  Instead of selecting the primary key of rows to delete and then deleting rows by that key, just DELETE them.  Use the rows\_affected indication in the protocol to find out how many rows were deleted and signal a time to stop.  This behavior should be configurable.

There is also an interesting and potentially unsolvable problem with LIMIT.  The problem is, if fewer than LIMIT rows match the WHERE clause, a SELECT might continue scanning unwanted rows for a very long time.  It would be nice to be able to instruct the tool to scan no more than X rows and then give up (consider there to be no more matches, even if there are unexamined rows).  The only possible solution that has presented itself is a subquery in the FROM clause, e.g.

```
SELECT ... FROM (
   SELECT ... FROM tbl LIMIT 1000
) AS x WHERE .... LIMIT 100
```