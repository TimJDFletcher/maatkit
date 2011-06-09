#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

use ForeignKeyIterator;
use SchemaIterator;
use FileIterator;
use Quoter;
use TableParser;
use DSNParser;
use OptionParser;
use MaatkitTest;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $q  = new Quoter();
my $tp = new TableParser(Quoter => $q);
my $fi = new FileIterator();
my $o  = new OptionParser(description => 'SchemaIterator');
$o->get_specs("$trunk/mk-table-checksum/mk-table-checksum");

my $in  = "$trunk/common/t/samples/ForeignKeyIterator/";
my $out = "common/t/samples/ForeignKeyIterator/";

sub test_fki {
   my ( %args ) = @_;
   my @required_args = qw(files db tbl test_name result);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }

   @ARGV = $args{filters} ? @{$args{filters}} : ();
   $o->get_opts();

   my $file_itr = $fi->get_file_itr(@{$args{files}});
   my $si = new SchemaIterator(
      file_itr     => $file_itr,
      OptionParser => $o,
      Quoter       => $q,
   );

   my $fki = new ForeignKeyIterator(
      db             => $args{db},
      tbl            => $args{tbl},
      reverse        => $args{reverse},
      SchemaIterator => $si,
      Quoter         => $q,
      TableParser    => $tp,
   );

   my @got;
   while ( my $obj = $fki->next_schema_object() ) {
      delete $obj->{ddl} unless $args{ddl};
      delete $obj->{fks} unless $args{fks};
      push @got, $obj;
   }

   is_deeply(
      \@got,
      $args{result},
      $args{test_name},
   ) or print Dumper(\@got);

   return;
}

test_fki(
   test_name => 'Iterate from address (fktbls001.sql)',
   files     => ["$in/fktbls001.sql"],
   db        => 'test',
   tbl       => 'address',
   ddl       => 1,
   result    => [
      {
         db  => 'test',
         tbl => 'address',
         ddl => 'CREATE TABLE `address` (
  `address_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `address` varchar(50) NOT NULL,
  `city_id` smallint(5) unsigned NOT NULL,
  `postal_code` varchar(10) DEFAULT NULL,
  PRIMARY KEY (`address_id`),
  KEY `idx_fk_city_id` (`city_id`),
  CONSTRAINT `fk_address_city` FOREIGN KEY (`city_id`) REFERENCES `city` (`city_id`) ON UPDATE CASCADE
) ENGINE=InnoDB;',
      },
      {
         db  => 'test',
         tbl => 'city',
         ddl => 'CREATE TABLE `city` (
  `city_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `city` varchar(50) NOT NULL,
  `country_id` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`city_id`),
  KEY `idx_fk_country_id` (`country_id`),
  CONSTRAINT `fk_city_country` FOREIGN KEY (`country_id`) REFERENCES `country` (`country_id`) ON UPDATE CASCADE
) ENGINE=InnoDB;',
      },
      {
         db  => 'test',
         tbl => 'country',
         ddl => 'CREATE TABLE `country` (
  `country_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `country` varchar(50) NOT NULL,
  PRIMARY KEY (`country_id`)
) ENGINE=InnoDB;',
      },
   ],
);

test_fki(
   test_name => 'Iterate from data (fktbls002.sql)',
   files     => ["$in/fktbls002.sql"],
   db        => 'test',
   tbl       => 'data',
   ddl       => 1,
   fks       => 1,
   result    => [
      {
         db  => 'test',
         tbl => 'data',
         ddl => 'CREATE TABLE `data` (
  `data_report` int(11) NOT NULL DEFAULT \'0\',
  `hour` tinyint(4) NOT NULL DEFAULT \'0\',
  `entity` int(11) NOT NULL DEFAULT \'0\',
  `data_1` varchar(16) DEFAULT NULL,
  `data_2` varchar(16) DEFAULT NULL,
  PRIMARY KEY (`data_report`,`hour`,`entity`),
  KEY `entity` (`entity`),
  CONSTRAINT `data_ibfk_1` FOREIGN KEY (`data_report`) REFERENCES `data_report` (`id`),
  CONSTRAINT `data_ibfk_2` FOREIGN KEY (`entity`) REFERENCES `entity` (`id`)
) ENGINE=InnoDB;',
         fks => {
            data_ibfk_1 => {
               name     => 'data_ibfk_1',
               colnames => '`data_report`',
               cols     => [ 'data_report' ],
               parent_colnames => '`id`',
               parent_cols     => [ 'id' ],
               parent_tbl      => '`test`.`data_report`',
               ddl => 'CONSTRAINT `data_ibfk_1` FOREIGN KEY (`data_report`) REFERENCES `data_report` (`id`)',
            },
            data_ibfk_2 => {
               name     => 'data_ibfk_2',
               colnames => '`entity`',
               cols     => [ 'entity' ],
               parent_colnames => '`id`',
               parent_cols     => [ 'id' ],
               parent_tbl      => '`test`.`entity`',
               ddl => 'CONSTRAINT `data_ibfk_2` FOREIGN KEY (`entity`) REFERENCES `entity` (`id`)',
            },
         },
      },
      {
         db  => 'test',
         tbl => 'entity',
         ddl => 'CREATE TABLE `entity` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `entity_property_1` varchar(16) DEFAULT NULL,
  `entity_property_2` varchar(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `entity_property_1` (`entity_property_1`,`entity_property_2`)
) ENGINE=InnoDB;',
         fks => undef,
      },
      {
         db  => 'test',
         tbl => 'data_report',
         ddl => 'CREATE TABLE `data_report` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `date` date DEFAULT NULL,
  `posted` datetime DEFAULT NULL,
  `acquired` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `date` (`date`,`posted`,`acquired`)
) ENGINE=InnoDB;',
         fks => undef,
      },
   ],
);

# There is a circular reference between store and staff, but the
# code should handle it. See http://dev.mysql.com/doc/sakila/en/sakila.html
# for the entire sakila db table structure.
test_fki(
   test_name => 'Iterate from sakila.customer',
   files     => ["$trunk/common/t/samples/mysqldump-no-data/all-dbs.txt"],
   db        => 'sakila',
   tbl       => 'customer',
   result    => [
      { db  => 'sakila', tbl => 'customer' },
      { db  => 'sakila', tbl => 'store'    },
      { db  => 'sakila', tbl => 'staff'    },
      { db  => 'sakila', tbl => 'address'  },
      { db  => 'sakila', tbl => 'city'     },
      { db  => 'sakila', tbl => 'country'  },
   ],
);

test_fki(
   test_name => 'Iterate from sakila.customer reversed',
   files     => ["$trunk/common/t/samples/mysqldump-no-data/all-dbs.txt"],
   db        => 'sakila',
   tbl       => 'customer',
   reverse   => 1,
   result    => [
      { db  => 'sakila', tbl => 'country'  },
      { db  => 'sakila', tbl => 'city'     },
      { db  => 'sakila', tbl => 'address'  },
      { db  => 'sakila', tbl => 'staff'    },
      { db  => 'sakila', tbl => 'store'    },
      { db  => 'sakila', tbl => 'customer' },
   ],
);

# #############################################################################
# Done.
# #############################################################################
exit;
