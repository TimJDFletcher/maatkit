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
# OptionParser package $Revision$
# ###########################################################################
package OptionParser;

use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use List::Util qw(max);
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

my $POD_link_re = '[LC]<"?([^">]+)"?>';

my %attributes = (
   'type'       => 1,
   'short form' => 1,
   'group'      => 1,
   'default'    => 1,
   'cumulative' => 1,
   'negatable'  => 1,
);

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(description) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($program_name) = $PROGRAM_NAME =~ m/([.A-Za-z-]+)$/;
   $program_name ||= $PROGRAM_NAME;
   my $home = $ENV{HOME} || $ENV{HOMEPATH} || $ENV{USERPROFILE} || '.';

   my $self = {
      description    => $args{description},
      prompt         => $args{prompt} || '<options>',
      strict         => (exists $args{strict} ? $args{strict} : 1),
      dp             => $args{dp}     || undef,
      program_name   => $program_name,
      opts           => {},
      got_opts       => 0,
      short_opts     => {},
      defaults       => {},
      groups         => {},
      allowed_groups => {},
      errors         => [],
      rules          => [],  # desc of rules for --help
      mutex          => [],  # rule: opts are mutually exclusive
      atleast1       => [],  # rule: at least one opt is required
      disables       => {},  # rule: opt disables other opts 
      defaults_to    => {},  # rule: opt defaults to value of other opt
      default_files  => [
         "/etc/maatkit/maatkit.conf",
         "/etc/maatkit/$program_name.conf",
         "$home/.maatkit.conf",
         "$home/.$program_name.conf",
      ],
   };
   return bless $self, $class;
}

# Read and parse POD OPTIONS in file or current script if
# no file is given. This sub must be called before get_opts();
sub get_specs {
   my ( $self, $file ) = @_;
   my @specs = $self->_pod_to_specs($file);
   $self->_parse_specs(@specs);
   return;
}

# Returns the program's defaults files.
sub get_defaults_files {
   my ( $self ) = @_;
   return @{$self->{default_files}};
}

# Parse command line options from the OPTIONS section of the POD in the
# given file. If no file is given, the currently running program's POD
# is parsed.
# Returns an array of hashrefs which is usually passed to _parse_specs().
# Each hashref in the array corresponds to one command line option from
# the POD. Each hashref has the structure:
#    {
#       spec  => GetOpt::Long specification,
#       desc  => short description for --help
#       group => option group (default: 'default')
#    }
sub _pod_to_specs {
   my ( $self, $file ) = @_;
   $file ||= __FILE__;
   open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";

   my %types = (
      string => 's', # standard Getopt type
      'int'  => 'i', # standard Getopt type
      float  => 'f', # standard Getopt type
      Hash   => 'H', # hash, formed from a comma-separated list
      hash   => 'h', # hash as above, but only if a value is given
      Array  => 'A', # array, similar to Hash
      array  => 'a', # array, similar to hash
      DSN    => 'd', # DSN, as provided by a DSNParser which is in $self->{dp}
      size   => 'z', # size with kMG suffix (powers of 2^10)
      'time' => 'm', # time, with an optional suffix of s/h/m/d
   );
   my @specs = ();
   my @rules = ();
   my $para;

   # Read a paragraph at a time from the file.  Skip everything until options
   # are reached...
   local $INPUT_RECORD_SEPARATOR = '';
   while ( $para = <$fh> ) {
      next unless $para =~ m/^=head1 OPTIONS/;
      last;
   }

   # ... then read any option rules...
   while ( $para = <$fh> ) {
      last if $para =~ m/^=over/;
      chomp $para;
      $para =~ s/\s+/ /g;
      $para =~ s/$POD_link_re/$1/go;
      MKDEBUG && _d('Option rule:', $para);
      push @rules, $para;
   }

   die 'POD has no OPTIONS section' unless $para;

   # ... then start reading options.
   do {
      if ( my ($option) = $para =~ m/^=item --(.*)/ ) {
         chomp $para;
         MKDEBUG && _d($para);
         my %attribs;

         $para = <$fh>; # read next paragraph, possibly attributes

         if ( $para =~ m/: / ) { # attributes
            $para =~ s/\s+\Z//g;
            %attribs = map {
                  my ( $attrib, $val) = split(/: /, $_);
                  die "Unrecognized attribute for --$option: $attrib"
                     unless $attributes{$attrib};
                  ($attrib, $val);
               } split(/; /, $para);
            if ( $attribs{'short form'} ) {
               $attribs{'short form'} =~ s/-//;
            }
            $para = <$fh>; # read next paragraph, probably short help desc
         }
         else {
            MKDEBUG && _d('Option has no attributes');
         }

         # Remove extra spaces and POD formatting (L<"">).
         $para =~ s/\s+\Z//g;
         $para =~ s/\s+/ /g;
         $para =~ s/$POD_link_re/$1/go;

         # Take the first period-terminated sentence as the option's short help
         # description.
         $para =~ s/\.(?:\n.*| [A-Z].*|\Z)//s;
         MKDEBUG && _d('Short help:', $para);

         die "No description after option spec $option" if $para =~ m/^=item/;

         # Change [no]foo to foo and set negatable attrib. See issue 140.
         if ( my ($base_option) =  $option =~ m/^\[no\](.*)/ ) {
            $option = $base_option;
            $attribs{'negatable'} = 1;
         }

         push @specs, {
            spec  => $option
               . ($attribs{'short form'} ? '|' . $attribs{'short form'} : '' )
               . ($attribs{'negatable'}  ? '!'                          : '' )
               . ($attribs{'cumulative'} ? '+'                          : '' )
               . ($attribs{'type'}       ? '=' . $types{$attribs{type}} : '' ),
            desc  => $para
               . ($attribs{default} ? " (default $attribs{default})" : ''),
            group => ($attribs{'group'} ? $attribs{'group'} : 'default'),
         };
      }
      while ( $para = <$fh> ) {
         last unless $para;

         # The 'allowed with' hack that was here was removed.
         # Groups need to be used instead. So, this new OptionParser
         # module will not work with mk-table-sync.

         if ( $para =~ m/^=head1/ ) {
            $para = undef; # Can't 'last' out of a do {} block.
            last;
         }
         last if $para =~ m/^=item --/;
      }
   } while ( $para );

   die 'No valid specs in POD OPTIONS' unless @specs;

   close $fh;
   return @specs, @rules;
}

# Parse an array of option specs and rules (usually the return value of
# _pod_to_spec()). Each option spec is parsed and the following attributes
# pairs are added to its hashref:
#    short         => the option's short key (-A for --charset)
#    is_cumulative => true if the option is cumulative
#    is_negatable  => true if the option is negatable
#    is_required   => true if the option is required
#    type          => the option's type (see %types in _pod_to_spec() above)
#    got           => true if the option was given explicitly on the cmd line
#    value         => the option's value
#
sub _parse_specs {
   my ( $self, @specs ) = @_;
   my %disables; # special rule that requires deferred checking

   foreach my $opt ( @specs ) {
      if ( ref $opt ) { # It's an option spec, not a rule.
         MKDEBUG && _d('Parsing opt spec:',
            map { ($_, '=>', $opt->{$_}) } keys %$opt);

         my ( $long, $short ) = $opt->{spec} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
         if ( !$long ) {
            # This shouldn't happen.
            die "Cannot parse long option from spec $opt->{spec}";
         }
         $opt->{long} = $long;

         die "Duplicate long option --$long" if exists $self->{opts}->{$long};
         $self->{opts}->{$long} = $opt;

         if ( length $long == 1 ) {
            MKDEBUG && _d('Long opt', $long, 'looks like short opt');
            $self->{short_opts}->{$long} = $long;
         }

         if ( $short ) {
            die "Duplicate short option -$short"
               if exists $self->{short_opts}->{$short};
            $self->{short_opts}->{$short} = $long;
            $opt->{short} = $short;
         }
         else {
            $opt->{short} = undef;
         }

         $opt->{is_negatable}  = $opt->{spec} =~ m/!/        ? 1 : 0;
         $opt->{is_cumulative} = $opt->{spec} =~ m/\+/       ? 1 : 0;
         $opt->{is_required}   = $opt->{desc} =~ m/required/ ? 1 : 0;

         $opt->{group} ||= 'default';
         $self->{groups}->{ $opt->{group} }->{$long} = 1;

         $opt->{value} = undef;
         $opt->{got}   = 0;

         my ( $type ) = $opt->{spec} =~ m/=(.)/;
         $opt->{type} = $type;
         MKDEBUG && _d($long, 'type:', $type);

         if ( $type && $type eq 'd' && !$self->{dp} ) {
            die "$opt->{long} is type DSN (d) but no dp argument "
               . "was given when this OptionParser object was created";
         }

         # Option has a non-Getopt type: HhAadzm (see %types in
         # _pod_to_spec() above). For these, use Getopt type 's'.
         $opt->{spec} =~ s/=./=s/ if ( $type && $type =~ m/[HhAadzm]/ );

         # Option has a default value if its desc says 'default' or 'default X'.
         # These defaults from the POD may be overridden by later calls
         # to set_defaults().
         if ( (my ($def) = $opt->{desc} =~ m/default\b(?: ([^)]+))?/) ) {
            $self->{defaults}->{$long} = defined $def ? $def : 1;
            MKDEBUG && _d($long, 'default:', $def);
         }

         # Handle special behavior for --config.
         if ( $long eq 'config' ) {
            $self->{defaults}->{$long} = join(',', $self->get_defaults_files());
         }

         # Option disable another option if its desc says 'disable'.
         if ( (my ($dis) = $opt->{desc} =~ m/(disables .*)/) ) {
            # Defer checking till later because of possible forward references.
            $disables{$long} = $dis;
            MKDEBUG && _d('Deferring check of disables rule for', $opt, $dis);
         }

         # Save the option.
         $self->{opts}->{$long} = $opt;
      }
      else { # It's an option rule, not a spec.
         MKDEBUG && _d('Parsing rule:', $opt); 
         push @{$self->{rules}}, $opt;
         my @participants = $self->_get_participants($opt);
         my $rule_ok = 0;

         if ( $opt =~ m/mutually exclusive|one and only one/ ) {
            $rule_ok = 1;
            push @{$self->{mutex}}, \@participants;
            MKDEBUG && _d(@participants, 'are mutually exclusive');
         }
         if ( $opt =~ m/at least one|one and only one/ ) {
            $rule_ok = 1;
            push @{$self->{atleast1}}, \@participants;
            MKDEBUG && _d(@participants, 'require at least one');
         }
         if ( $opt =~ m/default to/ ) {
            $rule_ok = 1;
            # Example: "DSN values in L<"--dest"> default to values
            # from L<"--source">."
            $self->{defaults_to}->{$participants[0]} = $participants[1];
            MKDEBUG && _d($participants[0], 'defaults to', $participants[1]);
         }
         if ( $opt =~ m/restricted to option groups/ ) {
            $rule_ok = 1;
            my ($groups) = $opt =~ m/groups ([\w\s\,]+)/;
            my @groups = split(',', $groups);
            %{$self->{allowed_groups}->{$participants[0]}} = map {
               s/\s+//;
               $_ => 1;
            } @groups;
         }

         die "Unrecognized option rule: $opt" unless $rule_ok;
      }
   }

   # Check forward references in 'disables' rules.
   foreach my $long ( keys %disables ) {
      # _get_participants() will check that each opt exists.
      my @participants = $self->_get_participants($disables{$long});
      $self->{disables}->{$long} = \@participants;
      MKDEBUG && _d('Option', $long, 'disables', @participants);
   }

   return; 
}

# Returns an array of long option names in str. This is used to
# find the "participants" of option rules (i.e. the options to
# which a rule applies).
sub _get_participants {
   my ( $self, $str ) = @_;
   my @participants;
   foreach my $long ( $str =~ m/--(?:\[no\])?([\w-]+)/g ) {
      die "Option --$long does not exist while processing rule $str"
         unless exists $self->{opts}->{$long};
      push @participants, $long;
   }
   MKDEBUG && _d('Participants for', $str, ':', @participants);
   return @participants;
}

# Returns a copy of the internal opts hash.
sub opts {
   my ( $self ) = @_;
   my %opts = %{$self->{opts}};
   return %opts;
}

# Returns a copy of the internal short_opts hash.
sub short_opts {
   my ( $self ) = @_;
   my %short_opts = %{$self->{short_opts}};
   return %short_opts;
}

sub set_defaults {
   my ( $self, %defaults ) = @_;
   $self->{defaults} = {};
   foreach my $long ( keys %defaults ) {
      die "Cannot set default for nonexistent option $long"
         unless exists $self->{opts}->{$long};
      $self->{defaults}->{$long} = $defaults{$long};
      MKDEBUG && _d('Default val for', $long, ':', $defaults{$long});
   }
   return;
}

sub get_defaults {
   my ( $self ) = @_;
   return $self->{defaults};
}

sub get_groups {
   my ( $self ) = @_;
   return $self->{groups};
}

# Getopt::Long calls this sub for each opt it finds on the
# cmd line. We have to do this in order to know which opts
# were "got" on the cmd line.
sub _set_option {
   my ( $self, $opt, $val ) = @_;
   my $long = exists $self->{opts}->{$opt}       ? $opt
            : exists $self->{short_opts}->{$opt} ? $self->{short_opts}->{$opt}
            : die "Getopt::Long gave a nonexistent option: $opt";

   # Reassign $opt.
   $opt = $self->{opts}->{$long};
   if ( $opt->{is_cumulative} ) {
      $opt->{value}++;
   }
   else {
      $opt->{value} = $val;
   }
   $opt->{got} = 1;
   MKDEBUG && _d('Got option', $long, '=', $val);
}

# Get options on the command line (ARGV) according to the option specs
# and enforce option rules. Option values are saved internally in
# $self->{opts} and accessed later by get(), got() and set().
sub get_opts {
   my ( $self ) = @_; 

   # Reset opts. 
   foreach my $long ( keys %{$self->{opts}} ) {
      $self->{opts}->{$long}->{got} = 0;
      $self->{opts}->{$long}->{value}
         = exists $self->{defaults}->{$long}       ? $self->{defaults}->{$long}
         : $self->{opts}->{$long}->{is_cumulative} ? 0
         : undef;
   }
   $self->{got_opts} = 0;

   # Reset errors.
   $self->{errors} = [];

   # --config is special-case; parse them manually and remove them from @ARGV
   if ( @ARGV && $ARGV[0] eq "--config" ) {
      shift @ARGV;
      $self->_set_option('config', shift @ARGV);
   }
   if ( $self->has('config') ) {
      my @extra_args;
      foreach my $filename ( split(',', $self->get('config')) ) {
         # Try to open the file.  If it was set explicitly, it's an error if it
         # can't be opened, but the built-in defaults are to be ignored if they
         # can't be opened.
         eval {
            push @extra_args, $self->_read_config_file($filename);
         };
         if ( $EVAL_ERROR ) {
            if ( $self->got('config') ) {
               die $EVAL_ERROR;
            }
            elsif ( MKDEBUG ) {
               _d($EVAL_ERROR);
            }
         }
      }
      unshift @ARGV, @extra_args;
   }

   Getopt::Long::Configure('no_ignore_case', 'bundling');
   GetOptions(
      # Make Getopt::Long specs for each option with custom handler subs.
      map    { $_->{spec} => sub { $self->_set_option(@_); } }
      grep   { $_->{long} ne 'config' } # --config is handled specially above.
      values %{$self->{opts}}
   ) or $self->save_error('Error parsing options');

   if ( exists $self->{opts}->{version} && $self->{opts}->{version}->{got} ) {
      printf("%s  Ver %s Distrib %s Changeset %s\n",
         $self->{program_name}, $main::VERSION, $main::DISTRIB, $main::SVN_REV)
            or die "Cannot print: $OS_ERROR";
      exit 0;
   }

   if ( @ARGV && $self->{strict} ) {
      $self->save_error("Unrecognized command-line options @ARGV");
   }

   # Check mutex options.
   foreach my $mutex ( @{$self->{mutex}} ) {
      my @set = grep { $self->{opts}->{$_}->{got} } @$mutex;
      if ( @set > 1 ) {
         my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
                      @{$mutex}[ 0 .. scalar(@$mutex) - 2] )
                 . ' and --'.$self->{opts}->{$mutex->[-1]}->{long}
                 . ' are mutually exclusive.';
         $self->save_error($err);
      }
   }

   foreach my $required ( @{$self->{atleast1}} ) {
      my @set = grep { $self->{opts}->{$_}->{got} } @$required;
      if ( @set == 0 ) {
         my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
                      @{$required}[ 0 .. scalar(@$required) - 2] )
                 .' or --'.$self->{opts}->{$required->[-1]}->{long};
         $self->save_error("Specify at least one of $err");
      }
   }

   foreach my $long ( keys %{$self->{opts}} ) {
      my $opt = $self->{opts}->{$long};
      if ( $opt->{got} ) {
         # Rule: opt disables other opts.
         if ( exists $self->{disables}->{$long} ) {
            my @disable_opts = @{$self->{disables}->{$long}};
            map { $self->{opts}->{$_}->{value} = undef; } @disable_opts;
            MKDEBUG && _d('Unset options', @disable_opts,
               'because', $long,'disables them');
         }

         # Group restrictions.
         if ( exists $self->{allowed_groups}->{$long} ) {
            # This option is only allowed with other options from
            # certain groups.  Check that no options from restricted
            # groups were gotten.

            my @restricted_groups = grep {
               !exists $self->{allowed_groups}->{$long}->{$_}
            } keys %{$self->{groups}};

            my @restricted_opts;
            foreach my $restricted_group ( @restricted_groups ) {
               RESTRICTED_OPT:
               foreach my $restricted_opt (
                  keys %{$self->{groups}->{$restricted_group}} )
               {
                  next RESTRICTED_OPT if $restricted_opt eq $long;
                  push @restricted_opts, $restricted_opt
                     if $self->{opts}->{$restricted_opt}->{got};
               }
            }

            if ( @restricted_opts ) {
               my $err;
               if ( @restricted_opts == 1 ) {
                  $err = "--$restricted_opts[0]";
               }
               else {
                  $err = join(', ',
                            map { "--$self->{opts}->{$_}->{long}" }
                            grep { $_ } 
                            @restricted_opts[0..scalar(@restricted_opts) - 2]
                         )
                       . ' or --'.$self->{opts}->{$restricted_opts[-1]}->{long};
               }
               $self->save_error("--$long is not allowed with $err");
            }
         }

      }
      elsif ( $opt->{is_required} ) { 
         $self->save_error("Required option --$long must be specified");
      }

      $self->_validate_type($opt);
   }

   $self->{got_opts} = 1;
   return;
}

sub _validate_type {
   my ( $self, $opt ) = @_;
   return unless $opt && $opt->{type};
   my $val = $opt->{value};

   if ( $val && $opt->{type} eq 'm' ) {  # type time
      MKDEBUG && _d('Parsing option', $opt->{long}, 'as a time value');
      my ( $num, $suffix ) = $val =~ m/(\d+)([a-z])?$/;
      # The suffix defaults to 's' unless otherwise specified.
      if ( !$suffix ) {
         my ( $s ) = $opt->{desc} =~ m/\(suffix (.)\)/;
         $suffix = $s || 's';
         MKDEBUG && _d('No suffix given; using', $suffix, 'for',
            $opt->{long}, '(value:', $val, ')');
      }
      if ( $suffix =~ m/[smhd]/ ) {
         $val = $suffix eq 's' ? $num            # Seconds
              : $suffix eq 'm' ? $num * 60       # Minutes
              : $suffix eq 'h' ? $num * 3600     # Hours
              :                  $num * 86400;   # Days
         $opt->{value} = $val;
         MKDEBUG && _d('Setting option', $opt->{long}, 'to', $val);
      }
      else {
         $self->save_error("Invalid time suffix for --$opt->{long}");
      }
   }
   elsif ( $val && $opt->{type} eq 'd' ) {  # type DSN
      MKDEBUG && _d('Parsing option', $opt->{long}, 'as a DSN');
      # DSN vals for this opt may come from 3 places, in order of precedence:
      # the opt itself, the defaults to/copies from opt (prev), or
      # --host, --port, etc. (defaults).
      my $prev = {};
      my $from_key = $self->{defaults_to}->{ $opt->{long} };
      if ( $from_key ) {
         MKDEBUG && _d($opt->{long}, 'DSN copies from', $from_key, 'DSN');
         $prev = $self->{opts}->{$from_key}->{value};
      }
      my $defaults = $self->{dp}->parse_options($self);
      $opt->{value} = $self->{dp}->parse($val, $prev, $defaults);
   }
   elsif ( $val && $opt->{type} eq 'z' ) {  # type size
      MKDEBUG && _d('Parsing option', $opt->{long}, 'as a size value');
      my %factor_for = (k => 1_024, M => 1_048_576, G => 1_073_741_824);
      my ($pre, $num, $factor) = $val =~ m/^([+-])?(\d+)([kMG])?$/;
      if ( defined $num ) {
         if ( $factor ) {
            $num *= $factor_for{$factor};
            MKDEBUG && _d('Setting option', $opt->{y},
               'to num', $num, '* factor', $factor);
         }
         $opt->{value} = ($pre || '') . $num;
      }
      else {
         $self->save_error("Invalid size for --$opt->{long}");
      }
   }
   elsif ( $opt->{type} eq 'H' || (defined $val && $opt->{type} eq 'h') ) {
      $opt->{value} = { map { $_ => 1 } split(',', ($val || '')) };
   }
   elsif ( $opt->{type} eq 'A' || (defined $val && $opt->{type} eq 'a') ) {
      $opt->{value} = [ split(/(?<!\\),/, ($val || '')) ];
   }
   else {
      MKDEBUG && _d('Nothing to validate for option',
         $opt->{long}, 'type', $opt->{type}, 'value', $val);
   }

   return;
}

# Get an option's value. The option can be either a
# short or long name (e.g. -A or --charset).
sub get {
   my ( $self, $opt ) = @_;
   my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
   die "Option $opt does not exist"
      unless $long && exists $self->{opts}->{$long};
   return $self->{opts}->{$long}->{value};
}

# Returns true if the option was given explicitly on the
# command line; returns false if not. The option can be
# either short or long name (e.g. -A or --charset).
sub got {
   my ( $self, $opt ) = @_;
   my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
   die "Option $opt does not exist"
      unless $long && exists $self->{opts}->{$long};
   return $self->{opts}->{$long}->{got};
}

# Returns true if the option exists.
sub has {
   my ( $self, $opt ) = @_;
   my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
   return defined $long ? exists $self->{opts}->{$long} : 0;
}

# Set an option's value. The option can be either a
# short or long name (e.g. -A or --charset). The value
# can be any scalar, ref, or undef. No type checking
# is done so becareful to not set, for example, an integer
# option with a DSN.
sub set {
   my ( $self, $opt, $val ) = @_;
   my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
   die "Option $opt does not exist"
      unless $long && exists $self->{opts}->{$long};
   $self->{opts}->{$long}->{value} = $val;
   return;
}

# Save an error message to be reported later by calling usage_or_errors()
# (or errors()--mostly for testing).
sub save_error {
   my ( $self, $error ) = @_;
   push @{$self->{errors}}, $error;
}

# Return arrayref of errors (mostly for testing).
sub errors {
   my ( $self ) = @_;
   return $self->{errors};
}

sub prompt {
   my ( $self ) = @_;
   return "Usage: $PROGRAM_NAME $self->{prompt}\n";
}

sub descr {
   my ( $self ) = @_;
   my $descr  = $self->{program_name} . ' ' . ($self->{description} || '')
              . "  For more details, please use the --help option, "
              . "or try 'perldoc $PROGRAM_NAME' "
              . "for complete documentation.";
   $descr = join("\n", $descr =~ m/(.{0,80})(?:\s+|$)/g);
   $descr =~ s/ +$//mg;
   return $descr;
}

sub usage_or_errors {
   my ( $self ) = @_;
   if ( $self->{opts}->{help}->{got} ) {
      print $self->print_usage() or die "Cannot print usage: $OS_ERROR";
      exit 0;
   }
   elsif ( scalar @{$self->{errors}} ) {
      print $self->print_errors() or die "Cannot print errors: $OS_ERROR";
      exit 0;
   }
   return;
}

# Explains what errors were found while processing command-line arguments and
# gives a brief overview so you can get more information.
sub print_errors {
   my ( $self ) = @_;
   my $usage = $self->prompt() . "\n";
   if ( (my @errors = @{$self->{errors}}) ) {
      $usage .= join("\n  * ", 'Errors in command-line arguments:', @errors)
              . "\n";
   }
   return $usage . "\n" . $self->descr();
}

# Prints out command-line help.  The format is like this:
# --foo  -F   Description of --foo
# --bars -B   Description of --bar
# --longopt   Description of --longopt
# Note that the short options are aligned along the right edge of their longest
# long option, but long options that don't have a short option are allowed to
# protrude past that.
sub print_usage {
   my ( $self ) = @_;
   die "Run get_opts() before print_usage()" unless $self->{got_opts};
   my @opts = values %{$self->{opts}};

   # Find how wide the widest long option is.
   my $maxl = max(
      map { length($_->{long}) + ($_->{is_negatable} ? 4 : 0) }
      @opts);

   # Find how wide the widest option with a short option is.
   my $maxs = max(0,
      map { length($_) + ($self->{opts}->{$_}->{is_negatable} ? 4 : 0) }
      values %{$self->{short_opts}});

   # Find how wide the 'left column' (long + short opts) is, and therefore how
   # much space to give options and how much to give descriptions.
   my $lcol = max($maxl, ($maxs + 3));
   my $rcol = 80 - $lcol - 6;
   my $rpad = ' ' x ( 80 - $rcol );

   # Adjust the width of the options that have long and short both.
   $maxs = max($lcol - 3, $maxs);

   # Format and return the options.
   my $usage = $self->descr() . "\n" . $self->prompt();

   # Sort groups alphabetically but make 'default' first.
   my @groups = reverse sort grep { $_ ne 'default'; } keys %{$self->{groups}};
   push @groups, 'default';

   foreach my $group ( reverse @groups ) {
      $usage .= "\n".($group eq 'default' ? 'Options' : $group).":\n\n";
      foreach my $opt (
         sort { $a->{long} cmp $b->{long} }
         grep { $_->{group} eq $group }
         @opts )
      {
         my $long  = $opt->{is_negatable} ? "[no]$opt->{long}" : $opt->{long};
         my $short = $opt->{short};
         my $desc  = $opt->{desc};
         # Expand suffix help for time options.
         if ( $opt->{type} && $opt->{type} eq 'm' ) {
            my ($s) = $desc =~ m/\(suffix (.)\)/;
            $s    ||= 's';
            $desc =~ s/\s+\(suffix .\)//;
            $desc .= ".  Optional suffix s=seconds, m=minutes, h=hours, "
                   . "d=days; if no suffix, $s is used.";
         }
         # Wrap long descriptions
         $desc = join("\n$rpad", grep { $_ } $desc =~ m/(.{0,$rcol})(?:\s+|$)/g);
         $desc =~ s/ +$//mg;
         if ( $short ) {
            $usage .= sprintf("  --%-${maxs}s -%s  %s\n", $long, $short, $desc);
         }
         else {
            $usage .= sprintf("  --%-${lcol}s  %s\n", $long, $desc);
         }
      }
   }

   if ( (my @rules = @{$self->{rules}}) ) {
      $usage .= "\nRules:\n\n";
      $usage .= join("\n", map { "  $_" } @rules) . "\n";
   }
   if ( $self->{dp} ) {
      $usage .= "\n" . $self->{dp}->usage();
   }
   $usage .= "\nOptions and values after processing arguments:\n\n";
   foreach my $opt ( sort { $a->{long} cmp $b->{long} } @opts ) {
      my $val   = $opt->{value};
      my $type  = $opt->{type} || '';
      my $bool  = $opt->{spec} =~ m/^[\w-]+(?:\|[\w-])?!?$/;
      $val      = $bool                     ? ( $val ? 'TRUE' : 'FALSE' )
                : !defined $val             ? '(No value)'
                : $type eq 'd'              ? $self->{dp}->as_string($val)
                : $type =~ m/H|h/           ? join(',', sort keys %$val)
                : $type =~ m/A|a/           ? join(',', @$val)
                :                             $val;
      $usage .= sprintf("  --%-${lcol}s  %s\n", $opt->{long}, $val);
   }
   return $usage;
}

# Tries to prompt and read the answer without echoing the answer to the
# terminal.  This isn't really related to this package, but it's too handy not
# to put here.  OK, it's related, it gets config information from the user.
sub prompt_noecho {
   shift @_ if ref $_[0] eq __PACKAGE__;
   my ( $prompt ) = @_;
   local $OUTPUT_AUTOFLUSH = 1;
   print $prompt
      or die "Cannot print: $OS_ERROR";
   my $response;
   eval {
      require Term::ReadKey;
      Term::ReadKey::ReadMode('noecho');
      chomp($response = <STDIN>);
      Term::ReadKey::ReadMode('normal');
      print "\n"
         or die "Cannot print: $OS_ERROR";
   };
   if ( $EVAL_ERROR ) {
      die "Cannot read response; is Term::ReadKey installed? $EVAL_ERROR";
   }
   return $response;
}

# This is debug code I want to run for all tools, and this is a module I
# certainly include in all tools, but otherwise there's no real reason to put
# it here.
if ( MKDEBUG ) {
   print '# ', $^X, ' ', $], "\n";
   my $uname = `uname -a`;
   if ( $uname ) {
      $uname =~ s/\s+/ /g;
      print "# $uname\n";
   }
   printf("# %s  Ver %s Distrib %s Changeset %s line %d\n",
      $PROGRAM_NAME, ($main::VERSION || ''), ($main::DISTRIB || ''),
      ($main::SVN_REV || ''), __LINE__);
   print('# Arguments: ',
      join(' ', map { my $a = "_[$_]_"; $a =~ s/\n/\n# /g; $a; } @ARGV), "\n");
}

# Reads a configuration file and returns it as a list.  Inspired by
# Config::Tiny.
sub _read_config_file {
   my ( $self, $filename ) = @_;
   open my $fh, "<", $filename or die "Cannot open $filename: $OS_ERROR\n";
   my @args;
   my $prefix = '--';
   my $parse  = 1;

   LINE:
   while ( my $line = <$fh> ) {
      chomp $line;
      # Skip comments and empty lines
      next LINE if $line =~ m/^\s*(?:\#|\;|$)/;
      # Remove inline comments
      $line =~ s/\s+#.*$//g;
      # Remove whitespace
      $line =~ s/^\s+|\s+$//g;
      # Watch for the beginning of the literal values (not to be interpreted as
      # options)
      if ( $line eq '--' ) {
         $prefix = '';
         $parse  = 0;
         next LINE;
      }
      if ( $parse
         && (my($opt, $arg) = $line =~ m/^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/)
      ) {
         push @args, grep { defined $_ } ("$prefix$opt", $arg);
      }
      elsif ( $line =~ m/./ ) {
         push @args, $line;
      }
      else {
         die "Syntax error in file $filename at line $INPUT_LINE_NUMBER";
      }
   }
   close $fh;
   return @args;
}

# Reads the next paragraph from the POD after the magical regular expression is
# found in the text.
sub read_para_after {
   my ( $self, $file, $regex ) = @_;
   open my $fh, "<", $file or die "Can't open $file: $OS_ERROR";
   local $INPUT_RECORD_SEPARATOR = '';
   my $para;
   while ( $para = <$fh> ) {
      next unless $para =~ m/^=pod$/m;
      last;
   }
   while ( $para = <$fh> ) {
      next unless $para =~ m/$regex/;
      last;
   }
   $para = <$fh>;
   chomp($para);
   close $fh or die "Can't close $file: $OS_ERROR";
   return $para;
}

# Returns a lightweight clone of ourself.  Currently, only the basic
# opts are copied.  This is used for stuff like "final opts" in
# mk-table-checksum.
sub clone {
   my ( $self ) = @_;

   # Deep-copy contents of hashrefs; do not just copy the refs. 
   my %clone = map {
      my $hashref  = $self->{$_};
      my $val_copy = {};
      foreach my $key ( keys %$hashref ) {
         my $ref = ref $hashref->{$key};
         $val_copy->{$key} = !$ref           ? $hashref->{$key}
                           : $ref eq 'HASH'  ? { %{$hashref->{$key}} }
                           : $ref eq 'ARRAY' ? [ @{$hashref->{$key}} ]
                           : $hashref->{$key};
      }
      $_ => $val_copy;
   } qw(opts short_opts defaults);

   # Re-assign scalar values.
   foreach my $scalar ( qw(got_opts) ) {
      $clone{$scalar} = $self->{$scalar};
   }

   return bless \%clone;     
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
# End OptionParser package
# ###########################################################################
