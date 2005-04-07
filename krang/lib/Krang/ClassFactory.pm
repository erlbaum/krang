package Krang::ClassFactory;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(pkg);

=head1 NAME

Krang::ClassFactory - a registry for class names allowing runtime overrides

=head1 SYNOPSIS

  use Krang::ClassLoader ClassFactory => qw(pkg);

  # instead of this
  pkg('Story')->new(...);

  # write this:
  pkg('Story')->new();

=head1 DESCRIPTION

This module mainatins a table of class names which allows addons to
selectively override core Krang classes.  Addons declare their
overrides via a F<conf/class.conf> file.  For example, if the
Turbo-1.00.tar.gz addon contains a F<conf/class.conf> file with:

  Story Turbo::Story

Then Krang will return 'Turbo::Story' for calls to class('Story').
This will have the effect of dynamically substituting Turbo::Story for
Krang::Story.  The benefit of this over just including
C<lib/Krang/Story.pm> in the addon is that Turbo::Story can (and
probably I<should>) inherit from Krang::Story to implement its
functionality.

=head1 INTERFACE

=head2 pkg($class_name)

This function returns a class name (ex. Krang::Story) given a partial
class name (Story).  By default this function meerly appends Krang::
to the name passed in, unless an addon has registered an override, in
which case that will be returned instead.

The name for this function was chosen primarily for its size.  Since
pkg('foo') is exactly as long as Krang:: this new system was added via
search-and-replace without breaking any code formatting.

=cut

our %CLASSES;

sub pkg {
    return "Krang::" . $_[0] unless exists $CLASSES{$_[0]};
    return $CLASSES{$_[0]};
}

1;
