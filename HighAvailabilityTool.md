See [issue 850](https://code.google.com/p/maatkit/issues/detail?id=850).

# Introduction #

This document contains requirements and specification for a new tool to manage clusters of MySQL replication servers.  This tool's goal is to achieve high availability and load balancing, with as much consistency as possible.  [In Josh Berkus's terms, the tool is for online users](http://it.toolbox.com/blogs/database-soup/the-three-database-clustering-users-35473).  The tool will be able to perform automated failovers during a cluster or node failure, and to make it easy and safe to correctly perform manual switchovers.  The tool is designed to improve upon MMM and Flipper, overcome their limitations, and meet the needs of Percona's clients.

This tool has nothing to do with NDB cluster ("MySQL Cluster").  It is designed to take advantage of stock MySQL installations using normal MySQL replication.

# Synopsis #

Assume that you have a master-master pair of servers on 192.168.1.{10,11}, and .10 is the writable server right now.  You want to set up a new cluster.  All you should have to do is run the following two commands to create a high-availability cluster of Master Master replication between the two nodes.  The first IP address tells the monitor how to connect to the first server.  The 10 range IP addresses are the writer IP and the two reader IP addresses.

```
mk-cluster h=192.168.1.10,D=maatkit --initialize 10.10.10.1 10.10.10.2 10.10.10.3
mk-cluster h=192.168.1.10,D=maatkit
```

This cluster has a weakness.  Only one monitor is watching it for failures and other problems.  On any other machine, you run the following command to create a standby monitor in case the first one fails.

```
mk-cluster h=192.168.1.10,D=maatkit
```

This is how simple it should be to set up a high-availability cluster.  This is the goal of the tool described in this document.  Notice that there is absolutely no configuration file in this example.

# Basic Requirements #

This tool will support various replication topologies and provide reader, writer, and offline roles by default; users may define their own roles.  Major goals include:

  * Provide a highly available database cluster, first and foremost
  * Strive for as much consistency as possible, within the constraints of stock MySQL technology (asynchronous replication that has bugs and may fail)
  * Support takeover by another monitor, so the monitor is not a single point of failure
  * Be trustworthy; provide as strong as possible guarantees of correctness
  * Accommodate more advanced functionality in the future
  * Be as simple as possible so the tool can be well designed and well understood
  * Perform certain actions through plug-ins so the tool can be extended
  * Store the state and configuration in the database

The tool's functionality can be broken down into:

  1. Accept instructions on the desired state of a set of machines (cluster of nodes).
  1. Observe the cluster.
  1. Compare the observed state to the desired state and find differences.
  1. Decide what needs to be done to reconcile differences.
  1. Take actions to reconcile.
  1. Verify that the actions succeeded and the end state matches the desired state.

These are distinct functions that must be specified and tested in isolation to meet the goal of strong correctness guarantees.  (#2 and #6 are quite similar).

# Terminology #

The following is a basic glossary of the terms used in this document.

  * A **node** is an independent machine (physical or virtual) which is part of the cluster.
  * A **cluster** is a collection of nodes that are related by MySQL replication.
  * A **monitor** is an instance of the tool that is connected to and watching the cluster.
  * A **controller** is the single monitor that is in control of the cluster.
  * An **instance** is a MySQL daemon on a node.
  * An **address** identifies how to connect to a node or instance.  It is either an IP address or a DNS name.  Right now only IP addresses will be specified; DNS names are future functionality.
    * A **virtual IP address** is an IP address that can be moved from node to node in the cluster.
    * A **static IP address** is an IP address that remains fixed to one of the nodes in the cluster.
  * A **role** describes the functions a node is performing.


# Consistency, Availability, and Partitioning #

It is important to understand that this tool is designed for high availability, not complete consistency.  Users who cannot afford to lose any data should look at a tool that guarantees data will not be lost, such as DRBD with Heartbeat.  This tool will be built upon asynchronous replication, which does not offer strong consistency guarantees.

We believe there is a great need for a highly available, reasonably consistent cluster built upon asynchronous replication.  For the majority of users, replication is not noly "good enough," it is actually the right solution (i.e. it is better than DRBD).  Even though replication can lag, and you can see inconsistency from reading a slave that is delayed, there are many use cases for this that are more than good enough for real-world needs.  What is needed is simply a decent way to manage such clusters.

There is a lot of literature and research around distributed clusters, especially synchronous clusters.  In recent years, much of this has focused on three properties of such clusters: consistency, availability, and network partitioning ([see this research paper on Brewer's conjecture and the CAP principle for more](http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.20.1495)).  The traditional approach values correctness and consistency, at the expense of scalability and/or availability.  This is not the solution that we seek to support.

The type of cluster that this tool will support could be considered a BASE cluster, as opposed to an ACID cluster.  These concepts are best explained in [an ACM queue article](http://queue.acm.org/detail.cfm?id=1394128).

In short, you can choose from consistency, high-availability, and partition resistance, but you can only choose two of those properties.  This tool supports high-availability and partition resistance, with as much consistency as possible.

An example of the type of trade-off that this tool makes is fencing, or STONITH (shoot the other node in the head) functionality.  A system such as heartbeat with DRBD would typically take whatever steps are necessary to protect the consistency of the data.  This includes forcibly killing a node that cannot be controlled normally.  For many of our users, this is absolutely unacceptable.  Instead, we will choose to isolate the misbehaving node and allow an administrator to bring it online again later.  This gives an administrator a chance to correct the situation, which may be simple to resolve with human intervention.

For example, suppose there is a misbehaving replication master.  The server is unreachable through the network.  The remaining servers will disconnect from the server, instead of killing it.  Killing such a server could have an extremely high cost.  A server with a large buffer pool could take several days to recover, warm up, and become fully functional again.

# Why a New Tool? #

Why not fix [MMM](http://code.google.com/p/mysql-master-master/)?  MMM's design seems to be limited in ways that cannot be overcome.  It uses agents, and has a single point of failure that cannot be solved. MMM code is demonstrably buggy in critical parts, difficult to understand, and complicated by administrative functions, the use of agents, and reams of "glue" code. MMM also includes many features that this tool will not include, such as tools to help automate backups, synchronize servers with each other, and perform other tasks.  These are unnecessary for our purposes, and they should be built as separate tools.  This tool will focus on doing one thing well.

Why not extend [Flipper](http://code.google.com/p/flipper/)?  Flipper's code is nice and its design is good, but it does not have enough features.  And instead of extending Flipper, we think it makes sense to take advantage of all the code that is already written for other Maatkit tools.  Unlike Flipper's code, Maatkit's code has a real test suite, which is required for this type of tool.

Why not use heartbeat or pacemaker?  These are well understood, well tested tools that are trusted by many people and widely deployed.  The problem is, they are also quite complicated.  Neither Heartbeat nor Pacemaker is capable of building the type of functionality that Percona's clients require.  And a purpose-built solution is better than a highly complex generic system.  For example, Drupal can be used to build a blog, but Wordpress is a much better blog.  In the same way I believe we can build a much better cluster management system that is easier to use and administer than one built on top of pacemaker.  Finally, the Heartbeat/Pacemaker model is wrong for replication high availability as envisioned here.  The decisions should not be made by disconnected agents communicating amongst themselves and reaching some kind of majority opinion; the database should be the sole source of truth.  A transactional database is different from the kinds of systems such as DRBD that Pacemaker is built to work with.

# Why Store State and Configuration in the Database? #

Storing the state in the database is actually one of the more important characteristics of the system.  Storing the state in the database means that there is no chance for mismatch between the cluster itself and some extra system.  Three properties must be true about the system for it to work well:

  1. updates to the system state must be transactional, and the scope of those transactions must be carefully defined.
  1. updates to the system must be designed so that a system takeover is not overwritten by another event, for example by interleaved updates on a master and slave.
  1. monitors that have the same information about the cluster must make the same decisions about what to do with it; there must not be any randomness in the policy engine; and the decision about which node to promote must be consistent across monitors even if they have different information about the cluster.

When properly implemented, these properties mean that the stored state is exactly as authoritative as the true state of the cluster, and a failure in either is made unimportant by the success of the other.  There is no weak link inside or outside of the cluster; both the cluster itself, with all of replication's problems, and the stored state can be wrong in the same ways and under the same set of circumstances.  The cluster is self-documenting, as it should be.  If there is a failure to record the state, then there must have been a failure in the cluster, so the failure to record the state doesn't matter.  If there is a failure to change the cluster to match the stored state, then the tool will try again, so the failure to change the cluster doesn't matter.

If the cluster isn't available, the configuration doesn't matter.  If the configuration isn't available, then the cluster must not be, either, so that also doesn't matter.

You can look at it as a proof by contradiction, too.  Imagine we store configuration/state separately from the cluster.  There are now two things (cluster + state) we must make highly available and keep in sync in a distributed fashion.  For the cluster to be any good, we need both of them to be online.  Now pretend that one of the two is unavailable -- what good is the other? And conversely, if one of the two is down, what do you lose if the remaining one goes down?  The cluster and its state/configuration succeed or fail as a group, not separately.

In addition, if you've ever deployed a system across a number of nodes and had to fiddle with keeping the configuration files in sync across the nodes, you'll appreciate the single source of truth that this design creates.  I have seen several problems caused by MMM configurations that were not the same (in subtle ways) on all the nodes.

The danger of storing state in the database is that, unless we design things carefully, the tool itself could cause a problem for the cluster.  To avoid this, we need to avoid auto\_increment primary keys or statements that could cause duplicate key errors in situations like a takeover.  We'll need to vet all the SQL statements to see if there is a possibility of any of them breaking replication from writing on a slave.

# Requirements #

The following is a laundry list of requirements, in no particular order.

  * The tool should have no single point of failure.  It should be possible to run multiple monitors as peers.  One of these, the controller, will control the cluster.  It will be possible for one of the monitors to take over control of the cluster from the other, and for a human to manually specify that the controller should yield.  If the controller seems to stop functioning, the remaining monitors should be able to atomically elect one of themselves to be the controller.  In case the former controller really did not stop functioning, it must be able to determine that it has been replaced by another controller.
  * All control and configuration of the cluster should be centralized around the database, so the monitor (and thus the cluster) can be controlled and monitored by SQL queries and updates.
    * Configuration must be robust; it should not be possible to break the cluster with a configuration mistake.  Every configuration variable should have a command-line variable with a default.  If the configuration in the database is changed to something invalid or deleted, the default must be used instead.  Configuration keys stored in the database that are not known to the tool should cause a warning, but not an error.  This is in contrast to the command-line behavior, which will reject invalid options and arguments.
    * All functions of the monitor should be performed online during normal operation.  These include administrative takeovers, reconfiguration of the cluster, adding or subtracting nodes to the cluster, and taking a node off-line or bringing it back online.  There should be no need to restart the controller for any of this.
    * Administrative functions should not cause any downtime or inconsistency in the cluster.  During emergencies when the monitor controls the cluster automatically, it is acceptable to permit some inconsistency for the purpose of high-availability.  However, taking a node off-line for administrative work, or similar functionality, must never introduce any inconsistency into the cluster.
  * The tool must support different modes of operation: automatic, manual, and passive.
  * The monitor must confirm the results of every action it takes.  There must be no silent failures.
  * The tool must understand master-master, master-slave(s), and master-master-slave(s) topologies to any depth (i.e. not just master with single slaves, but slaves that have more slaves too).
  * The tool should have a plugin interface so custom code can be hooked before and after important action points in the code.
  * High availability will be implemented by moving virtual IP addresses between nodes in the cluster.  This will be pluggable, so in the future it will be possible to alter DNS records instead, or make calls to custom systems or commercial load balancers.  This will be useful for cloud computing scenarios such as Amazon EC2 and for integrating with customers' existing investments.
    * The tool will also have the capability to move replication servers around in the hierarchy.  When moving a slave to a new master, wait until it is caught up as much as possible before moving it.  Wait until slaves are caught up before moving IP addresses.  The wait timeout should be configurable, and when the timeout expires, existing connections should be killed.
  * The tool will have basic load-balancing capabilities.  In the beginning, the only metric of load will be replication delay.  However, in the future the tool will also be able to check other load metrics.  Load balancing will be implemented by moving virtual IP addresses to less loaded machines.
  * Do not break a functioning cluster.  When in doubt, do nothing.  Never move roles from the writer unless it is completely dead.  Never move roles unless at least one node is reachable (when promoting a slave to a master is an option -- when only master-master failover of the writer is permitted, don't move roles unless at least one master is reachable).  When the tool starts or stops, it should not make any changes to the cluster unless the stored state is out of sync with reality.  If this happens, it should be configurable to sync the cluster or sync the stored state.
  * The tool will not use an agent-based architecture.  This brings the number of benefits, such as security, lack of interprocess communication, making the tool easier to understand, and making the design simpler and more robust.  It also makes it much easier to design a redundant system with no single points of failure.
    * Agents actually do not bring any benefits to the design.  In fact, agents are one of the main weaknesses of MMM.  An agent is just a middleman, and is only a benefit when a) the agent can make autonomous decisions; but that does not apply in this case because an agent that makes autonomous decisions is going to introduce split brain syndrome into the cluster, or b) the agent provides some service between requests from the central system; but there is no need for that in this design.
  * No support for multiple clusters.  Each instance of this tool will manage one replication cluster, and an administrator who desires more than one cluster must run more than one instance of the tool.
    * Every bit of state should be checked on every cycle -- check @@read\_only, check @@server\_id, check node's replication parent, etc etc.
  * Minimal reliance on fallible features within MySQL, such as SHOW SLAVE STATUS, to detect replication lag and other failures.
  * Build for the lowest common denominator: stock MySQL 4.1 or better (replication is different before 4.1).  However, do not preclude support for global transaction ID and other community enhancements.  These might be future features.
  * Use SSH for all operating system commands, for security.  Use sudo by default, so that the tool doesn't need to run as root.
  * Keep a MySQL connection permanently open to all nodes, so that we don't fall prey to too-many-connections, etc.  Don't kill these connections upon failover.
  * No support initially for alerting or notifications.  The only communication with the outside world is through the stored state saved in the database, and the log.  This might change in the future.
  * Unresolved issue: is it possible to control which IP address an application connects to?  If an application connects to mysql on the non-floating IP address, this can be a problem.  mysqld must bind to all traffic on an interface, as far as I know -- it cannot just bind to the floating IP address, and in case of multiple roles, it can't bind to any specific IP address at all.  Maybe this can be an extra step (if desired for extra safety) as iptables rules.
  * Although technically this is master-master replication, in reality the tool always runs STOP SLAVE on the active master by default, to prevent corruption from someone running updates on the passive master.  So in reality replication is always one-way, not both-way.  This is configurable.  The benefit is that corruption is avoided; the drawback is that upon failover, the new active master might need to run some statements before it's ready for writable IP addresses.
    * Since the active master's replication is stopped by default, we should also save its replication state in a database table (TODO) to avoid reliance on the master.info file; we don't try to keep this up to date when replication is running.  But we want to make sure we don't forget where it should be started in replication.  Checking that the slave is stopped and the binlog position matches what's in the database should be a regular sanity check on each execution cycle.
  * The tool needs a quick way to support a "freeze" or another way to make a node's roles static.  For example, the following task: freeze roles; determine which is the passive server; take a backup off the passive server; unfreeze the roles.  It might be useful to freeze only that one node's roles, and it might be useful to have a timeout in case the backup script doesn't reset it.  So "freeze roles on node N for X seconds." (And a configuration item that specifies a max-freeze-timeout the tool will honor, too.)
  * The tool needs a verbose, auditable history of what it observed, what it decided, and what actions it took.  "Changed status of X to Y" is not helpful -- why did that happen?  It would be much better to see "... because Z."  I'd like to be able to query this information, and if any monitor can't write its log to the database, it should buffer and then insert later.
  * Each monitoring process should store its version and other interesting information into the database when it connects.
  * If the DBA issues STOP SLAVE, that will cause the machine to be removed from the cluster.  Configurable.

# Assumptions #

  * Assume all nodes in a cluster are fully identical.  This means, among other things, that all nodes use the same username and password.
  * Only one node is writable at a time.
  * The tool has its own username, so it can identify which connections belong to it.
  * Network interfaces do not need to be up'ed and down'ed. (Debatable.  Maybe it should ifup as required.)

# Adjusting Replication Topology #

  * Don't auto-move slaves to a new master unless a) the old master isn't the writer and its replication is failed b) the old master isn't the writer and it is dead, e.g. replication on the slave is failed.  The point of this is that the active master role can change from A to B and the slaves don't have to move with it!  There is nothing wrong with A having slaves when B is the active (writable) master

# Fencing and STONITH #

Fencing is isolating a resource from the other resources to protect them.  It is very important to protect data integrity.

Here is a typical scenario in master-master replication without fencing, which illustrates what can happen: the active master fails, and the writable role is moved to its co-master.  However, some application connections are still open to the first server, and writes continue to happen there.  These propagate through replication and cause duplicate key errors on the newly promoted second master, and its replication fails.  Or, the first master crashes; the writable role is moved to the second master; the first master comes back online, and finishes sending its binary log events to the second master, causing the same trouble.

In clusters that insist on protecting data to above all, such as Red Hat's clustered file system or DRBD, fencing is very strict.  If a resource cannot be isolated (e.g. it is not responding or not reachable, which can happen for a number of reasons), the typical tactic is called STONITH, or "shoot the other node in the head."  This is usually done with a network power switch to forcibly power off the fenced-off node.

In MySQL replication, fencing needs to be able to break two types of connections between machines:

  1. Replication.  This is easy, because the slave is in control.  You can simply connect to the slave and run STOP SLAVE, and the slave is now isolated from any changes on the master.
  1. Network connections.  This is harder, because an IP address may stay attached to a machine for a variety of reasons.  This requires STONITH to get absolute certainty.

In a BASE cluster such as the type mk-cluster supports, fencing is good, but STONITH is not necessarily a good thing.  Here's why.  The replication connection is the one that can corrupt data the worst, and it's easy to fence off.  But the consequences of an IP address refusing to move to a new node are much less dramatic.  In the worst case, writes will occur to a node that is suddenly not part of the cluster anymore.  This is not nice, but it won't mess up the rest of the cluster in the general case.  It just means an administrator has to decide whether that data is worth saving, and if so, what to do about it.

Moreover, killing a node can have a very high cost, as mentioned early on in this document.

mk-cluster will support fencing as far as possible without actually STONITH-ing a node (and even that will be an option if someone wants it).  It will also try all available means to determine whether a node is truly unreachable; it will try to connect to all addresses associated with a node before declaring it unreachable.

If a failed node comes back online, the resume\_policy configuration variable specifies the resulting behavior.

# Load Balancing #

In the beginning, load balancing will be very simple: nodes with roles of type `balanced` will have addresses distributed amongst them such that no node has more than one more address than any other.

# Database Structures #

Table names are hardcoded into the tool and are not configurable.  The only configurable variable is the database name in which the tables are stored.  Tables must use a transactional engine.

The naming convention is that the primary key of each table, if it has a single-column primary key, is named id.  Foreign keys are named after the table they link to; thus, the following type of query makes sense:

```
select * from child join parent on child.parent = parent.id;
```

The @@server\_id and similar @@ variables in sample queries is a placeholder. The value needs to be selected from the server and then inserted as a literal, to avoid different behaviors across MySQL versions.  The @@ variables are not replication-safe in some versions of MySQL.

## The Config Table ##

This table is a simple name-value structure that defines configuration options for the tool.  The table structure is as follows:

```
create table config (
  name varchar(64) not null primary key,
  value text not null
);
```

The possible names and their values are:

  * failure\_count
    * After this many cycles of failure, the service or node is considered dead and failover begins.
  * fence\_timeout (default 60)
    * When moving a writable IP address to a slave, wait up to this amount of time for the slave to catch up in replication.  After this time, fence off the old writable and move the IP address anyway.  This does not apply in an administrative failover, which should always be clean.
  * interval (default 1)
    * The frequency with which the tool runs its "main loop" to check the cluster.
  * mode (default automatic)
    * In **automatic** mode, the tool adjusts the cluster's IP addresses and replication topology as it deems best.  It makes changes to the state stored in the database, and adjusts the cluster to match.
    * In **manual** mode, the tool changes the cluster, but not the state in the database.  This lets an administrator control the system fully by changing data in the database.
    * In **passive** mode, the tool doesn't make any changes at all.  It keeps pulsing the heartbeat, but doesn't take any other actions.
  * move\_timeout (default 60)
    * When moving a server to a new master, wait this amount of time for it to catch up to its master before moving it anyway.  Moving a slave that is delayed shouldn't cause inconsistency in a healthy cluster, but may in a broken one.  This timeout does not apply in an administrator move; the timeout is infinite then.
  * prevent\_new\_slaves (default true)
    * This setting prevents unwanted, unknown slaves from being added to the cluster.  If a node has an unknown slave, it will be fenced off by marking it misconfigured, connecting to it, issuing STOP SLAVE, and killing its connection from the master.  New slaves should be added with CHANGE MASTER TO, but START SLAVE should not be executed; the controller will take care of that.
  * resume\_policy (default none)
    * If a failed master comes back online, replication slaves may be configured to restart replication from it again in the following ways:
      * none: Do not restart replication (default; safest).
      * restart: Restart where they left off (very dangerous).
      * skip: Restart from the master's current binary log position, effectively skipping transactions that might conflict with their current state.  This is also dangerous, because it means the master and the slave do not have the same data anymore.
  * slaves\_follow\_writable (default false)
    * If this is true, slaves will follow the writable role when it moves.
  * splitbrain\_prevention (default true)
    * This setting prevents two controllers from believing they are in control of the cluster at the same time.  It forbids takeover if a node is unreachable, unless the writable node is the only unreachable one.  This, combined with the strict and predictable ordering of which monitor will attempt takeover and which node is to be promoted to the writable role, means that all monitors will make the same decision about takeover and promotion.  Without this protection, the following scenario leading to splitbrain syndrome is possible:  Assume a cluster with a master and 2 slaves, and 3 monitors watching; monitors 2 and 3 decide monitor 1 is not doing its job, but the writable master is not available; monitor 2 tries to takeover and promote slave 1 as writable, but monitor 3 tries to takeover and promote slave 2 as writable.
  * storage\_engine (default InnoDB)
    * This variable controls the storage engine for all the configuration tables.  It must be transactional.  We can run `SHOW ENGINES` and verify that the Comment column contains the word "transaction" as a simple test.
  * sync\_database\_on\_start (default true)
    * Controls what the tool does when it starts and the database and the observed state of the cluster don't agree. If this is set, it should update the database to match observed state.
  * takeover\_timeout (default 60)
    * If a monitor notices that the controller hasn't updated the heartbeat in this amount of time, it will attempt to take over the cluster if it is next in line as controller.  If it cannot gain control of the cluster in the same amount of time, it stops trying.  If it is not next in line as controller, it waits 3 times the timeout for each monitor ahead of it in line.  This ensures that no two monitors are trying to take over at the same time.
  * user
    * The username for the monitors.  This is necessary to ensure that all monitors are connecting to the cluster as the same user.

## The Monitor Table ##

This table records the presence of monitors, and their order of precedence in takeover attempts. The structure:

```
create table monitor (
  id varchar(32) not null primary key,
  promotion_order int unsigned not null,  -- order in which monitors will attempt takeover
  unique index(promotion_order)
);
```

When a monitor starts up and joins the cluster, it inserts into the table as follows:

```
insert into monitor (id, promotion_order)
   select <monitor ID>, coalesce(max(promotion_order), 0) + 1
   from monitor inner join heartbeat on heartbeat.id = 1
   where heartbeat.node = <@@server_id>;
```

TODO: I think this table needs a ts column for a heartbeat, and each monitor needs to pulse it to indicate it is still alive.  The controller should delete rows that haven't had a heartbeat in some configurable delay time.  Otherwise users can't clean out the table, and the monitors might wait a long time during takeovers.

## The Heartbeat Table ##

The heartbeat table is similar in concept to that used by mk-heartbeat.  It is safe to read from this table with mk-heartbeat, but not safe to write to it.  Only mk-cluster should write to it.  This is because the updates must be done very carefully.  The heartbeat table has a special purpose in the cluster. It contains a single row, so it is a global mutex. It indicates the ID of the monitor instance that is controlling the cluster, and which node is considered to be writable (there is only one writable node in the cluster). It is used for both automated and manual takeovers of the cluster.

```
create table heartbeat (
  id int unsigned not null primary key,
  node int unsigned not null,            -- the @@server_id where it was inserted
  monitor varchar(32) not null,          -- the mk-cluster monitor that inserted it
  thread  int unsigned not null,         -- the connection_id() of the monitor
  ts datetime not null
);
```

There is only one row in the table, with the magical id constant of 1.

All monitors try to write to the heartbeat, whether they are actually the controller or not.  Writes to the heartbeat table are specially done so only the controller will actually change the data.  Here is the query:

```
replace into heartbeat(id, node, monitor, thread, ts)
select 1, <@@server_id>, <mk-cluster ID>, connection_id(), now()
from heartbeat
where id = 1
   and monitor = <mk-cluster ID>
   and node = <@@server_id>;
```

This query won't change anything unless two conditions hold:

  1. The query is run on the writable node, as defined by the heartbeat table.
  1. The query is run by the controller, as defined by the heartbeat table.

The heartbeat table can be read from any node to determine its replication delay, to a tolerance of one second.  And it can be read on the writable or origin node to determine which mk-cluster monitor is the controller.

It also communicates to every monitor whether the cluster's controller has failed.  If the heartbeat is not updated recently on the writable node, the output of SHOW PROCESSLIST will reveal whether the controller is still connected to the writable node.  More on this later.

The monitor ID is a new concept in mk-cluster. This is something we need to develop for the tool. It needs to be a globally unique identifier, which should probably be some combination of timestamp, IP address, and some random information. We need to investigate existing methods for creating a globally unique identifier.

All queries that modify data must select or join from the heartbeat table with the current node and monitor ID in the WHERE clause, to ensure that only the cluster controller updates data and only on the writable node.  There is only one exception, and that is a cluster takeover.  More on this later.

By default, when you initialize a cluster, mk-cluster inserts the following row:

```
insert into heartbeat (id, monitor, node, thread, ts)
values (1, <monitor ID>, <@@server_id>, connection_id(), now());
```

The following query will take control of the cluster and reset the writable node, in case the controller has been inactive for more than 30 seconds.

```
update heartbeat set
  monitor = <my ID>,
  node    = <@@server_id>,
  thread  = connection_id(),
  ts      = now()
where ts < now() - interval 30 second
  and id = 1;
```

## The Node Table ##

The node table contains one row for each node in the cluster.  The table structure is as follows:

```
create table node (
  id int unsigned not null primary key, -- the @@server_id
  ip_address int unsigned not null,     -- the permanent IP address of the node
  master int unsigned null,             -- the replication master
  state enum(
    'online',
    'offline',
    'misconfigured',
    'fenced',
    'unreachable')
);
```

### Node States ###

The node states have the following meanings:

  * **online** is normal, all is well.
  * **offline** is an administrative state that prevents any roles from being assigned to the node.
  * **misconfigured** means the node was rejected from the cluster because it did not pass the sanity checks.
  * **fenced** means the node was intentionally isolated from the cluster to protect the consistency of the rest of the cluster.
  * **unreachable** means the node can't be reached by any means.

If you're missing REPLICATION\_DELAY or REPLICATION\_FAILED as in MMM, these are specified per-role as an allowable replication delay.  We also really don't care if replication is actually running.  If the sysadmin stops replication for a bit and the delay doesn't exceed the configured limit, nothing is actually wrong.  We care whether the data is up to date enough to use.

## The Role Table ##

mk-cluster requires there to be a writer role that has only one address. By default it creates writer and reader roles.  The reader roles are optional. All other roles are up to the user.  The relationship between nodes and roles is stored in the node\_role table.

There are several types of roles:

  1. A **writer** role has exactly one address.  The role of the same name is an example of this.
  1. A **balanced** role may have one to many addresses.  These are load balanced as defined in Load Balancing.

The structure of the table is as follows:

```
create table role (
  id varchar(64) not null primary key,
  type enum('writer', 'balanced') not null default 'balanced',
  delay_threshold int,
  allowed_demotions int,
  comment varchar(255),
);
```

The delay\_threshold column contains the maximum permissible replication delay for balanced roles.  If a node's replication delay exceeds this value, the role's addresses will be moved away from the node.

The allowed\_demotions column is explained in the Node\_Role table.  If it is NULL, then an infinite number of demotions are permitted.

By default, when you initialize a cluster, mk-cluster will add the following entries:

```
insert into role(id, type, delay_threshold, comment) values
  ('writer', 'writer',    null, 'Automatically added writer role'),
  ('reader', 'balanced',  60,   'Automatically added reader role'),
```

## The Node\_Role Table ##

This table contains relationships between nodes and roles.  The presence of a row in this table indicates that a node is eligible for a specified role.

The structure of the table is as follows:

```
create table node_role (
  node int unsigned not null,
  role varchar(64) not null,
  assigned int not null default 0,      -- whether the node should have the role
  promotion_order int null,             -- order of preference for failover
  demotion_count int unsigned not null, -- number of times has been failed away from
  primary key(node, role),
  unique index(role, promotion_order)
);
```

The note and role columns should be self-explanatory.  The assigned column contains a zero if the role has been assigned to the note.  Remember, the presence of the row indicates that the node is eligible for the role, but the node may not actually have that role.  If the node is supposed to have the role, the assigned column will be one.  It is up to the controller to make sure that this actually happens.

The demotion\_count column counts how many times the controller has automatically failed away from a node (taken the role away from it).  If this count exceeds the allowed\_demotions configurable value for the role, then the node is not eligible for the role anymore.

The promotion\_order column is a unique order in which the controller will attempt to assign roles to nodes.  The order is stored in the database when a node is added, and not modified afterwards.  This is very important for takeovers, when monitors must agree on the new writable node.  Two monitors must not be trying to do a takeover and promotion to writable role on two different nodes unless there is a severe problem.  Aside from being useful in takeovers, this also lets the database administrator specify a preference for which nodes should be assigned which roles.  For example, perhaps you want to create a data warehouse role, and you prefer the associated address to be assigned to a particular node if it is available, not treating all nodes within the role equally.

When mk-cluster initializes a master-slave cluster with one writer and two reader IP addresses, it inserts the following example rows into the table:

```
insert into node_role(node, role, assigned, promotion_order)
values
  (1, "writer", 1, 0),
  (1, "reader", 1, null),
  (2, "reader", 1, null);
```

## The Address Table ##

This table contains only addresses that are movable -- the fixed addresses are stored in the node table.

Every address belongs to a role.  If the role is balanced, the addresses are balanced across nodes, within the role, as defined by Load Balancing.

The table structure is as follows:

```
create table address (
  id varchar(64) not null primary key,
  role varchar(64) not null,
  node int unsigned null -- The node to which the address is assigned
);
```

## The Health\_Check Table ##

This table contains information about each type of check the system will perform.  This allows each check to be configurable.

The structure is as follows:

```
create table health_check (
   id varchar(64) not null primary key,
   comment varchar(64)
);
```

## The Health\_Check\_Config Table ##

This table contains configuration parameters for each check:

```
create table health_check_config (
   health_check varchar(64) not null,
   name varchar(64) not null,
   value text,
   primary key(health_check, name)
);
```

For example, the default configuration for the mysqld health check will be `SELECT NOW()`.

## The Role\_Health\_Check Table ##

This table specifies which checks are to be performed for each role that belongs to a node:

```
create table role_health_check (
   role varchar(64) not null,
   health_check varchar(64) not null,
   primary key(role,health_check)
);
```

TODO: does it make sense to specify timeouts and fail-counts per-role?

## The Cluster\_Log Table ##

The cluster log table stores a log of all actions taken by the controller.  This is a brief, terse log that only records changes the controller makes and the reasons for making them.

The structure of this table is as follows:

```
create table cluster_log (
  -- exact columns TBD
);
```

The table probably shouldn't have a primary key.  The log statements are inserted in the usual way to make sure they only get inserted into the writable server.

```
insert into cluster_log(....)
select ( .... ) from heartbeat where ...;
```

# Research Done On MMM #

The following sections are about the MMM code I've read to try to understand it and make sure nothing important is missed.

## State Changes ##

MMM's state changes look too complex to me.  They are in daemon.pm and are as follows, simplified.  One of the problems is that these are all if statements, not if/else, so a state might change to one thing and then another as they are traversed.

| current state     | check results | next state |
|:------------------|:--------------|:-----------|
| ADMIN\_OFFLINE     | -- any --     | ADMIN\_OFFLINE |
| PENDING           | OK            | agent says UNKNOWN ? HARD\_OFFLINE : trust agent |
| AWAITING\_RECOVERY | not OK        | HARD\_OFFLINE |
| HARD\_OFFLINE      | OK            | AWAITING\_RECOVERY |
| AWAITING\_RECOVERY | OK            | Might go ONLINE, depending on uptime and wait\_for\_other\_master |
| REPLICATION\_ERROR  | not OK        | HARD\_OFFLINE if 'auto'; STONITH if can't send new status to it |
| REPLICATION\_FAIL   | OK but delayed | REPLICATION\_DELAY |
| REPLICATION\_DELAY  | not OK threads | REPLICATION\_FAIL  |
| ONLINE             | not OK         | HARD\_OFFLINE and move roles if 'auto'; STONITH if can't move roles |
| ONLINE             | not OK threads | REPLICATION\_FAIL and move roles if 'auto'; but not if it's the active master; children notified |
| ONLINE             | not OK delay   | REPLICATION\_DELAY, move roles if 'auto'; but not if it's the active master; children notified |
| REPLICATION\_DELAY/FAIL | OK, but delay (and running) OR peer is not ONLINE | ONLINE     |

In addition to the above, when the failover method is "wait" and both hosts online, it gets switched to "auto".  If both hosts aren't online, the behavior depends on wait\_for\_other\_master which is unclear to me now.

## When MMM changes a slave's state ##

We need to move a slave to a different parent when its parent is truly dead.

MMM's behavior is not known yet; when a parent fails or replication delays, the daemon notifies the agent; what does it do?  TODO.

# Use Cases #

## Initialize a cluster ##

  * Primary Actor: system administrator
  * Preconditions: the tool is installed and two or more servers are already running and accessible
  * Success Guarantee: new table structures have been created in the database cluster, and they contain all necessary data to describe the cluster and its operation.
  * Main Success Scenario:
    * The user invokes the tool with the --initialize option.
    * The tool connects to the database.
    * The tool treats the first IP address on the command line as the writer IP address.
    * The tool treats any other IP addresses on the command line as reader IP addresses.
    * The tool creates the system tables in the server to which it connected.
    * The tool detects all connected slaves by examining the process list.
    * The tool adds the detected slaves as new nodes.

## Monitor the cluster ##

  * Primary Actor: the monitor.
  * Preconditions: the cluster is configured.
  * Success Guarantee: the state of the cluster matches the desired state of the cluster.

Main Success Scenario:

  * The monitor wakes up after being asleep.
  * The monitor queries the writable node in the database and retrieves the cluster configuration.
  * The monitor inspects every other node in the cluster and compares its state to the desired state in the cluster.
    * The monitor performs all checks for each node assigned to the role.
  * The monitor inserts a heartbeat record into the heartbeat table and goes to sleep.

Extensions:

  * The monitor is not the controller
    * The monitor does not inspect every other node in the cluster.
    * The monitor inspects the database to ensure that the controller is active and functioning.  If not, the monitor attempts a takeover.

## Add a node to a cluster ##

  * Primary Actor: system administrator.
  * Preconditions: the cluster is already up and running, and there is an active cluster controller.
  * Success Guarantee: the new node will be monitored as a normal part of the cluster.

Main Success Scenario:

  * The user inserts a new row into the nodes table.
  * The tool begins a check cycle.
  * The tool notices the new row in the database table.
  * The tool runs sanity checks on the new node.
  * The tool rebalances IP addresses.

Extensions:

  * The new node is not reachable: the tool changes the new node's status to off-line in the database.
  * The new node is reachable, but one or more checks fail: TODO

TODO: Should it try to start replication on a slave that comes online?  (I think it should -- setting a dupe server\_id can affect existing servers -- a new node should NOT have replication started yet IMO)

## Take a node off-line for maintenance ##

  * Primary Actor: system administrator.
  * Preconditions: the cluster is running, and there is an active controller.
  * Success Guarantee: the specified node will have no rules and no virtual IP addresses.

Main Success Scenario:

  * The user updates a row in the nodes table and sets its role to off-line.
  * TODO

## Move a role to another node ##

## Add an IP address to the cluster ##

## Remove a node from the cluster ##

## Move a slave to a new master ##

  * wait until slaves are caught up before moving IPs.  Let slaves finish executing their relay logs before moving to a new master.

## Bring a node back online ##

## Remove an IP address from the cluster ##

## Reconfigure a cluster ##

## Add an IP address to a node ##

## Remove an IP address from a node ##

## Test whether an IP address is present ##

## Test for my SQL replication delay ##

## Test whether replication is running ##

## Test whether a node is alive ##

## Make a node read-only ##

  * kill connections when setting @@read\_only

## Make a node writable ##

## Test whether a node is writable ##

## Start replication ##

## Stop replication ##

## Terminate connections to a node ##

## Check configuration on a node for read-only and skip slave start ##

## Send a replication heartbeat ##

## Detect a failed controller ##

Look at the heartbeat on the writable node.  If it's not updated there, look at the heartbeat table on all nodes, to see if the writable node has been fenced off from the cluster.  If you find a new writable node, look there, repeat.  If you don't find a new writable node, assume the original one is still writable.  Look at it and try to see if SHOW PROCESSLIST shows the controller's thread.  If not, assume the controller is dead; take over the cluster.

## Assume control of the cluster ##

## Relinquish control of the cluster ##

## Fence off a failed node ##

## Read the desired state of the cluster ##

## Observe the current state of the cluster ##

## Compare the observed state to the desired state ##

## Find differences between the desired state and the observed state ##

## Decide how to reconcile differences in state ##

## Read updated cluster configuration ##

Every loop we read configuration and sanity-check it.  If it's invalid we
correct it.

  * There is a writer role, and it has only one address.
  * make sure @@server\_id gotten from ip\_address matches node.id

## Test that a slave is connected to a Master ##

## Test that the master has a correct slave ##

## Synchronize the stored state with the observed state ##

## Wait for sleep to catch up ##

## Let a slave finish executing relay logs ##

## Balance roles among nodes ##

## Determine whether a node is eligible for rule ##

## Change a node's role ##

## Test whether the database is available ##

## Perform routine sanity checks on an instance ##

In the main loop, every node in the cluster is checked for the following:

  * It agrees with the writable master about which server is the writable.  If this doesn't hold, then it might mean the controller has been booted by a takeover.  TODO
  * There are no new unwanted slaves on this node.  If there are, we should fence them off and mark them misconfigured if so configured.
  * All of the initial sanity checks hold (@@read\_only, for example)
  * TODO: for a different use case... The 'user' config variable matches the result of CURRENT\_USER().

## Perform initial sanity checks on an instance ##

When a node is added to the cluster, the tool should perform checks on it.  The tool should warn and refuse to join the node to the cluster if any of the following is not true:

  * The node's server\_id is unique
  * --skip-slave-start is set
  * --read\_only is set
  * There are no replication filters in master or slave status
  * Check privileges and look for SUPER -- refuse (?) to initialize if SUPER is granted too liberally?
  * The state/configuration tables are not transactional.
  * It is possible to SSH to the node.

If any of the checks fails, the node's status should be set to "misconfigured".