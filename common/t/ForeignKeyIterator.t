#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 26;

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

my $in  = "$trunk/common/t/samples/mysqldump-no-data/";
my $out = "common/t/samples/ForeignKeyIterator/";

sub test_fki {
   my ( %args ) = @_;
   my @required_args = qw(files db tbl test_name);
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
      SchemaIterator => $si,
      Quoter         => $q,
      TableParser    => $tp,
   );

   while ( my %obj = $fki->next_schema_object() ) {
      print Dumper(\%obj);
   }

   return;
}

test_fki(
   files     => ["$in/one-db.txt"],
   db        => 'sakila',
   tbl       => 'customer',
   test_name => 'Iterate sakila.address',
);

# #############################################################################
# Done.
# #############################################################################
exit;
