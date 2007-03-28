package Krang::HTMLTemplate;
use Krang::ClassFactory qw(pkg);
use strict;
use warnings;

=head1 NAME

Krang::HTMLTemplate - HTML::Template wrapper for Krang

=head1 SYNOPSIS

None.  See L<HTML::Template>.

=head1 DESCRIPTION

This module is a wrapper around HTML::Template which sets up certain
automatic template variables for templates loading through
Krang::CGI::load_tmpl().  Specifically, it is responsible for all
variables and loops found in F<header.tmpl>.

=head1 INTERFACE

See L<HTML::Template>.

=cut

use base 'HTML::Template';
use Krang::ClassLoader Session => qw(%session);
use Krang::ClassLoader Conf => qw(InstanceDisplayName KrangRoot Skin CustomCSS);
use Krang::ClassLoader Message => qw(get_messages clear_messages get_alerts clear_alerts);
use Krang::ClassLoader 'Navigation';
use Krang::ClassLoader Log => qw(debug);
use Krang::ClassLoader 'AddOn';

use File::Spec::Functions qw(catdir);
use Carp qw(croak);

# setup paths to templates
our @PATH;

sub reload_paths {
    @PATH = 
      (grep { -e $_ } 
       (map { catdir(KrangRoot, 'addons', $_, 'skins', Skin, 'templates'),
              catdir(KrangRoot, 'addons', $_, 'templates') }
        (map { $_->name } pkg('AddOn')->find())),
       catdir(KrangRoot, 'skins', Skin, 'templates'),
       catdir(KrangRoot, 'templates'));
}

BEGIN { reload_paths() }


# overload new() to setup template paths
sub new {
    my ($pkg, %arg) = @_;
    $arg{path} = $arg{path} ? _compute_path($arg{path}) : \@PATH;
    return $pkg->SUPER::new(%arg);
}

# given the path setting coming from the caller, compute the final path array
sub _compute_path {
    my $in = shift;
    $in = [ $in ] unless ref $in;

    # append @PATH to each input path
    my @out;
    foreach my $in (@$in) {
        foreach my $path (@PATH) {
            push(@out, "$path/$in");
        }
    }
    push(@out, @PATH);

    return \@out;
}

# overload output() to setup template variables
my %CUSTOM_CSS;
sub output {
    my $template = shift;

    # fill in header variables as necessary
    if ($template->query(name => 'header_user_name')) {
        my ($user) = pkg('User')->find(user_id => $ENV{REMOTE_USER});
        $template->param(header_user_name => $user->first_name . " " . 
                                             $user->last_name) if $user;
    }

    $template->param(instance_display_name => InstanceDisplayName)
      if $template->query(name => 'instance_display_name');

    if ($template->query(name => 'header_message_loop')) {
        $template->param( header_message_loop => [ map { { message => $_ } } get_messages() ] );
        clear_messages();
    }

    if ($template->query(name => 'header_alert_loop')) {
        $template->param( header_alert_loop => [ map { { alert => $_ } } get_alerts() ] );
        clear_alerts();
    }

    if (CustomCSS() and $template->query(name => 'custom_css') ) {
        # read in the custom css file if we can find it
        my $file = pkg('File')->find(CustomCSS());
        if( $file ) {
            my $css;
            if( $CUSTOM_CSS{$file} ) {
                $css = $CUSTOM_CSS{$file};
            } else {
                my $IN;
                open($IN, $file) or croak "Could not open file $file for reading: $!";
                # hopefully a tiny file, so slurp it
                {
                    local $/;
                    $css = <$IN>;
                }
                close($IN);
                $CUSTOM_CSS{$file} = $css;
            }
            $template->param(custom_css => $css);
        }
    }

    pkg('Navigation')->fill_template(template => $template);

    return $template->SUPER::output();
}

1;

