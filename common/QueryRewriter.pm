# This program is copyright 2007-2009 Baron Schwartz.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.
# ###########################################################################
# QueryRewriter package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package QueryRewriter;

use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# A list of verbs that can appear in queries.  I know this is incomplete -- it
# does not have CREATE, DROP, ALTER, TRUNCATE for example.  But I don't need
# those for my client yet.  Other verbs: KILL, LOCK, UNLOCK
our $verbs   = qr{^SHOW|^FLUSH|^COMMIT|^ROLLBACK|^BEGIN|SELECT|INSERT
                  |UPDATE|DELETE|REPLACE|^SET|UNION|^START|^LOCK}xi;
my $quote_re = qr/"(?:(?!(?<!\\)").)*"|'(?:(?!(?<!\\)').)*'/; # Costly!
my $bal;
$bal         = qr/
                  \(
                  (?:
                     (?> [^()]+ )    # Non-parens without backtracking
                     |
                     (??{ $bal })    # Group with matching parens
                  )*
                  \)
                 /x;

# The one-line comment pattern is quite crude.  This is intentional for
# performance.  The multi-line pattern does not match version-comments.
my $olc_re = qr/(?:--|#)[^'"\r\n]*(?=[\r\n]|\Z)/;  # One-line comments
my $mlc_re = qr#/\*[^!].*?\*/#sm;                  # But not /*!version */
my $vlc_re = qr#/\*.*?[0-9+].*?\*/#sm;                  # But for replacing SHOW + /*!version */
my $vlc_rf = qr#^(SHOW).*?/\*![0-9+].*?\*/#sm;    		# ^^ if its starts with SHOW followed by version

sub new {
   my ( $class, %args ) = @_;
   my $self = { %args };
   return bless $self, $class;
}

# Strips comments out of queries.
sub strip_comments {
   my ( $self, $query ) = @_;
   return unless $query;
   $query =~ s/$olc_re//go;
   $query =~ s/$mlc_re//go;
   if ( $query =~ m/$vlc_rf/i ) { # contains show + version
   			$query =~ s/$vlc_re//go;
   }
   return $query;
}

# Shortens long queries by normalizing stuff out of them.  $length is used only
# for IN() lists.  If $length is given, the query is shortened if it's longer
# than that.
sub shorten {
   my ( $self, $query, $length ) = @_;
   # Shorten multi-value insert/replace, all the way up to on duplicate key
   # update if it exists.
   $query =~ s{
      \A(
         (?:INSERT|REPLACE)
         (?:\s+LOW_PRIORITY|DELAYED|HIGH_PRIORITY|IGNORE)?
         (?:\s\w+)*\s+\S+\s+VALUES\s*\(.*?\)
      )
      \s*,\s*\(.*?(ON\s+DUPLICATE|\Z)}
      {$1 /*... omitted ...*/$2}xsi;

   # Shortcut!  Find out if there's an IN() list with values.
   return $query unless $query =~ m/IN\s*\(\s*(?!select)/i;

   # Shorten long IN() lists of literals.  But only if the string is longer than
   # the $length limit.  Assumption: values don't contain commas or closing
   # parens inside them.
   my $last_length  = 0;
   my $query_length = length($query);
   while (
      $length          > 0
      && $query_length > $length
      && $query_length < ( $last_length || $query_length + 1 )
   ) {
      $last_length = $query_length;
      $query =~ s{
         (\bIN\s*\()    # The opening of an IN list
         ([^\)]+)       # Contents of the list, assuming no item contains paren
         (?=\))           # Close of the list
      }
      {
         $1 . __shorten($2)
      }gexsi;
   }

   return $query;
}

# Used by shorten().  The argument is the stuff inside an IN() list.  The
# argument might look like this:
#  1,2,3,4,5,6
# Or, if this is a second or greater iteration, it could even look like this:
#  /*... omitted 5 items ...*/ 6,7,8,9
# In the second case, we need to trim out 6,7,8 and increment "5 items" to "8
# items".  We assume that the values in the list don't contain commas; if they
# do, the results could be a little bit wrong, but who cares.  We keep the first
# 20 items because we don't want to nuke all the samples from the query, we just
# want to shorten it.
sub __shorten {
   my ( $snippet ) = @_;
   my @vals = split(/,/, $snippet);
   return $snippet unless @vals > 20;
   my @keep = splice(@vals, 0, 20);  # Remove and save the first 20 items
   return
      join(',', @keep)
      . "/*... omitted "
      . scalar(@vals)
      . " items ...*/";
}

# Normalizes variable queries to a "query fingerprint" by abstracting away
# parameters, canonicalizing whitespace, etc.  See
# http://dev.mysql.com/doc/refman/5.0/en/literals.html for literal syntax.
# Note: Any changes to this function must be profiled for speed!  Speed of this
# function is critical for mk-log-parser.  There are known bugs in this, but the
# balance between maybe-you-get-a-bug and speed favors speed.  See past
# revisions of this subroutine for more correct, but slower, regexes.
sub fingerprint {
   my ( $self, $query ) = @_;

   # First, we start with a bunch of special cases that we can optimize because
   # they are special behavior or because they are really big and we want to
   # throw them away as early as possible.
   $query =~ m#\ASELECT /\*!40001 SQL_NO_CACHE \*/ \* FROM `# # mysqldump query
      && return 'mysqldump';
   # Matches queries like REPLACE /*foo.bar:3/3*/ INTO checksum.checksum
   $query =~ m#/\*\w+\.\w+:[0-9]/[0-9]\*/#     # mk-table-checksum, etc query
      && return 'maatkit';
   # Administrator commands appear to be a comment, so return them as-is
   $query =~ m/\A# administrator command: /
      && return $query;
   # Special-case for stored procedures.
   $query =~ m/\A\s*(call\s+\S+)\(/i
      && return lc($1); # Warning! $1 used, be careful.
   # mysqldump's INSERT statements will have long values() lists, don't waste
   # time on them... they also tend to segfault Perl on some machines when you
   # get to the "# Collapse IN() and VALUES() lists" regex below!
   if ( my ($beginning) = $query =~ m/\A((?:INSERT|REPLACE)(?: IGNORE)?\s+INTO.+?VALUES\s*\(.*?\))\s*,\s*\(/is ) {
      $query = $beginning; # Shorten multi-value INSERT statements ASAP
   }

   $query =~ s/$olc_re//go;
   $query =~ s/$mlc_re//go;
   $query =~ s/\Ause \S+\Z/use ?/i       # Abstract the DB in USE
      && return $query;

   $query =~ s/\\["']//g;                # quoted strings
   $query =~ s/".*?"/?/sg;               # quoted strings
   $query =~ s/'.*?'/?/sg;               # quoted strings
   # This regex is extremely broad in its definition of what looks like a
   # number.  That is for speed.
   $query =~ s/[0-9+-][0-9a-f.xb+-]*/?/g;# Anything vaguely resembling numbers
   $query =~ s/[xb.+-]\?/?/g;            # Clean up leftovers
   $query =~ s/\A\s+//;                  # Chop off leading whitespace
   chomp $query;                         # Kill trailing whitespace
   $query =~ tr[ \n\t\r\f][ ]s;          # Collapse whitespace
   $query = lc $query;
   $query =~ s/\bnull\b/?/g;             # Get rid of NULLs
   $query =~ s{                          # Collapse IN and VALUES lists
               \b(in|values?)(?:[\s,]*\([\s?,]*\))+
              }
              {$1(?+)}gx;
   $query =~ s{                          # Collapse UNION
               \b(select\s.*?)(?:(\sunion(?:\sall)?)\s\1)+
              }
              {$1 /*repeat$2*/}xg;
   $query =~ s/\blimit \?(?:, ?\?| offset \?)?/limit ?/; # LIMIT
   # The following are disabled because of speed issues.  Should we try to
   # normalize whitespace between and around operators?  My gut feeling is no.
   # $query =~ s/ , | ,|, /,/g;    # Normalize commas
   # $query =~ s/ = | =|= /=/g;       # Normalize equals
   # $query =~ s# [,=+*/-] ?|[,=+*/-] #+#g;    # Normalize operators
   return $query;
}

sub _distill_verbs {
   my ( $self, $query ) = @_;

   # Special cases.
   $query =~ m/\A\s*call\s+(\S+)\(/i
      && return "CALL $1"; # Warning! $1 used, be careful.
   if ( $query =~ m/\A# administrator command:/ ) {
		$query =~ s/# administrator command:/ADMIN/go;
		$query = uc $query;
       	return "$query";
   }
   $query =~ m/\A\s*use\s+/
      && return "USE";
   $query =~ m/\A\s*UNLOCK TABLES/i
      && return "UNLOCK";
   $query =~ m/\A\s*xa\s+(\S+)/i
      && return "XA_$1";

   $query = $self->strip_comments($query);

   if ( $query =~ m/\A\s*SHOW\s+/i ) {
      my @what = $query =~ m/SHOW\s+(\S+)(?:\s+(\S+))?/i;
      MKDEBUG && _d('SHOW', @what);
      return unless scalar @what;
      @what = map { uc $_ } grep { defined $_ } @what; 

      # Handles SHOW CREATE * and SHOW * STATUS and SHOW MASTER *.
      if ( $what[0] =~ m/CREATE/
           || ($what[1] && $what[1] =~ m/STATUS/)
           || $what[0] =~ m/MASTER/ ) {
         return "SHOW $what[0] $what[1]";
      }
      else {
         $what[0] =~ m/GLOBAL/ ? return "SHOW $what[1]"
                  :              return "SHOW $what[0]";
      }
   }

   # More special cases for data defintion statements.
   # The two evals are a hack to keep Perl from warning that
   # "QueryParser::data_def_stmts" used only once: possible typo at...".
   # Some day we'll group all our common regex together in a packet and
   # export/import them properly.
   eval $QueryParser::data_def_stmts;
   eval $QueryParser::tbl_ident;
   my ( $dds ) = $query =~ /^\s*($QueryParser::data_def_stmts)\b/i;
   if ( $dds ) {
      my ( $obj ) = $query =~ m/$dds.+(DATABASE|TABLE)\b/i;
      $obj = uc $obj if $obj;
      MKDEBUG && _d('Data def statment:', $dds, 'obj:', $obj);
      my ($db_or_tbl)
         = $query =~ m/(?:TABLE|DATABASE)\s+($QueryParser::tbl_ident)(\s+.*)?/i;
      MKDEBUG && _d('Matches db or table:', $db_or_tbl);
      return uc($dds . ($obj ? " $obj" : '')), $db_or_tbl;
   }

   # First, get the query type -- just extract all the verbs and collapse them
   # together.
   my @verbs = $query =~ m/\b($verbs)\b/gio;
   @verbs    = do {
      my $last = '';
      grep { my $pass = $_ ne $last; $last = $_; $pass } map { uc } @verbs;
   };
   my $verbs = join(q{ }, @verbs);
   $verbs =~ s/( UNION SELECT)+/ UNION/g;

   return $verbs;
}

sub _distill_tables {
   my ( $self, $query, $table, %args ) = @_;
   my $qp = $args{QueryParser} || $self->{QueryParser};
   die "I need a QueryParser argument" unless $qp;

   # "Fingerprint" the tables.
   my @tables = map {
      $_ =~ s/`//g;
      $_ =~ s/(_?)[0-9]+/$1?/g;
      $_;
   } grep { defined $_ } $qp->get_tables($query);

   push @tables, $table if $table;

   # Collapse the table list
   @tables = do {
      my $last = '';
      grep { my $pass = $_ ne $last; $last = $_; $pass } @tables;
   };

   return @tables;
}

# This is kind of like fingerprinting, but it super-fingerprints to something
# that shows the query type and the tables/objects it accesses.
sub distill {
   my ( $self, $query, %args ) = @_;

   if ( $args{generic} ) {
      # Do a generic distillation which returns the first two words
      # of a simple "cmd arg" query, like memcached and HTTP stuff.
      my ($cmd, $arg) = $query =~ m/^(\S+)\s+(\S+)/;
      return '' unless $cmd;
      $query = (uc $cmd) . ($arg ? " $arg" : '');
   }
   else {
      # _distill_verbs() may return a table if it's a special statement
      # like TRUNCATE TABLE foo.  _distill_tables() handles some but not
      # all special statements so we pass it this special table in case
      # it's a statement it can't handle.  If it can handle it, it will
      # eliminate any duplicate tables.
      my ($verbs, $table)  = $self->_distill_verbs($query, %args);
      my @tables           = $self->_distill_tables($query, $table, %args);
      $query               = join(q{ }, $verbs, @tables);
   }
   
   if ( $args{trf} ) {
      $query = $args{trf}->($query, %args);
   }

   return $query;
}

sub convert_to_select {
   my ( $self, $query ) = @_;
   return unless $query;
   $query =~ s{
                 \A.*?
                 update\s+(.*?)
                 \s+set\b(.*?)
                 (?:\s*where\b(.*?))?
                 (limit\s*[0-9]+(?:\s*,\s*[0-9]+)?)?
                 \Z
              }
              {__update_to_select($1, $2, $3, $4)}exsi
      || $query =~ s{
                    \A.*?
                    (?:insert|replace)\s+
                    .*?\binto\b(.*?)\(([^\)]+)\)\s*
                    values?\s*(\(.*?\))\s*
                    (?:\blimit\b|on\s*duplicate\s*key.*)?\s*
                    \Z
                 }
                 {__insert_to_select($1, $2, $3)}exsi
      || $query =~ s{
                    \A.*?
                    delete\s+(.*?)
                    \bfrom\b(.*)
                    \Z
                 }
                 {__delete_to_select($1, $2)}exsi;
   $query =~ s/\s*on\s+duplicate\s+key\s+update.*\Z//si;
   $query =~ s/\A.*?(?=\bSELECT\s*\b)//ism;
   return $query;
}

sub convert_select_list {
   my ( $self, $query ) = @_;
   $query =~ s{
               \A\s*select(.*?)\bfrom\b
              }
              {$1 =~ m/\*/ ? "select 1 from" : "select isnull(coalesce($1)) from"}exi;
   return $query;
}

sub __delete_to_select {
   my ( $delete, $join ) = @_;
   if ( $join =~ m/\bjoin\b/ ) {
      return "select 1 from $join";
   }
   return "select * from $join";
}

sub __insert_to_select {
   my ( $tbl, $cols, $vals ) = @_;
   MKDEBUG && _d('Args:', @_);
   my @cols = split(/,/, $cols);
   MKDEBUG && _d('Cols:', @cols);
   $vals =~ s/^\(|\)$//g; # Strip leading/trailing parens
   my @vals = $vals =~ m/($quote_re|[^,]*${bal}[^,]*|[^,]+)/g;
   MKDEBUG && _d('Vals:', @vals);
   if ( @cols == @vals ) {
      return "select * from $tbl where "
         . join(' and ', map { "$cols[$_]=$vals[$_]" } (0..$#cols));
   }
   else {
      return "select * from $tbl limit 1";
   }
}

sub __update_to_select {
   my ( $from, $set, $where, $limit ) = @_;
   return "select $set from $from "
      . ( $where ? "where $where" : '' )
      . ( $limit ? " $limit "      : '' );
}

sub wrap_in_derived {
   my ( $self, $query ) = @_;
   return unless $query;
   return $query =~ m/\A\s*select/i
      ? "select 1 from ($query) as x limit 1"
      : $query;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

1;

# ###########################################################################
# End QueryRewriter package
# ###########################################################################
