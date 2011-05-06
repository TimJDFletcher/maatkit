DROP DATABASE IF EXISTS mk_heartbeat_test;
CREATE DATABASE mk_heartbeat_test;
USE mk_heartbeat_test;
CREATE TABLE heartbeat (
  `id` smallint(5) unsigned NOT NULL,
  `ts` float NOT NULL,
  `server_id` smallint(5) unsigned NOT NULL,
  `binlog_file` varchar(255) DEFAULT NULL,
  `binlog_pos` bigint(20) unsigned DEFAULT NULL,
  `master_server_id` smallint(5) unsigned DEFAULT NULL,
  `master_binlog_file` varchar(255) DEFAULT NULL,
  `master_binlog_pos` bigint(20) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MEMORY;
