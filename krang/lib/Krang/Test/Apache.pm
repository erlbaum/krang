package Krang::Test::Apache;
use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common;
use File::Spec::Functions qw(catfile);
use HTTP::Cookies;
use Krang::Conf qw(KrangRoot HostName ApachePort);
use Krang::Log qw(debug);
use Test::Builder;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(login_ok login_not_ok request_ok 
                 response_like response_unlike);

# hook up Test::Builder ala the Test::Builder POD 
my $Test = Test::Builder->new;
sub import {
    my($self) = shift;
    my $pack = caller;
    $Test->exported_to($pack);    
    $self->export_to_level(1, $self, @EXPORT);
}

# initialize an LWP user agent object to use in the tests
my $ua = LWP::UserAgent->new(agent => 'Mozilla/5.0');

# setup cookie jar
my $cookies = HTTP::Cookies->new();
$ua->cookie_jar($cookies);

# the last response is stored here
my $res;

=head1 NAME

Krang::Test::Apache - support module for testing against Apache

=head1 SYNOPSIS

  use Test::More qw(no_plan); 
  use Krang::Test::Apache;

  # make sure bad logins fail
  login_not_ok('foo', 'bar');

  # login for real, now other tests can run
  login_ok('admin', 'shredder');

  # test requesting a list of stories
  request_ok('story.pl', { rm => 'find' });
  reponse_like(qr/FIND STORY/);
  reponse_unlike(qr/None Found/);

=head1 DESCRIPTION

This module exists to make writing tests against the web interface
easier.  Krang::Test::Apache uses Test::Builder and works the same way
Test::More does.

=head1 INTERFACE

All functions described below can take an optional final $name
parameter to name the test, like Test::More::ok() and others.  All the
functions described below are exported by default, in true Test::More
style.

=over 4

=item login_ok($username, $password)

Logs into Krang with the supplied username and password.  The test
succeeds if the login was successful and fails otherwise.  

A side-effect of this test passing is that the underlying cookie
object gets loaded with a valid login cookie.  This is necessary
before other tests against the interface can run successfully.

=cut

sub login_ok {
    my($username, $password, $name) = @_;
    $Test->ok(_do_login($username, $password), $name);
}

# underlying login function used by login_ok and login_not_ok
sub _do_login {
    my($username, $password) = @_;
    my $instance = Krang::Conf->instance;
    
    my $url = _url('login.pl');
    my $res = $ua->request(POST $url,
                           [ rm => 'login',

                             username => $username ,
                             password => $password ]);
    # should get a redirect
    return 0 unless $res->code == 302;
    
    # try to request env.pl, which will only work if the login succeeded
    $res = $ua->request(GET _url('env.pl'));
    return 0 unless $res->code == 200;
    return 0 unless $res->content =~ /REMOTE_USER/;
    
    # success
    return 1;
}

=item login_not_ok($username, $password)

The opposite of login_ok().  Succeeds if the login attempt fails.

=cut

sub login_not_ok {
    my($username, $password, $name) = @_;
    $Test->ok(not _do_login($username, $password), $name);
}

=item request_ok($script, \%params)

Makes a POST request to the named script with the given set of
parameters and options.  Succeeds if the result is a success (defined
as an HTTP response code of 200 or 302).

=cut

sub request_ok {
    my ($script, $params, $name) = @_;

    $res = $ua->request(POST _url($script),
                        [ %$params ]);
    debug("FAILED REQUEST: " . $res->as_string)
      unless $res->code == 200 or $res->code == 302;
    $Test->ok($res->code == 200 or $res->code == 302, $name);
}

=item response_like(qr/$re/)

Tests a regular expression against the content of the last response
generated by a previous request_ok().

=cut

sub response_like {
    my ($re, $name) = @_;
    $Test->like($res->content, $re, $name);
}

=item response_unlike(qr/$re/)

Opposite of response_like().

=cut

sub response_unlike {
    my ($re, $name) = @_;
    $Test->unlike($res->content, $re, $name);
}

=back

=cut

# private functions
###################

# return the URL to a given script in the current instance
sub _url {
    my $script = shift;

    # compute Krang's URL
    my $base_url = 'http://' . HostName;
    $base_url .= ":" . ApachePort if ApachePort ne '80';

    # build the URL
    return join('/', $base_url, Krang::Conf->instance, $script);
}

1;
