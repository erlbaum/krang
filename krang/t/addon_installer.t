use strict;
use warnings;

use Krang::Script;
use Test::More qw(no_plan);
use Krang::AddOn;
use Krang::Conf qw(KrangRoot);
use File::Spec::Functions qw(catfile);

# make sure Turbo isn't installed
my ($turbo) = Krang::AddOn->find(name => 'Turbo');
ok(not $turbo);

# install Turbo 1.00
my $installer = catfile(KrangRoot, 'bin', 'krang_addon_installer');
my $cmd = $installer . " " .
  catfile(KrangRoot, 't', 'addons', 'Turbo-1.00.tar.gz');
system("$cmd > /dev/null") && die "Unable to run krang_addon_installer: $?";

# worked?
($turbo) = Krang::AddOn->find(name => 'Turbo');
isa_ok($turbo, 'Krang::AddOn');
cmp_ok($turbo->version, '==', 1);
ok(-d 'addons/Turbo');
ok(-e 'addons/Turbo/lib/Krang/Turbo.pm');
ok(not -e 'lib/Krang/Turbo.pm');
ok(-e 'addons/Turbo/t/turbo.t');
ok(-e 'addons/Turbo/docs/turbo.pod');
ok(not -e 'krang_addon.conf');

=begin comment

# upgrade to Turbo 1.01
$cmd = $installer . " " .
  catfile(KrangRoot, 't', 'addons', 'Turbo-1.01.tar.gz');
system("$cmd > /dev/null");

# worked?
($turbo) = Krang::AddOn->find(name => 'Turbo');
isa_ok($turbo, 'Krang::AddOn');
cmp_ok($turbo->version, '==', 1.01);
ok(-e 'lib/Krang/Turbo.pm');
ok(-e 't/turbo.t');
ok(-e 'docs/turbo.pod');
ok(-e 'turbo_1.01_was_here');
ok(not -e 'krang_addon.conf');

=end comment

=cut

# clean up
$turbo->delete;
system('rm -rf addons/Turbo') && die "Unable to cleanup.";
