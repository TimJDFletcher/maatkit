# Synopsis #

QueryRanker ranks query execution results from QueryExecutor. (See comments on QueryExecutor::exec() for what an execution result looks like.)  We want to know which queries have the greatest difference in execution time, warnings, etc. when executed on different hosts.  The greater a query's differences, the greater its rank.

The order of hosts does not matter.  We speak of host1 and host2, but neither is considered the benchmark.  We are agnostic about the hosts; it could be an upgrade scenario where host2 is a newer version of host1, or a downgrade scenario where host2 is older than host1, or a comparison of the same version on different hardware or something.  **So remember**: we're only interested in "absolute" differences and no host has preference.

A query's rank (or score) is a simple integer.  Every query starts with a zero rank.  Then its rank is increased when a difference is found.  How much it increases depends on the difference.  This is discussed next; it's different for each comparison.

# Execution Time and Warnings #

A query is executed and timed on each host.  The query's rank is increased for one of two reasons.  First, if the two times are in the same general time range (or "bucket") and the increase from the faster time to the slower time exceeds a threshold value for that time range, then the query's rank is increased by 1.

The general time ranges are:
  1. 1us  (0-9us)
  1. 10us (tens of microseconds)
  1. 100us (hundreds of microseconds)
  1. 1ms  (etc.)
  1. 10ms
  1. 100ms
  1. 1s
  1. 10s+

The threshold values for these time ranges are subjective.  For present values, see inside QueryRanker.pm.

If the query cannot be executed, its rank is increase by 100.

After the query is executed, its warnings from each host are compared.  (By "warnings" we mean but warnings and errors.) If the query has any warnings on either host, its rank is increased by 1.

A query's rank increases proportionately to the absolute difference in its warning counts (@@warning\_count).  So if a query produces a warning on host1 but not on host2, or vice-versa, its rank increases by 1.

A query's rank is also increased by 2 for every old warning (i.e. every warning that is the same code on both hosts) that differs in level; e.g. if it's an error on host1 but a warning on host2, this may seem like a good thing (the error goes away) but it's not because it's suspicious and suspicious leads to surprises and we don't like surprises.

And a query's ranks is increased by 3 for every new warning (i.e. a warning on one host but not the other).

Here's a summary of time and warning differences and their respective rank increase:

| Difference | Rank Increase |
|:-----------|:--------------|
| Query times in same range but increase beyond range's threshold | 2             |
| Query times in different ranges | 2 `*` (high range - low range) |
| Query cannot be executed | 100           |
| Query has warnings | 1             |
| Warning counts | abs(host1 warning count - host2 warning count) |
| Warning level changes | 2 `*` each changed warning level |
| New warning | 3 `*` each new warning |


# Other Ranks (TODO) #

Other rank metrics are planned: difference in result checksum, in EXPLAIN
plan, etc.