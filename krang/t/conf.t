use Test::More tests => 21;
use strict;
use warnings;

use File::Temp qw(tempfile);

# setup a test conf file
my ($fh, $filename) = tempfile();
print $fh <<CONF;
ElementLibrary /usr/local/krang_elements

<Instance instance_one>
  ElementSet Flex
  DBName test
  DBUser test
  DBPass test
</Instance>

<Instance instance_two>
  ElementSet LA
  DBName test2
  DBUser test2
  DBPass test2
</Instance>
CONF
close($fh);

# use this file as krang.conf
$ENV{KRANG_CONF} = $filename;
ok(-e $filename);

eval "use_ok('Krang::Conf')";
die $@ if $@;

# get the globals, all ways
ok(Krang::Conf->get("KrangRoot"));
is(Krang::Conf->get("ElementLibrary"), "/usr/local/krang_elements");
ok(Krang::Conf->KrangRoot);
is(Krang::Conf->ElementLibrary, "/usr/local/krang_elements");

Krang::Conf->import(qw(KrangRoot ElementLibrary DBName));
ok(KrangRoot());
is(ElementLibrary(), "/usr/local/krang_elements");

Krang::Conf->instance("instance_one");
is(Krang::Conf->instance, "instance_one");
ok(KrangRoot());
is(Krang::Conf->get("DBName"), "test");
is(DBName(), "test");

Krang::Conf->instance("instance_two");
is(Krang::Conf->instance, "instance_two");
ok(KrangRoot());
is(Krang::Conf->get("DBName"), "test2");
is(DBName(), "test2");


## Test behavior for automagic setting of instance()
#
# Test no KRANG_INSTANCE
Krang::Conf->instance(undef);  # Reset Conf state
delete($ENV{KRANG_INSTANCE});  # Just in case...
ok(not defined Krang::Conf->instance());  # Should be undef

# Should read "instance_one" from environment
Krang::Conf->instance(undef);  # Reset Conf state
$ENV{KRANG_INSTANCE} = "instance_one";
is(Krang::Conf->instance(), "instance_one");  

# Test croak() when KRANG_INSTANCE == invalid instance
Krang::Conf->instance(undef);  # Reset Conf state
$ENV{KRANG_INSTANCE} = "no_such_instance_123";
eval { Krang::Conf->instance(); };
ok($@ =~ /No such block|Unable to find instance/);  

# Test empty KRANG_INSTANCE
Krang::Conf->instance(undef);  # Reset Conf state
$ENV{KRANG_INSTANCE} = "";
eval { Krang::Conf->instance(); };
ok($@ =~ /No such block|Unable to find instance/);  


## Test automagic loading of instance() via get()
#
Krang::Conf->instance(undef);  # Reset Conf state
delete($ENV{KRANG_INSTANCE});  # Just in case...
eval { DBName() };
ok($@ =~ /No Krang instance has been specified/);
