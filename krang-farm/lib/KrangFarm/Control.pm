package KrangFarm::Control;
use strict;
use warnings;

=head1 NAME

KrangFarm::Control - control a machine on the farm

=head1 SYNOPSIS

  KrangFarm::Control->start(machine => $machine);
  KrangFarm::Control->stop(machine => $machine);

=head1 DESCRIPTION

This module offers start() and stop(), routines to start and stop
machines on the farm.  The machine parameter takes machine
descriptions from KrangFarm::Conf->machines().

=head1 INTERFACE

=over

=item KrangFarm::Control->start(machine => $machine, log => $log)

Starts the VM associated with $machine, printing debug info on $log or
STDERR if not provided.  Croaks on errors.

=item KrangFarm::Control->stop(machine => $machine, log => $log)

Starts the VM associated with $machine, printing debug info on $log or
STDERR if not provided.  Croaks on errors.

=item KrangFarm::Control->send_file(machine => $machine, log => $log, file => $file)

Transfer a file to the machine.  The file will be in the home
directory of the user configured in F<farm.conf>.

=item KrangFarm::Control->fetch_file(machine => $machine, log => $log, file => $file)

Transfer a file from the machine to the current directory.  The file
path is relative to the home directory of the user configured in
F<farm.conf>.

=item $command = KrangFarm::Control->spawn(machine => $machine, log => $log, command => $command)

Spawns a command in the machine and returns an Expect object for the
connection.

=item KrangFarm::Control->run(machine => $machine, log => $log, command => $command)

Runs a command in the machine and waits for it to finish before
returning.

=back

=cut

use VMware::VmPerl qw(VM_EXECUTION_STATE_OFF
                      VM_EXECUTION_STATE_ON
                      VM_POWEROP_MODE_HARD
                     );
use VMware::VmPerl::Server;
use VMware::VmPerl::ConnectParams;
use VMware::VmPerl::VM;
use Carp qw(croak);
use Net::Ping;
use Time::HiRes qw(time sleep);
use Expect;

# how long to wait for VMWare to do stuff, in seconds
our $MAX_WAIT = 60 * 5;

# make a connection to VMWare
our $PORT = 902;
our $CONNECT_PARAMS = 
  VMware::VmPerl::ConnectParams::new(undef,$PORT,undef,undef);
our $SERVER = VMware::VmPerl::Server::new();
if (!$SERVER->connect($CONNECT_PARAMS)) {
    my ($error_number, $error_string) = $SERVER->get_last_error();
    die "Could not connect to server: Error $error_number: $error_string";
}
our @VM_LIST = $SERVER->registered_vm_names();
unless (defined($VM_LIST[0])) {
   my ($error_number, $error_string) = $SERVER->get_last_error();
   die "Could not get list of VMs from server: Error $error_number: ".
       "$error_string\n";
}

sub start {
    my ($pkg, %args) = @_;
    my $machine = $args{machine} or croak("Missing machine param.");
    my $cfg = _machine2cfg($machine);
    my $log = $args{log} || \*STDERR;

    # connect to this vm
    my $vm = VMware::VmPerl::VM::new();
    unless ($vm->connect($CONNECT_PARAMS, $cfg)) {
        my ($error_number, $error_string) = $vm->get_last_error();
        croak("Could not connect to vm: Error $error_number: $error_string");
    }
    
    # make sure it's not running
    my $state = $vm->get_execution_state();
    die "Machine '$machine->{name}' is not stopped.  Aborting start().\n"
      unless ($state == VM_EXECUTION_STATE_OFF);

    # start it up
    print $log localtime() . " : Starting machine...\n";
    $vm->start(VM_POWEROP_MODE_HARD);

    # wait till machine is on the net
    my $start = time;
    my $ping = Net::Ping->new();
    my $alive = 0;
    while(time - $start < $MAX_WAIT) {
        if ($ping->ping($machine->{name})) {
            $alive = 1;
            last;
        }
        sleep 0.5;
    }
    die "Timed out waiting for machine to start.\n"
      unless $alive;

    # wait a little longer for sshd to come up
    sleep 15;

    print $log localtime() . " : Machine started.\n";
}

sub send_file {
    my ($pkg, %args) = @_;
    my $machine = $args{machine} or croak("Missing machine param.");
    my $log = $args{log} || \*STDERR;
    my $file = $args{file};
    croak "File '$file' does not exist." unless -e $file;
    
    print $log localtime() . " : sending $file to machine.\n";

    # open up an scp command, logging to $log
    my $command = Expect->spawn("scp $file $machine->{user}\@$machine->{name}: 2>&1");
    $command->log_stdout(0);
    $command->log_file(sub { _log_expect($log, @_) });
    croak("Unable to spawn scp.") unless $command;

    # answer the password prompt and all should be well
    if ($command->expect(undef, 'password:')) {
        $command->send($machine->{password} . "\n");
    }
    # wait for EOF
    $command->expect(undef);
    $command->soft_close();
    croak "Failed to send file." if $command->exitstatus() != 0;

    # make sure the file has the right size by comparing results of
    # 'ls -s' on both host and target
    my ($f) = $file =~ m!([^/]+)$!;
    my ($size) = `ls -s $file` =~ /(\d+)/;
    $command = $pkg->spawn(%args, command => "ls -s $f");
    if (not($command->expect(5, '-re', "\\d+\\s+$f")) or
        $command->match !~ /${size}\s+$f/) {
        croak("Failed to send file, size of '$f' does not match '$size'.");
    }
    $command->soft_close();

    print $log localtime() . " : File sent successfully.\n";
}

sub fetch_file {
    my ($pkg, %args) = @_;
    my $machine = $args{machine} or croak("Missing machine param.");
    my $log = $args{log} || \*STDERR;
    my $file = $args{file};
    
    print $log localtime() . " : sending $file to machine.\n";

    # open up an scp command, logging to $log
    my $command = Expect->spawn("scp $machine->{user}\@$machine->{name}:$file . 2>&1");
    $command->log_stdout(0);
    $command->log_file(sub { _log_expect($log, @_) });
    croak("Unable to spawn scp.") unless $command;

    # answer the password prompt and all should be well
    if ($command->expect(5, 'password:')) {
        $command->send($machine->{password} . "\n");
    }
    # wait for EOF
    $command->expect(undef);
    $command->soft_close();
    croak "Failed to send file." if $command->exitstatus() != 0;

    # make sure the file has the right size by comparing results of
    # 'ls -s' on both host and target
    my ($f) = $file =~ m!([^/]+)$!;
    my ($size) = `ls -s $f` =~ /(\d+)/;
    $command = $pkg->spawn(%args, command => "ls -s $file");
    if (not($command->expect(5, '-re', "\\d+\\s+$file")) or
        $command->match !~ /${size}\s+$file/) {
        croak("Failed to fetch file, size of '$file' does not match '$size'.");
    }
    $command->soft_close();

    print $log localtime() . " : File fetched successfully.\n";
}

sub spawn {
    my ($pkg, %args) = @_;
    my $machine = $args{machine} or croak("Missing machine param.");
    my $log = $args{log} || \*STDERR;
    my $command = $args{command};

    print $log localtime() . " : Spawning command '$command'.\n";

    my $spawn = Expect->spawn("ssh $machine->{user}\@$machine->{name} $command");
    $spawn->log_stdout(0);
    $spawn->log_file(sub { _log_expect($log, @_) } );
    croak("Unable to spawn '$command'.") unless $spawn;
    if ($spawn->expect(5, 'password:')) {
        $spawn->send($machine->{password} . "\n");
    }
    return $spawn;
}

sub run {
    my ($pkg, %args) = @_;
    my $machine = $args{machine} or croak("Missing machine param.");
    my $log = $args{log} || \*STDERR;

    # spawn the command
    my $command = $pkg->spawn(%args);

    # wait for EOF
    $command->expect(undef);
    $command->soft_close();
    croak "Failed to run '$args{command}'." if $command->exitstatus() != 0;
}

sub stop {
    my ($pkg, %args) = @_;
    my $machine = $args{machine} or croak("Missing machine param.");
    my $cfg = _machine2cfg($machine);
    my $log = $args{log} || \*STDERR;

    # connect to this vm
    my $vm = VMware::VmPerl::VM::new();
    unless ($vm->connect($CONNECT_PARAMS, $cfg)) {
        my ($error_number, $error_string) = $vm->get_last_error();
        croak("Could not connect to vm: Error $error_number: $error_string");
    }

    # make sure it is running
    my $state = $vm->get_execution_state();
    die "Machine '$machine->{name}' is not running.  Aborting stop().\n"
      unless ($state == VM_EXECUTION_STATE_ON);

    # stop it
    print $log localtime() . " : Stopping machine...\n";
    $vm->stop(VM_POWEROP_MODE_HARD);

    # wait for it to go off the net
    my $start = time;
    my $ping = Net::Ping->new();
    my $alive = 1;
    while(time - $start < $MAX_WAIT) {
        if (not $ping->ping($machine->{name})) {
            $alive = 0;
            last;
        }
    }
    die "Timed out waiting for machine to stop.\n"
      if $alive;   

    print $log localtime() . " : Machine stopped.\n";
}

# gets the vmware config name for a machine
sub _machine2cfg {
    my $machine = shift;
    my $name = $machine->{name};
    foreach my $cfg (@VM_LIST) {
        if ($cfg =~ m!/$name\.vmx$!) {
            return $cfg;
        }
    }
    croak("Machine '$machine->{name}' not found in VMWare machine list: " . 
          join(', ', @VM_LIST));
}

# logs expect output to log files
sub _log_expect {
    my ($log, @text) = @_;
    print $log @text;
}
1;
