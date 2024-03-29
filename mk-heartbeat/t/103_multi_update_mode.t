#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Time::HiRes qw(sleep);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-heartbeat/mk-heartbeat";

diag(`$trunk/sandbox/mk-test-env reset`);  # don't repl sakila db to 12347
diag(`$trunk/sandbox/stop-sandbox remove 12347 >/dev/null`);
diag(`$trunk/sandbox/start-sandbox slave 12347 12346 >/dev/null`);

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave1_dbh = $sb->get_dbh_for('slave1');
my $slave2_dbh = $sb->get_dbh_for('slave2');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave1_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave1';
}
elsif ( !$slave2_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave2';
}
else {
   plan tests => 28;
}

$sb->create_dbs($master_dbh, ['test']);

my $output;
my $pid_file = "/tmp/__mk-heartbeat-test.pid";

# Multi-update mode is the new, hi-res mode that allows a single table to
# be updated by multiple servers: a slave's master, its master's master, etc.
#
# We have master -> slave1 -> slave2 where master has server_id=12345,
# slave1 server_id=12346, and slave2 server_id=12347.  The  heartbeat table
# on slave2 can have 3 heartbeat rows: one from the master, one from slave1
# and one for itself.
my @ports = qw(12345 12346 12347);

foreach my $port (@ports) {
   system("$trunk/mk-heartbeat/mk-heartbeat -h 127.1 -u msandbox -p msandbox -P $port --database test --table heartbeat --create-table --update --interval 0.5 --daemonize --pid $pid_file.$port >/dev/null");

   sleep 0.2;

   ok(
      -f "$pid_file.$port",
      "--update on $port started"
   );
}

# Check heartbeat on master.
my $rows = $master_dbh->selectall_hashref("select * from test.heartbeat", 'server_id');

is(
   scalar keys %$rows,
   1,
   "One heartbeat row on master"
);

ok(
   exists $rows->{12345},
   "Master heartbeat"
);

ok(
   defined $rows->{12345}->{file} && defined $rows->{12345}->{position},
   "Master file and position"
);

ok(
   !$rows->{12345}->{relay_master_log_file} && !$rows->{12345}->{exec_master_log_pos},
   "No relay_master_log_file or exec_master_log_pos for master"
);

# Check heartbeat on slave1.
$rows = $slave1_dbh->selectall_hashref("select * from test.heartbeat", 'server_id');

is(
   scalar keys %$rows,
   2,
   "Two heartbeat rows on slave1"
);

ok(
   exists $rows->{12345},
   "Slave1 has master heartbeat",
);

ok(
   exists $rows->{12346},
   "Slave1 heartbeat"
);

ok(
   defined $rows->{12346}->{file} && defined $rows->{12346}->{position},
   "Slave1 master file and position"
);

ok(
   $rows->{12346}->{relay_master_log_file} && $rows->{12346}->{exec_master_log_pos},
   "Slave1 relay_master_log_file and exec_master_log_pos for master"
);

# Check heartbeat on slave2.
$rows = $slave2_dbh->selectall_hashref("select * from test.heartbeat", 'server_id');

is(
   scalar keys %$rows,
   3,
   "Three heartbeat rows on slave2"
);

ok(
   exists $rows->{12345},
   "Slave2 has master heartbeat",
);

ok(
   exists $rows->{12346},
   "Slave2 has slave1 heartbeat",
);

ok(
   exists $rows->{12347},
   "Slave1 heartbeat"
);

ok(
   defined $rows->{12347}->{file} && defined $rows->{12347}->{position},
   "Slave2 master file and position"
);

ok(
   $rows->{12347}->{relay_master_log_file} && $rows->{12347}->{exec_master_log_pos},
   "Slave2 relay_master_log_file and exec_master_log_pos for master"
);

# ############################################################################
# Verify that the master heartbeat is changing and replicating.
# ############################################################################

# $rows already has slave2 heartbeat info.
sleep 1.0;

my $rows2 = $slave2_dbh->selectall_hashref("select * from test.heartbeat", 'server_id');

cmp_ok(
   $rows2->{12345}->{ts},
   'gt',
   $rows->{12345}->{ts},
   "Master heartbeat ts is changing and replicating"
);

cmp_ok(
   $rows2->{12345}->{position},
   '>',
   $rows->{12345}->{position},
   "Master binlog position is changing and replicating"
);

# But the master binlog file shouldn't change.
is(
   $rows->{12345}->{file},
   $rows2->{12345}->{file},
   "Master binlog file is not changing"
);


# ############################################################################
# Test --master-server-id.
# ############################################################################

# First, the option should be optional.  If not given, the server's
# immediate master should be used.
$output = output(
   sub { mk_heartbeat::main(qw(-h 127.1 -P 12347 -u msandbox -p msandbox),
      qw(-D test --check --print-master-server-id)) },
);

like(
   $output,
   qr/0\.\d\d\s+12346\n/,
   "--check 12347, automatic master server_id"
);

$output = output(
   sub { mk_heartbeat::main(qw(-h 127.1 -P 12347 -u msandbox -p msandbox),
      qw(-D test --check --print-master-server-id --master-server-id 12346)) },
);

like(
   $output,
   qr/0\.\d\d\s+12346\n/,
   "--check 12347 from --master-server-id 12346"
);

$output = output(
   sub { mk_heartbeat::main(qw(-h 127.1 -P 12347 -u msandbox -p msandbox),
      qw(-D test --check --print-master-server-id --master-server-id 12345)) },
);

like(
   $output,
   qr/0\.\d\d\s+12345\n/,
   "--check 12347 from --master-server-id 12345"
);

$output = output(
   sub { mk_heartbeat::main(qw(-h 127.1 -P 12347 -u msandbox -p msandbox),
      qw(-D test --check --print-master-server-id --master-server-id 42),
      qw(--no-insert-heartbeat-row)) },
);

like(
   $output,
   qr/No row found in heartbeat table for server_id 42/,
   "Error if --master-server-id row doesn't exist"
);

# ############################################################################
# Stop our --update instances.
# ############################################################################
diag(`$trunk/mk-heartbeat/mk-heartbeat --stop >/dev/null`);
sleep 1;

foreach my $port (@ports) {
   ok(
      !-f "$pid_file.$port",
      "--update on $port stopped"
   );
}

diag(`rm -rf /tmp/mk-heartbeat-sentinel >/dev/null`);
diag(`$trunk/sandbox/stop-sandbox remove 12347 >/dev/null`);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
exit;
