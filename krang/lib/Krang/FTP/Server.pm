package Krang::FTP::Server;
use strict;
use warnings;
use Carp qw(croak);
use Krang::User;
use Krang::Log qw(debug info critical);
use Net::FTPServer;
use Krang::FTP::FileHandle;
use Krang::FTP::DirHandle;

# Inheritance
our @ISA = qw(Net::FTPServer);

=head1 NAME

Krang::FTP::Server - Virtual FTP Server for Krang Templates and Media

=head1 SYNOPSIS

    use Krang::FTP::Server;
    Krang::FTP::Server->run();

=head1 DESCRIPTION

This module provides an FTP interface to Krang Templates and Media. The
directory tree is the site/category tree created in Krang. 
At the top level (/) there are two directories: /template and /media. 
What appears to be directories below /template and /media 
actually correspond with L<Krang::Site>s (if any exist).  Below the 
site dir appears that site's L<Krang::Category> tree as a directory 
structure.  If there are not multiple sites, the single category tree 
appears starting below /template and /media. Files within these directories 
are L<Krang::Template> .tmpl files (in the /template tree),and media 
files associated with L<Krang::Media> objects (in the /media tree).
When a user downloads a .tmpl or media file 
with Krang::FTP::Server, they recieve the file from the most recent 
checked-in version of Template/Media object. When a file is uploaded it
is automatically checked in and published/deployed.

For installation and configuration instructions see L<Krang::Admin>

=head1 LIMITATIONS

Only GET, PUT and DELETE are implemented for templates and media.  No
modification of categories is supported.

=head1 INTERFACE

This module inherits from Net::FTPServer and doesn't override any
public methods.  See L<Net::FTPServer> for details.

=head1 PRIVATE

=head2 Private Instance Methods

=over 4

=item pre_configuration_hook()

This is called by Net:FTPServer before configuration begins.  It's
used in this class to add our name and version to the version string
displayed by the server.

=cut

sub pre_configuration_hook {
  my $self = shift;

  # add to version info
  $self->{version_string} .= " Krang::FTP::Server";
  
}

=item authenticaton_hook($user, $pass, $user_is_anon)

When a user logs in authentication_hook() is called to check their
username and password.  This method calls
Krang::User->find() using the given username and then
checks the password.  Also stores the Krang::User object into
$self->{user_obj}. Returns -1 on login failure or 0 on success.

=cut

sub authentication_hook {
    my $self = shift;
    my $user = shift;
    my $pass = shift;
    my $user_is_anon = shift;

    # log this attempt to login
    info("FTP Login attempt- Username:$user.");
 
    # disallow anonymous access.
    return -1 if $user_is_anon;

    # get user object
    my $user_object = Krang::User->find( login => $user ); 

    $self->{user_obj} = $user_object if $user_object;
    debug("User object found for login $user.");
 
    # return failure if authentication fails.
    my $login_ok = Krang::User->check_auth($user,$pass);

    if (not $login_ok) {
        info("FTP login/passowrd denied.");
        return -1;
    }
 
    # successful login.
    info("FTP login/password accepted.");
    return 0;
}

=item root_directory_hook()

Net::FTPServer calls this method to get a DirHandle for the root
directory.  This method just calls Krang::FTP::DirHandle->new().

=cut

sub root_directory_hook {
  my $self = shift;
  return new Krang::FTP::DirHandle ($self);
}

=item system_error_hook()

This method is called when an error is signaled elsewhere in the
server.  It looks for a key called "error" in $self and returns that
if it's available.  This allows for an OO version of the ever-popular
$! mechanism.  (Or, at least, that's the idea.  As far as I can tell
it never really gets called!)

=cut

sub system_error_hook {
  my $self = shift;
  return delete $self->{error}
    if exists $self->{error};
  return "Unknown error occurred.";
}

1;

=back

=cut

1;
