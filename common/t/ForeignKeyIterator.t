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
      TableParser  => $tp,
      keep_ddl     => 1,
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
   result    => [
      {
         db  => 'test',
         tbl => 'address',
      },
      {
         db  => 'test',
         tbl => 'city',
      },
      {
         db  => 'test',
         tbl => 'country',
      },
   ],
);

test_fki(
   test_name => 'Iterate from data (fktbls002.sql)',
   files     => ["$in/fktbls002.sql"],
   db        => 'test',
   tbl       => 'data',
   fks       => 1,
   result    => [
      {
         db  => 'test',
         tbl => 'data',
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
         fks => undef,
      },
      {
         db  => 'test',
         tbl => 'data_report',
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
