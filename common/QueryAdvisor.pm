# This program is copyright 2010 Percona Inc.
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
# QueryAdvisor package $Revision$
# ###########################################################################
package QueryAdvisor;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Arguments:
#   * ignore_rules  hashref: rule IDs to ignore
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw() ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $self = {
      %args,
      rules          => [],  # Rules from all advisor modules.
      rule_index_for => {},  # Maps rules by ID to their array index in $rules.
      rule_info      => {},  # ID, severity, description, etc. for each rule.
   };

   return bless $self, $class;
}

# Load rules from the given advisor module.  Will die on duplicate
# rule IDs.
sub load_rules {
   my ( $self, $advisor ) = @_;
   return unless $advisor;
   MKDEBUG && _d('Loading rules from', ref $advisor);

   # Starting index value in rules arrayref for these rules.
   # This is >0 if rules from other advisor modules have
   # already been loaded.
   my $i = scalar @{$self->{rules}};

   RULE:
   foreach my $rule ( $advisor->get_rules() ) {
      my $id = $rule->{id};
      if ( $self->{ignore_rules}->{$id} ) {
         MKDEBUG && _d("Ignoring rule", $id);
         next RULE;
      }
      die "Rule $id already exists and cannot be redefined"
         if defined $self->{rule_index_for}->{$id};
      push @{$self->{rules}}, $rule;
      $self->{rule_index_for}->{$id} = $i++;
   }

   return;
}

sub load_rule_info {
   my ( $self, $advisor ) = @_;
   return unless $advisor;
   MKDEBUG && _d('Loading rule info from', ref $advisor);
   my $rules = $self->{rules};
   foreach my $rule ( @$rules ) {
      my $id = $rule->{id};
      if ( $self->{ignore_rules}->{$id} ) {
         # This shouldn't happen.  load_rules() should keep any ignored
         # rules out of $self->{rules}.
         die "Rule $id was loaded but should be ignored";
      }
      my $rule_info = $advisor->get_rule_info($id);
      next unless $rule_info;
      die "Info for rule $id already exists and cannot be redefined"
         if $self->{rule_info}->{$id};
      $self->{rule_info}->{$id} = $rule_info;
   }
   return;
}

sub run_rules {
   my ( $self, $event ) = @_;
   my @matched_rules;
   my @matched_pos;
   my $rules = $self->{rules};
   foreach my $rule ( @$rules ) {
      if ( defined(my $pos = $rule->{code}->($event)) ) {
         MKDEBUG && _d('Matches rule', $rule->{id}, 'near pos', $pos);
         push @matched_rules, $rule->{id};
         push @matched_pos,   $pos;
      }
   }
   return \@matched_rules, \@matched_pos;
};

sub get_rule_info {
   my ( $self, $id ) = @_;
   return unless $id;
   return $self->{rule_info}->{$id};
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
# End QueryAdvisor package
# ###########################################################################
