use strict;
use warnings;

use Krang::Script;
use Test::More qw(no_plan);
use Krang::AddOn;
use Krang::Conf qw(KrangRoot);
use File::Spec::Functions qw(catfile);
use Krang::ElementLibrary;
use Krang::Test::Apache;
use Krang::HTMLTemplate;

# make sure Turbo isn't installed
my ($turbo) = Krang::AddOn->find(name => 'Turbo');
ok(not $turbo);

# install Turbo 1.00
Krang::AddOn->install(src => 
                      catfile(KrangRoot, 't', 'addons', 'Turbo-1.00.tar.gz'));

# worked?
($turbo) = Krang::AddOn->find(name => 'Turbo');
END { $turbo->uninstall }
isa_ok($turbo, 'Krang::AddOn');
cmp_ok($turbo->version, '==', 1);
ok(-d 'addons/Turbo');
ok(-e 'addons/Turbo/lib/Krang/Turbo.pm');
ok(not -e 'lib/Krang/Turbo.pm');
ok(-e 'addons/Turbo/t/turbo.t');
ok(-e 'addons/Turbo/docs/turbo.pod');
ok(not -e 'krang_addon.conf');

# try to load Krang::Turbo
use_ok('Krang::Turbo');

# upgrade to Turbo 1.01
Krang::AddOn->install(src => 
                      catfile(KrangRoot, 't', 'addons', 'Turbo-1.01.tar.gz'));

# worked?
($turbo) = Krang::AddOn->find(name => 'Turbo');
isa_ok($turbo, 'Krang::AddOn');
cmp_ok($turbo->version, '==', 1.01);
ok(-e 'addons/Turbo/lib/Krang/Turbo.pm');
ok(-e 'addons/Turbo/t/turbo.t');
ok(-e 'addons/Turbo/docs/turbo.pod');
ok(-e 'turbo_1.01_was_here');
unlink('turbo_1.01_was_here');

# install an addon with an element set
Krang::AddOn->install(src => 
            catfile(KrangRoot, 't', 'addons', 'NewDefault-1.00.tar.gz'));
# worked?
my ($def) = Krang::AddOn->find(name => 'NewDefault');
END { $def->uninstall }
isa_ok($def, 'Krang::AddOn');
cmp_ok($def->version, '==', 1.00);
is($def->name, 'NewDefault');

# try loading the element lib
eval { Krang::ElementLibrary->load_set(set => "Default2") };
ok(not $@);
die $@ if $@;

# install an addon with an htdocs/ script
Krang::AddOn->install(src => 
            catfile(KrangRoot, 't', 'addons', 'LogViewer-1.00.tar.gz'));
# worked?
my ($log) = Krang::AddOn->find(name => 'LogViewer');
END { $log->uninstall }
isa_ok($log, 'Krang::AddOn');
cmp_ok($log->version, '==', 1.00);
is($log->name, 'LogViewer');

# try loading the about.tmpl template
my $template = Krang::HTMLTemplate->new(filename => 'about.tmpl',
                                        path     => 'About/');
like($template->output, qr/enhanced with LogViewer/);

# try hitting the CGI through the webserver
SKIP: {
    skip "Apache server isn't up, skipping live tests", 3
      unless -e catfile(KrangRoot, 'tmp', 'httpd.pid');

    # get creds
    my $username = $ENV{KRANG_USERNAME} ? $ENV{KRANG_USERNAME} : 'admin';
    my $password = $ENV{KRANG_PASSWORD} ? $ENV{KRANG_PASSWORD} : 'whale';
    login_ok($username, $password);

    # hit workspace.pl and look for the new nav entries
    request_ok('workspace.pl', {});
    response_like(qr/Log Tools/);
    response_like(qr/<a.*?log_viewer.pl.*>.*?View Log/);

    # try the script
    request_ok('log_viewer.pl', {});
    response_like(qr/hi mom/i);
}

