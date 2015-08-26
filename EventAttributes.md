Events can have the attributes (a.k.a. attribs, properties or props) listed below.  Some attributes are only available in certain input.  For example, Warning\_count is only available in tcpdump input.  Even then, an attribute is only available if it actually appeared in the input or could be calculated.  Therefore, do not always assume that an attribute is available.

Versions of mk-query-digest after [r3968](https://code.google.com/p/maatkit/source/detail?r=3968) auto-detect and print almost all attribs that it discovers.  Certain properties are ignored; see mk-query-digest's default value for --ignore-attributes.

## Attribute Classes ##
There are four classes of attributes: internal, normal, SET and Percona-patch.

Internal attribs do not appear in the input (i.e. the slow log, tcpdump, or processlist) but are created by the event parsing module (i.e. SlowLogParser, MySQLProtocolParser, Processlist, MemcachedEvent).  Internal attribs help accomplish various things inside the code.  They are generally ignored by the user.  Once exception is memcached attributes; see below.

Normal attribs do appear in the input; they are the ones with which you're most familiar: Query\_time, Lock\_time, etc.  These attributes come from the event's header.

SET attribs also appear in the input but unlike normal attributes they do not appear in the event's header.  Rather, they are attributes from SET statements.  The statement `SET insert_id=123;` creates an insert\_id attribute with value 123.

Percona-patch attribs are also appear in the input and the event's header but only if you're using a Percona-patched server or Percona binary.

Knowing these attributes can help you write fancy --filter subs for mk-query-digest or know which attributes to --select or --ignore-attributes.

## memcached ##

As of roughly [r4159](https://code.google.com/p/maatkit/source/detail?r=4159), mk-query-digest can parse memcached data from a tcpdump (mk-query-digest --type memcached).  Several memcached attributes come from the protocol, like cmd, key, val and res.  These are generally not used by the user and so they're listed as internal attributes.  But from these several normal attributes are created which begin with "Memc_"._

### Internal attributes ###

| Attribute | Input | Description |
|:----------|:------|:------------|
| arg       | All   | The query text, or, in case it's an admin command like Ping, the command. |
| bytes     | All   | The byte length of the arg. |
| cmd       | All   | "Query" or "Admin" for all except memcached.  For memcached it's the memcached command (get, set, etc.). |
| exptime   | memcached | Expiration time. |
| flags     | memcached |             |
| key       | memached | The key used by cmd. |
| key\_print | memcached | An abstracted form of the key. |
| pos\_in\_log | All except Processlist | The byte offset of the event in the log or tcpdump. |
| fingerprint | All   | An abstracted form of the query. |
| res       | memcached | Result of cmd. |
| ts        | All   | The timestamp of the query. ts is from the Time normal attribute in slow logs, and it's the time when the query ended. See also the SET timestamp attribute. |
| val       | memcached | The return value of cmd, if any. |

### Normal attributes ###

| Attribute | Input | Description |
|:----------|:------|:------------|
| db        | All except memcached | Current database.  Comes from USE database statements in logs. See also Percona-patch Schema attribute. |
| Error\_no | tcpdump | The error number if any. |
| host      | All   | Client host which executed the query. |
| id        | Processlist | Process ID. |
| ip        | Log, tcpdump | Client IP.  |
| Lock\_time | Log   | Time the query was locked before it was able to start executing. |
| Memc\_add | memcached | Yes/No if the command is add. |
| Memc\_append | memcached | Yes/No if the command is append. |
| Memc\_cas | memcached | Yes/No if the command is cas. |
| Memc\_error | memcached | Yes/No if command caused an error.  Currently, the only error is when a retrieval command is interrupted. |
| Memc\_get | memcached | Yes/No if the command is get. |
| Memc\_gets | memcached | Yes/No if the command is gets. |
| Memc\_miss | memcached | Yes/No if the command tried to access a nonexistent key. |
| Memc\_prepend | memcached | Yes/No if the command is prepend. |
| Memc\_replace | memcached | Yes/No if the command is replace. |
| Memc\_set | memcached | Yes/No if the command is set. |
| No\_good\_index\_used, No\_index\_used | tcpdump | Yes/No properties set by status flags sent by server. |
| port      | tcpdump | Client port. |
| Rows\_sent, Rows\_examined, Rows\_affected, Rows\_read | Log   | Self-explanatory. |
| user      | Log   | User who executed the query. |
| Query\_time | All   | The total time the query took, **including** lock time. |
| Warning\_count | tcpdump | The number of warnings. |

### Common SET attributes ###

| Attribute | Input | Description |
|:----------|:------|:------------|
| insert\_id | Log   | Self-explanatory. |
| timestamp | Log   |  The time at the start of the query.  In a replication slave, this could be something unrelated to the time of execution.  See also ts internal attribute. |

### Percona-patch attributes ###

The most up-to-date documentation on the Percona patches should be found at http://www.percona.com/docs/wiki/patches:microslow_innodb, but we list them below in an abbreviated form.

| Attribute | Input | Description |
|:----------|:------|:------------|
| Disk\_filesort | Log   | Yes/No if the query's filesort was done on disk. |
| Disk\_tmp\_table | Log   | Yes/No if query used a temporary table on disk. |
| Filesort  | Log   | Yes/No if query used a filesort. |
| Full\_scan | Log   | Yes/No if query caused a full table scan. |
| Full\_join | Log   | Yes/No if query caused a full join. |
| InnoDB\_IO\_r\_ops | Log   |             |
| InnoDB\_IO\_r\_bytes | Log   |             |
| InnoDB\_IO\_r\_wait | Log   |             |
| InnoDB\_rec\_lock\_wait | Log   |             |
| InnoDB\_queue\_wait | Log   |             |
| InnoDB\_pages\_distinct | Log   |             |
| Merge\_passes | Log   | Number of merge passes to sort query. |
| QC\_Hit   | Log   | Yes/No if query was served from query cache. |
| Schema    | Log   | The current database. See also the db normal attribute. |
| Thread\_id | Log   | Self-explanatory. |
| Tmp\_table | Log   | Yes/No if query used a temporary table in RAM. |