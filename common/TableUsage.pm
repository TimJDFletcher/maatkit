# This program is copyright 2011 Percona Inc.
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
# TableUsage package $Revision$
# ###########################################################################

# Package: TableUsage
# TableUsage determines how tables in a query are used.
#
# For best results, queries should be from EXPLAIN EXTENDED so all identifiers
# are fully qualified.  Else, some table references may be missed because
# no effort is made to table-qualify unqualified columns.
#
# This package uses both QueryParser and SQLParser.  The former is used for
# simple queries, and the latter is used for more complex queries where table
# usage may be hidden in who-knows-which clause of the SQL statement.
package TableUsage;

{ # package scope
use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Sub: new
#
# Parameters:
#   %args - Arguments
#
# Required Arguments:
#   QueryParser - <QueryParser> object
#   SQLParser   - <SQLParser> object
#
# Returns:
#   TableUsage object
sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw(QueryParser SQLParser);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $self = {
      %args,
   };

   return bless $self, $class;
}

# Sub: get_table_access
#   Get table access info for each table in the given query.  Table access
#   info includes the Context, Access (read or write) and the Table (CAT).
#
# Parameters:
#   %args - Arguments
#
# Required Arguments:
#   query - Query string
#
# Returns:
#   Arrayref of hashrefs, one for each CAT, like:
#   (code start)
#   [
#     { context => 'DELETE',
#       access  => 'write',
#       table   => 'd.t',
#     },
#     { context => 'DELETE',
#       access  => 'read',
#       table   => 'd.t',
#     },
#   ],
#   (code stop)
sub get_table_usage {
   my ( $self, %args ) = @_;
   my @required_args = qw(query);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($query)   = @args{@required_args};
   MKDEBUG && _d('Getting table access for',
      substr($query, 0, 100), (length $query > 100 ? '...' : ''));

   my $cats;  # arrayref of CAT hashrefs for each table

   # Try to parse the query first with SQLParser.  This may be overkill for
   # simple queries, but it's probably cheaper to just do this than to try
   # detect first if the query is simple enough to parse with QueryParser.
   my $query_struct;
   eval {
      $query_struct = $self->{SQLParser}->parse($query);
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d('Failed to parse query with SQLParser:', $EVAL_ERROR);
      if ( $EVAL_ERROR =~ m/Cannot parse/ ) {
         # SQLParser can't parse this type of query, so it's probably some
         # data definition statement with just a table list.  Use QueryParser
         # to extract the table list and hope we're not wrong.
         $cats = $self->_get_cats_from_query_parser(%args);
      }
      else {
         # SQLParser failed to parse the query due to some error.
         die $EVAL_ERROR;
      }
   }
   else {
      # SQLParser parsed the query, so now we need to examine its structure
      # to determine the CATs for each table.
      $cats = $self->_get_tables_used_from_query_struct(
         query_struct => $query_struct,
         %args,
      );
   }

   MKDEBUG && _d('Query table access:', Dumper($cats));
   return $cats;
}

sub _get_cats_from_query_parser {
   my ( $self, %args ) = @_;
   my @required_args = qw(query);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($query) = @args{@required_args};
   MKDEBUG && _d('Getting cats from tables');

   my @cats;

   $query = $self->{QueryParser}->clean_query($query);
   my ($context) = $query =~ m/(\w+)\s+/;
   $context = uc $context;
   die "Query does not begin with a word" unless $context;  # shouldn't happen
   MKDEBUG && _d('Context for each table:', $context);

   my $access = $context =~ m/(?:ALTER|CREATE|TRUNCATE|DROP|RENAME)/ ? 'write'
              : $context =~ m/(?:INSERT|REPLACE|UPDATE|DELETE)/      ? 'write'
              : $context eq 'SELECT'                                 ? 'read'
              :                                                        undef;
   MKDEBUG && _d('Access for each table:', $access);

   my @tables = $self->{QueryParser}->get_tables($query);
   foreach my $table ( @tables ) {
      $table =~ s/`//g;
      push @cats, {
         table   => $table,
         context => $context,
         access  => $access,
      };
   }

   return \@cats;
}

sub _get_tables_used_from_query_struct {
   my ( $self, %args ) = @_;
   my @required_args = qw(query_struct);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($query_struct) = @args{@required_args};
   my $sp             = $self->{SQLParser};

   MKDEBUG && _d('Getting table used from query struct');

   # The table references clause is different depending on the query type.
   my $query_type = uc $query_struct->{type};
   my $tbl_refs   = $query_type =~ m/(?:SELECT|DELETE)/  ? 'from'
                  : $query_type =~ m/(?:INSERT|REPLACE)/ ? 'into'
                  : $query_type =~ m/UPDATE/             ? 'tables'
                  : die "Cannot find table references for $query_type queries";
   my $tables     = $query_struct->{$tbl_refs};

   # Get tables used in the query's WHERE clause, if it has one.
   my $where;
   if ( $query_struct->{where} ) {
      $where = $self->_get_tables_used_in_where(
         %args,
         tables  => $tables,
         where   => $query_struct->{where},
      );
   }

   my @tables_used;
   if ( $query_type eq 'UPDATE' && @{$query_struct->{tables}} > 1 ) {
      MKDEBUG && _d("Multi-table UPDATE");
      # UPDATE queries with multiple tables are a special case.  The query
      # reads from each referenced table and writes only to tables referenced
      # in the SET clause.  Each written table is like its own query, so
      # we create a table usage hashref for each one.

      my $set_cats = $self->_get_tables_used_in_set(
         %args,
         context => $query_type,
         set     => $query_struct->{set},
         tables  => $tables,
      );
      push @tables_used, @$set_cats;
   }
   else {
      if ( $query_type eq 'SELECT' ) {
         my $clist_tables = $self->_get_tables_used_in_columns(
            %args,
            tables  => $tables,
            columns => $query_struct->{columns},
         );
         foreach my $table ( @$clist_tables ) {
            my $table_usage = {
               context => 'SELECT',
               table   => $table,
            };
            MKDEBUG && _d("Table usage from CLIST:", Dumper($table_usage));
            push @{$tables_used[0]}, $table_usage;
         }
      }

      if ( @$tables > 1 || $query_type ne 'SELECT' ) {
         my $context = @$tables > 1 ? 'JOIN' : $query_type;
         foreach my $table ( @$tables ) {
            my $table = $self->_qualify_table_name(
               %args,
               tables => $tables,
               db     => $table->{db},
               tbl    => $table->{name},
            );
            my $table_usage = {
               context => $context,
               table   => $table,
            };
            MKDEBUG && _d("Table usage from TLIST:", Dumper($table_usage));
            push @{$tables_used[0]}, $table_usage;
         }
      }

      if ( $where && $where->{joined_tables} ) {
         foreach my $table ( @{$where->{joined_tables}} ) {
            my $table_usage = {
               context => $query_type,
               table   => $table,
            };
            MKDEBUG && _d("Table usage from WHERE (implicit join):",
               Dumper($table_usage));
            push @{$tables_used[0]}, $table_usage;
         }
      }

      if ( $query_type =~ m/(?:INSERT|REPLACE)/ && $query_struct->{select} ) {
         MKDEBUG && _d("Getting tables used in INSERT-SELECT");
         my $insert_select_tables = $self->_get_tables_used_from_query_struct(
            %args,
            query_struct => $query_struct->{select},
         );
         push @{$tables_used[0]}, @$insert_select_tables;
      }

      if ( $where && $where->{filter_tables} ) {
         foreach my $table ( @{$where->{filter_tables}} ) {
            my $table_usage = {
               context => 'WHERE',
               table   => $table,
            };
            MKDEBUG && _d("Table usage from WHERE:", Dumper($table_usage));
            push @{$tables_used[0]}, $table_usage;
         }
      }
   }

   return \@tables_used;
}

sub _get_tables_used_in_columns {
   my ( $self, %args ) = @_;
   my @required_args = qw(tables columns);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($tables, $columns) = @args{@required_args};

   MKDEBUG && _d("Getting tables used in CLIST");

   # The easy case: only 1 table is used so all columns must access that table.
   if ( @$tables == 1 ) {
      my $table = $self->_qualify_table_name(
         %args,
         db  => $tables->[0]->{db},
         tbl => $tables->[0]->{name},
      );
      return [ $table ];
   }

   my @tables;
   foreach my $column ( @$columns ) {
      my $table = $self->_qualify_table_name(
         %args,
         db  => $column->{db},
         tbl => $column->{tbl},
      );
      push @tables, $table if $table;
   }

   return \@tables;
}

sub _get_tables_used_in_where {
   my ( $self, %args ) = @_;
   my @required_args = qw(tables where);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   MKDEBUG && _d("Getting tables used in WHERE");
   my $conditions = $self->_parse_conditions(
      %args,
      conditions => $args{where},
   );

   my @filter_tables;
   my @joined_tables;
   CONDITION:
   foreach my $cond ( @$conditions ) {
      if ( $cond->{join} ) {
         push @joined_tables, $cond->{table};
      }
      else {
         push @filter_tables, $cond->{table};
      }
   }

   return {
      filter_tables => \@filter_tables,
      joined_tables => \@joined_tables,
   };
}

sub _get_tables_used_in_set {
   my ( $self, %args ) = @_;
   my @required_args = qw(context tables set);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   MKDEBUG && _d("Getting tables used in SET");
   return $self->_get_tables_used_in_conditions(
      %args,
      conditions => $args{set},
   );
}

sub _parse_conditions {
   my ( $self, %args ) = @_;
   my @required_args = qw(conditions tables);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($conditions, $tables) = @args{@required_args};
   my $sql_parser = $self->{SQLParser};

   my @condition_structs;
   my %seen_table;
   CONDITION:
   foreach my $cond ( @$conditions ) {
      MKDEBUG && _d("Condition:", Dumper($cond));

      # If these are conditions from a WHERE clause, $cond->{column} will
      # not be parsed, so we need the call below.  If these are conditions
      # from a SET clause, then $cond may already have $cond->{tbl} and
      # $cond->{db}, so we don't need the call below.  We make the call in
      # any case for simplicity.
      my $col = $sql_parser->parse_identifier('column', $cond->{column});

      # Try to determine the column's table and database if it wasn't
      # already db- or tbl-qualified.
      my $tbl;
      if ( $cond->{tbl} || $col->{tbl} ) {
         $tbl = $self->_get_real_table_name(
            %args,
            name => $cond->{tbl} || $col->{tbl},
         );
      }
      elsif ( @$tables == 1 ) {
         MKDEBUG && _d("Condition column is not table-qualified; ",
            "using query's only table:", $tables->[0]->{name});
         $tbl = $tables->[0]->{name};
      }
      else {
         MKDEBUG && _d("Condition column is not table-qualified",
            "and query has multiple tables; cannot determine its table");
         next CONDITION;
      }

      my $db;
      if ( $cond->{db} || ($col->{tbl} && $col->{db}) ) {
         $db = $cond->{db} || $col->{db};
      }
      elsif ( @$tables == 1 && $tables->[0]->{db} ) {
         MKDEBUG && _d("Condition column is not database-qualified; ",
            "using query's only database:", $tables->[0]->{db});
         $db = $tables->[0]->{db};
      }

      # Determine if the value is another table or something else.
      # If it's another table, then this condition is acting as an
      # implicit JOIN (instead of an ANSI JOIN in the FROM clause).
      my $value;
      my $join = 0;
      if ( $sql_parser->is_identifier($cond->{value}) ) {
         $join = 1;
         my $join_col = $sql_parser->parse_identifier('column', $cond->{value});
         if ( !$join_col->{tbl} ) {
            warn "Implicitly joined table in WHERE clause is not "
               . "table-qualified: $cond->{value}";
            next CONDITION;
         }

         my $db  = $join_col->{db} || $args{default_db};
         my $tbl = $self->_get_real_table_name(
            %args,
            name => $join_col->{tbl},
         );

         $value = ($db ? "$db." : "") . $tbl;
      }
      else {
         # Value is not a table ref, so it may be a constant, a function, etc.
         # In any case, we treat it as the dummy DUAL value because if it's
         # not a table ref then we don't care what it is.
         $value = 'DUAL';
      }

      my $db_tbl = ($db ? "$db." : "") . $tbl;
      if ( !$seen_table{$db_tbl}++ || $join ) {
         my $cond_struct = {
            table  => $db_tbl,
            column => $col->{name},
            value  => $value,
            join   => $join,
         };
         MKDEBUG && _d("Condition struct:", Dumper($cond_struct));
         push @condition_structs, $cond_struct;
      }
   }

   return \@condition_structs;
}

sub _get_real_table_name {
   my ( $self, %args ) = @_;
   my @required_args = qw(tables name);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($tables, $name) = @args{@required_args};

   foreach my $table ( @$tables ) {
      if ( $table->{name} eq $name
           || ($table->{alias} || "") eq $name ) {
         MKDEBUG && _d("Real table name for", $name, "is", $table->{name});
         return $table->{name};
      }
   }
   warn "Table $name does not exist in query";  # shouldn't happen
   return;
}

sub _qualify_table_name {
   my ( $self, %args) = @_;
   my @required_args = qw(tables tbl);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($tables, $tbl) = @args{@required_args};

   # Always use real table names, not alias.
   my $real_tbl = $self->_get_real_table_name(%args, name => $tbl);
   return unless $real_tbl;  # shouldn't happen

   # The easy case: a db is already given, so use it.
   return "$args{db}.$real_tbl" if $args{db};

   # If no db is given, see if the table is db-qualified.
   foreach my $tbl ( @$tables ) {
      if ( $tbl->{name} eq $real_tbl && $tbl->{db} ) {
         return "$tbl->{db}.$real_tbl";
      }
   }

   # Last resort: use default db if it's given.
   return "$args{default_db}.$real_tbl" if $args{default_db};

   # Can't db-qualify the table, so return just the real table name.
   return $real_tbl;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

} # package scope
1;

# ###########################################################################
# End TableUsage package
# ###########################################################################
