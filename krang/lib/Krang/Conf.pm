package Krang::Conf;
use strict;
use warnings;

# all valid configuration directives must be listed here
our @VALID_DIRECTIVES;
BEGIN {
@VALID_DIRECTIVES = map { lc($_) } qw(
KrangRoot
ElementSet
ElementLibrary
DBName
DBPass
DBUser
ApacheUser
ApacheGroup
ApacheAddr
ApachePort
RootVirtualHost
LogFile
LogLevel
LogTimeStamp
TimeStampFormat
VirtualHost
LogWrap
Assertions
);
}

use File::Spec::Functions qw(catfile catdir rel2abs);
use Carp qw(croak);
use Config::ApacheFormat;
use Cwd qw(fastcwd);
use IO::Scalar;

=head1 NAME

Krang::Conf - Krang configuration module

=head1 SYNOPSIS

  # all configuration directives are available as exported subs
  use Krang::Conf qw(KrangRoot Things);
  $root = KrangRoot;
  @thinks = Things;

  # you can also call get() in Krang::Conf directly
  $root = Krang::Conf->get("KrangRoot");

  # or you can access them as methods in the Krang::Conf module
  $root = Krang::Conf->rootdir;

  # the current instance, which affects the values returned, can
  # manipulated with instance():
  Krang::Conf->instance("this_instance");

  # get a list of available instances
  @instances = Krang::Conf->instances();

=head1 DESCRIPTION

This module provides access to the configuration settings in
F<krang.conf>.  The routines provided will return the correct settings
based on the currently active instance, accesible and setable using
C<< Krang::Conf->instance() >>.

If you call get() or an accessor method before setting instance(), 
Krang::Conf will attempt to automagically set the correct instance.
It will do so by looking for an environment variable, KRANG_INSTANCE,
which contains the name of the instance.  If this variable is not set
(or if it is set to a non-valid instance), get() will croak.

Full details on all configuration parameters is available in the
configuration document, which you can find at:

  http://krang-docs/configuration.html

=cut

# package variables
our $CONF;
our $INSTANCE;
our $INSTANCE_CONF;

# load the configuration file during startup
BEGIN {
    # find a default conf file
    my $conf_file;
    if (exists $ENV{KRANG_CONF}) {
        $conf_file = $ENV{KRANG_CONF};
    } else { 
        $conf_file = catfile($ENV{KRANG_ROOT}, "conf", "krang.conf");
    }

    croak(<<CROAK) unless -e $conf_file and -r _;
Unable to find krang.conf.  Please set the KRANG_CONF environment
variable to the location of the Krang configuration file, or KRANG_ROOT 
to a directory containing conf/krang.conf.
CROAK

    # FIX: log "[krang] Loading configuration from $conf_file..." when
    # logger is written

    # load conf file into package global
    eval {
        our $CONF = Config::ApacheFormat->new(valid_directives => 
                                              \@VALID_DIRECTIVES,
                                              valid_blocks => [ 'instance' ]);
        $CONF->read($conf_file);
    };
    croak("Unable to read config file '$conf_file'.  Error was: $@")
      if $@;
    croak("Unable to read config file '$conf_file'.")
      unless $CONF;

    # mix in KrangRoot
    my $extra = qq(KrangRoot "$ENV{KRANG_ROOT}"\n);
    my $extra_fh = IO::Scalar->new(\$extra);
    $CONF->read($extra_fh);
}

=head1 INTERFACE

=over 4

=item C<< $value = Krang::Conf->get("DirectiveName") >>

=item C<< @values = Krang::Conf->get("DirectiveName") >>

Returns the value of a configuration directive.  Directive names are
case-insensitive.

=cut

sub get {
    my $self = shift;
    my ($conf_prop_name) = @_;

    # Var for return data
    my $cont_prop_value;

    if ($INSTANCE_CONF) {
        $cont_prop_value = $INSTANCE_CONF->get($conf_prop_name);

    } else {

        # At this point there are two possibilities:
        #
        #  1. The caller is requesting a $CONF-level property,
        #     in which case they should be able to get it without
        #     specifying an $INSTANCE
        # 
        #  2. The caller is requesting an $INSTANCE_CONF-level
        #     property, but has not yet specified $INSTANCE,
        #     in which case we should try to automagically set
        #     it, or croak() trying.

        # Check the root level $CONF
        $cont_prop_value = $CONF->get($conf_prop_name);

        # Is there a $CONF-level property by that name?
        unless (defined($cont_prop_value)) {
            my $instance_name = $self->instance();
            croak ("No Krang instance has been specified") unless (defined($instance_name));

            # If we got this far, retrieve the $cont_prop_value from $INSTANCE_CONF
            $cont_prop_value = $INSTANCE_CONF->get($conf_prop_name);
        }

    }

    return $cont_prop_value;
}

=item C<< $value = Krang::Conf->directivenamehere() >>

=item C<< @values = Krang::Conf->directivenamehere() >>

Gets the value of a directive using an autoloaded method.
Case-insensitive.

=cut

sub AUTOLOAD {
    our $AUTOLOAD;
    return if $AUTOLOAD =~ /DESTROY$/;
    my ($name) = $AUTOLOAD =~ /([^:]+)$/;

    return shift->get($name);
}

=item C<< $value = ExportedDirectiveName() >>

=item C<< @values = ExportedDirectiveName() >>

Gets the value of a variable using an exported, autoloaded method.
Case-insensitive.

=cut

# export config getters on demand
sub import {
    my $pkg = shift;
    my $callpkg = caller(0);
    
    foreach my $name (@_) {
        no strict 'refs'; # needed for glob refs
        *{"$callpkg\::$name"} = sub () { $pkg->get($name) };
    } 
}

=item C<< $current_instance = Krang::Conf->instance() >>

=item C<< Krang::Conf->instance("instance name") >>

Gets or sets the currently active instance.  After setting the active
instance, all requests for variables will retrieve values specific to
this instance.

Before the first call to C<instance()> only globally declared variables
are available.  Setting the instance to C<undef> will recreate this
state.

=cut

sub instance {
    my $pkg = shift;

    unless (@_) {
        # Is instance already set?
        return $INSTANCE if defined($INSTANCE);

        # If not, try to find the instance name via KRANG_INSTANCE
        my $env_instance_name = $ENV{KRANG_INSTANCE};

        # No KRANG_INSTANCE?  We've failed.  Return undef
        return undef unless defined($env_instance_name);

        # If KRANG_INSTANCE is defined, attempt to set instance()
        return $pkg->instance($env_instance_name);
    }
    
    my $instance = shift;
    if (defined $instance) {
        # get a handle on the block
        my $block = $CONF->block(instance => $instance);
        croak("Unable to find instance named '$instance' in configuration " .
              "file.") unless defined $block;

        # setup package state
        $INSTANCE      = $instance;
        $INSTANCE_CONF = $block;
    } else {
        # clear state
        undef $INSTANCE;
        undef $INSTANCE_CONF;
    }

    return $INSTANCE;
}   

=item C<< @instances = Krang::Conf->instances() >>

Returns a list of available instances.

=cut

sub instances {
    my @instances = $CONF->get("Instance");
    return map { $_->[1] } @instances;
}

=back

=head1 TODO

Module needs to write conf file path to the log when the log module is
available.

=cut


1;
