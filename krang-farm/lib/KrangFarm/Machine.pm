package KrangFarm::Machine;
use strict;
use warnings;

=head1 NAME

KrangFarm::Machine - interface to machines in the farm

=head1 SYNOPSIS

  # get a list of all configured machine names
  my @machine_names = KrangFarm::Machine->list();

  # load one machine by name, passing a log-file where interaction
  # will be logged
  my $machine = KrangFarm::Machine->new(name => "Redhat9",
                                        log  => "logs/test.Redhat9.log");

  # get info about the machine
  my $name  = $machine->name;
  my $desc  = $machine->description;
  my $user  = $machine->user;
  my $pass  = $machine->password;
  my $perls = $machine->perls;

  # boot and shutdown
  $machine->start();
  $machine->stop();
  
  # file transfer
  $machine->send_file(file => $file);
  $machine->fetch_file(file => $file);

  # processs control
  $machine->run(command => "tar zxf $file");
  my $expect = $machine->spawn(command => "make");

  # write a message to the machine's log file
  $machine->log("Hello log.");

=head1 DESCRIPTION

This module provides an interface to Krang Farm machines.  All methods
croak() on failure.

=head1 INTERFACE

=item KrangFarm::Machines->list()

Returns a list of all machines defined in F<farm.conf>.

=item KrangFarm::Machines->new(name => $name, log => $log)

Creates a new machine.  C<name> must be defined in F<farm.conf>.  The
C<log> parameter provides a filename to write a trace of all
operations.

=item C<< $machine->start() >>

Starts the VM associated with the machine.

=item C<< $machine->stop() >>

Stops the VM associated with the machine.

=item C<< $machine->send_file(file => $file) >>

Transfer a file to the machine.  The file will be in the home
directory of the user configured in F<farm.conf> for this machine.

=item C<< $machine->fetch_file(file => $file) >>

Transfer a file from the machine to the current directory.  The file
path is relative to the home directory of the user configured in
F<farm.conf> for this machine.

=item C<< $command = $machine->spawn(command => $command) >>

Spawns a command in the machine and returns an Expect object for the
connection.

=item C<< $machine->run(command => $command) >>

Runs a command in the machine and waits for it to finish before
returning.

=item C<< $machine->log("Message") >>

Writes a message to the log-file named in the call to new().  Adds a
timestamp and a trailing newline unless one is already present.

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
use KrangFarm::Conf;

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

# load the configuration data
our %MACHINES = map { ($_->{name}, $_) } KrangFarm::Conf->machines();

sub list {
    return sort keys %MACHINES;
}

sub new {
    my ($pkg, %args) = @_;
    croak("Missing required 'name' parameter.") unless exists $args{name};
    croak("Missing required 'log' parameter.")  unless exists $args{log};
    croak("Can't find a machine named '$args{name}' in farm.conf.")
      unless exists $MACHINES{$args{name}};
    
    my $self = bless { %{$MACHINES{$args{name}}} }, $pkg;

    # open the log file and unbuffer it
    open(my $log, '>>', $args{log}) 
      or croak("Unable to open '$args{log}': $!");
    my $old = select($log);
    $|++;
    select($old);
    $self->{log} = $log;

    return $self;
}

sub start {
    my $self = shift;
    my $cfg = $self->_cfg();

    # connect to this vm
    my $vm = VMware::VmPerl::VM::new();
    unless ($vm->connect($CONNECT_PARAMS, $cfg)) {
        my ($error_number, $error_string) = $vm->get_last_error();
        croak("Could not connect to vm: Error $error_number: $error_string");
    }
    
    # make sure it's not running
    my $state = $vm->get_execution_state();
    die "Machine '$self->{name}' is not stopped.  Aborting start().\n"
      unless ($state == VM_EXECUTION_STATE_OFF);

    # start it up
    $self->log("Starting machine...");
    $vm->start(VM_POWEROP_MODE_HARD);

    # wait till machine is on the net
    my $start = time;
    my $ping = Net::Ping->new();
    my $alive = 0;
    while(time - $start < $MAX_WAIT) {
        if ($ping->ping($self->{name})) {
            $alive = 1;
            last;
        }
        sleep 0.5;
    }
    die "Timed out waiting for machine to start.\n"
      unless $alive;

    # wait a little longer for sshd to come up
    sleep 15;

    $self->log(" : Machine started.");
}

sub send_file {
    my ($self, %args) = @_;
    my $file = $args{file};
    croak "File '$file' does not exist." unless -e $file;
    
    $self->log(" : sending $file to machine.");
    
    # open up an scp command, logging to $log
    my $command = Expect->spawn("scp $file $self->{user}\@$self->{name}: 2>&1");
    $command->log_stdout(0);
    $command->log_file(sub { $self->_log_expect(@_) });
    croak("Unable to spawn scp.") unless $command;

    # answer the password prompt and all should be well
    if ($command->expect(undef, 'password:')) {
        $command->send($self->{password} . "\n");
    }
    # wait for EOF
    $command->expect(undef);
    $command->soft_close();
    croak "Failed to send file." if $command->exitstatus() != 0;

    # make sure the file has the right size by comparing results of
    # 'ls -s' on both host and target
    my ($f) = $file =~ m!([^/]+)$!;
    my ($size) = `ls -s $file` =~ /(\d+)/;
    $command = $self->spawn(%args, command => "ls -s $f");
    if (not($command->expect(5, '-re', "\\d+\\s+$f")) or
        $command->match !~ /${size}\s+$f/) {
        croak("Failed to send file, size of '$f' does not match '$size'.");
    }
    $command->soft_close();

    $self->log(" : File sent successfully.");
}

sub fetch_file {
    my ($self, %args) = @_;
    my $file = $args{file};
    
    $self->log(" : fetching $file from machine.");

    # open up an scp command, logging to $log
    my $command = Expect->spawn("scp $self->{user}\@$self->{name}:$file . 2>&1");
    $command->log_stdout(0);
    $command->log_file(sub { $self->_log_expect(@_) });
    croak("Unable to spawn scp.") unless $command;

    # answer the password prompt and all should be well
    if ($command->expect(5, 'password:')) {
        $command->send($self->{password} . "\n");
    }
    # wait for EOF
    $command->expect(undef);
    $command->soft_close();
    croak "Failed to send file." if $command->exitstatus() != 0;

    # make sure the file has the right size by comparing results of
    # 'ls -s' on both host and target
    my ($f) = $file =~ m!([^/]+)$!;
    my ($size) = `ls -s $f` =~ /(\d+)/;
    $command = $self->spawn(%args, command => "ls -s $file");
    if (not($command->expect(5, '-re', "\\d+\\s+$file")) or
        $command->match !~ /${size}\s+$file/) {
        croak("Failed to fetch file, size of '$file' does not match '$size'.");
    }
    $command->soft_close();

    $self->log(" : File fetched successfully.");
}

sub spawn {
    my ($self, %args) = @_;
    my $command = $args{command};

    $self->log(" : Spawning command '$command'.");

    my $spawn = Expect->spawn(qq{ssh $self->{user}\@$self->{name} "$command"});
    $spawn->log_stdout(0);
    $spawn->log_file(sub { $self->_log_expect(@_) } );
    croak("Unable to spawn '$command'.") unless $spawn;
    if ($spawn->expect(5, 'password:')) {
        $spawn->send($self->{password} . "\n");
    }
    return $spawn;
}

sub run {
    my ($self, %args) = @_;

    # spawn the command
    my $command = $self->spawn(%args);

    # wait for EOF
    $command->expect(undef);
    $command->soft_close();
    croak "Failed to run '$args{command}'." if $command->exitstatus() != 0;
}

sub stop {
    my $self = shift;
    my $cfg  = $self->_cfg;

    # connect to this vm
    my $vm = VMware::VmPerl::VM::new();
    unless ($vm->connect($CONNECT_PARAMS, $cfg)) {
        my ($error_number, $error_string) = $vm->get_last_error();
        croak("Could not connect to vm: Error $error_number: $error_string");
    }

    # make sure it is running
    my $state = $vm->get_execution_state();
    die "Machine '$self->{name}' is not running.  Aborting stop().\n"
      unless ($state == VM_EXECUTION_STATE_ON);

    # stop it
    $self->log(" : Stopping machine...");
    $vm->stop(VM_POWEROP_MODE_HARD);

    # wait for it to go off the net
    my $start = time;
    my $ping = Net::Ping->new();
    my $alive = 1;
    while(time - $start < $MAX_WAIT) {
        if (not $ping->ping($self->{name})) {
            $alive = 0;
            last;
        }
    }
    die "Timed out waiting for machine to stop.\n"
      if $alive;   

    $self->log(" : Machine stopped.");
}

sub log {
    my ($self, $msg) = @_;
    $msg .= "\n" unless $msg =~ /\n$/;
    my $log = $self->{log};
    print $log localtime() . " : $msg";
}

# hash accessors
BEGIN {
    no strict 'refs';
    for my $x qw(name description perls user password) {
        *{"KrangFarm::Machine::$x"} = sub { $_[0]->{$x} };
    }
}

# gets the vmware config name for a machine
sub _cfg {
    my $self = shift;
    my $name = $self->{name};
    foreach my $cfg (@VM_LIST) {
        if ($cfg =~ m!/$name\.vmx$!) {
            return $cfg;
        }
    }
    croak("Machine '$self->{name}' not found in VMWare machine list: " . 
          join(', ', @VM_LIST));
}

# logs expect output to log files
sub _log_expect {
    my ($self, @text) = @_;
    my $log = $self->{log};
    print $log @text;
}

1;


