package Krang::lib;
use strict;
use warnings;

=head1 NAME

Krang::lib - setup Krang library search path

=head1 SYNOPSIS

  use Krang::lib;

  # reload lib dirs when needed (ex. addon install)
  Krang::Lib->reload();

=head2 DESCRIPTION

This module is responsible for setting up the search path for Krang's
Perl libraries.  It handles setting @INC and $ENV{PERL5LIB} to correct
values.

B<NOTE>: Krang::lib is used by Krang::Script, so in most cases you
should just use Krang::Script and leave it at that.

=head2 INTERFACE

=head3 C<< Krang::Lib->reload() >>

Call to reload library paths.  This is only needed when something new
is added, removal is handled automatically by Perl.

=cut

use Carp qw(croak);
use File::Spec::Functions qw(catdir);
use Config;

sub reload { shift->import() }

sub import {
    my $root = $ENV{KRANG_ROOT} 
      or croak("KRANG_ROOT must be defined before loading Krang::lib");
    
    # using Krang::Addon would be easier but this module shouldn't
    # load any Krang:: modules since that will prevent them from being
    # overridden in addons
    opendir(my $dir, catdir($root, 'addons'));
    while(my $addon = readdir($dir)) {
        next if $addon eq '.' or $addon eq '..';
        my $lib  = catdir($root, 'addons', $addon, 'lib');
        $ENV{PERL5LIB} .= ":$lib";
        unshift @INC, $lib, "$lib/".$Config{archname};
    }

    # warn("INC after Krang::lib setup:\n\t" . join("\n\t", @INC));
}

1;
