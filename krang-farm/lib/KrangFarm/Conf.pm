package KrangFarm::Conf;
use strict;
use warnings;

use Config::ApacheFormat;
use File::Spec::Functions qw(catfile);
use Carp qw(croak);

=head1 NAME

KrangFarm::Conf - configuration for the Krang Farm

=item SYNOPSIS

  use KrangFarm::Conf;

  foreach my $machine (KrangFarm->machines()) {
      print "Name: . " $machine->{name} . "\n";
      print "Description: " . $machine->{description} . "\n";
      print "User: " . $machine->{user} . "\n";
      # ...
  }

=head1 DESCRIPTION

This module provides access to the values configured in
F<conf/farm.conf>.

=head1 INTERFACE

=over

=item *

C<< KrangFarm::Conf->machines() >>

Returns the list of machines defined in C<conf/farm.conf>.  Each
machine is a hash containing the following keys:

=over

=item name

=item description

=item user

=item password

=back

=back

=cut

# load configuration when this module loads
# internal routine to load the conf file.  Called by a BEGIN during
# startup, and used during testing.
our @MACHINE_VARS = qw(description user password);
our $CONF;
sub _load {
    # find a default conf file
    my $conf_file;
    if (exists $ENV{KRANGFARM_CONF}) {
        $conf_file = $ENV{KRANGFARM_CONF};
    } else { 
        $conf_file = catfile($ENV{KRANGFARM_ROOT}, "conf", "farm.conf");
    }

    warn(<<CROAK) and exit unless -e $conf_file and -r _;

Unable to find farm.conf!

CROAK

    # load conf file into package global
    eval {
        our $CONF = Config::ApacheFormat->new(valid_blocks => [ 'machine' ]);
        $CONF->read($conf_file);
    };
    croak("Unable to read config file '$conf_file'.  Error was: $@")
      if $@;
    croak("Unable to read config file '$conf_file'.")
      unless $CONF;
}
BEGIN { _load() }

sub machines {
    my %machines;
    foreach my $name (map { $_->[1] } $CONF->get("machine")) {
        my $block = $CONF->block([machine => $name]);
        $machines{$name} = { map { ($_, $block->get($_)) } @MACHINE_VARS };
        $machines{$name}{name} = $name;
    }
    return \%machines;
}

1;
