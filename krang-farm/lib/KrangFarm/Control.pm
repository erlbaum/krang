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

Transfer a file from the machine to the current directory.  If the
file path is relative it is relative to the home directory of the user
configured in F<farm.conf>.

=item $command = KrangFarm::Control->spawn(machine => $machine, log => $log, command => $command)

Spawns a command in the machine and returns an Expect object for the
connection.

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

    # wait till it's pingable or until max-wait has expired
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

    print $log localtime() . " : Machine started.\n";
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


1;
