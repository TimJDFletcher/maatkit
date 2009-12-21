#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 5;

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "perl ../mk-parallel-restore -F $cnf ";
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# #############################################################################
# Test stuff like --disable-keys, --unique-checks, etc.
# #############################################################################
$output = `$cmd samples/fast_index --dry-run --quiet -t store -t film_text`;
is(
   $output,
"USE `sakila`
DROP TABLE IF EXISTS `sakila`.`film_text`
CREATE TABLE `film_text` (
  `film_id` smallint(6) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  PRIMARY KEY  (`film_id`),
  KEY  (`title`),
  FULLTEXT KEY `idx_title_description` (`title`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8

USE `sakila`
/*!40000 ALTER TABLE `sakila`.`film_text` DISABLE KEYS */
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `film_text` VALUES (1,'ACADEMY DINOSAUR','A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies');
/*!40000 ALTER TABLE `sakila`.`film_text` ENABLE KEYS */
",
   'Disables/enables keys by default for MyISAM table'
);

$output = `$cmd samples/fast_index --dry-run --quiet -t store -t film_text --no-disable-keys`;
is(
   $output,
"USE `sakila`
DROP TABLE IF EXISTS `sakila`.`film_text`
CREATE TABLE `film_text` (
  `film_id` smallint(6) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  PRIMARY KEY  (`film_id`),
  KEY  (`title`),
  FULLTEXT KEY `idx_title_description` (`title`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8

USE `sakila`
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `film_text` VALUES (1,'ACADEMY DINOSAUR','A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies');
",
   'Does not disables/enables keys with --no-disable-keys'
);

$output = `$cmd samples/fast_index --dry-run --quiet -t store -t film_text --no-no-auto-value-on-0`;
is(
   $output,
"USE `sakila`
DROP TABLE IF EXISTS `sakila`.`film_text`
CREATE TABLE `film_text` (
  `film_id` smallint(6) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  PRIMARY KEY  (`film_id`),
  KEY  (`title`),
  FULLTEXT KEY `idx_title_description` (`title`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8

USE `sakila`
/*!40000 ALTER TABLE `sakila`.`film_text` DISABLE KEYS */
INSERT INTO `film_text` VALUES (1,'ACADEMY DINOSAUR','A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies');
/*!40000 ALTER TABLE `sakila`.`film_text` ENABLE KEYS */
",
   '--no-no-auto-value-on-0'
);

$output = `$cmd samples/fast_index --dry-run --quiet -t store -t film_text --no-unique-checks`;
is(
   $output,
"USE `sakila`
DROP TABLE IF EXISTS `sakila`.`film_text`
CREATE TABLE `film_text` (
  `film_id` smallint(6) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  PRIMARY KEY  (`film_id`),
  KEY  (`title`),
  FULLTEXT KEY `idx_title_description` (`title`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8

USE `sakila`
/*!40000 ALTER TABLE `sakila`.`film_text` DISABLE KEYS */
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
SET UNIQUE_CHECKS=0
INSERT INTO `film_text` VALUES (1,'ACADEMY DINOSAUR','A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies');
/*!40000 ALTER TABLE `sakila`.`film_text` ENABLE KEYS */
",
   '--no-unique-checks'
);

$output = `$cmd samples/fast_index --dry-run --quiet -t store -t film_text --no-foreign-key-checks`;
is(
   $output,
"USE `sakila`
SET FOREIGN_KEY_CHECKS=0
DROP TABLE IF EXISTS `sakila`.`film_text`
CREATE TABLE `film_text` (
  `film_id` smallint(6) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  PRIMARY KEY  (`film_id`),
  KEY  (`title`),
  FULLTEXT KEY `idx_title_description` (`title`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8

USE `sakila`
/*!40000 ALTER TABLE `sakila`.`film_text` DISABLE KEYS */
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
SET FOREIGN_KEY_CHECKS=0
INSERT INTO `film_text` VALUES (1,'ACADEMY DINOSAUR','A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies');
/*!40000 ALTER TABLE `sakila`.`film_text` ENABLE KEYS */
",
   '--no-foreign-key-checks'
);

# #############################################################################
# Done.
# #############################################################################
exit;
