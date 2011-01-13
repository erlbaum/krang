#!/usr/bin/perl -w
use strict;
use Expect;
use File::Spec::Functions qw(catfile catdir);
use File::Temp qw(tempdir);

die("Missing setting for KRANG_ROOT!") unless $ENV{KRANG_ROOT};
die("Missing setting for KRANG_WEBSITE_ROOT!") unless $ENV{KRANG_WEBSITE_ROOT};
die("Missing setting for SF_USERNAME!") unless $ENV{SF_USERNAME};
die("Missing setting for SF_PASSWORD!") unless $ENV{SF_PASSWORD};

# update Krang from SVN
chdir($ENV{KRANG_ROOT}) or die $!;
print "Updating SVN checkout...\n";
system("svn update") == 0 or die "Failed to update SVN: $?";

# rebuild docs
print "Building docs...\n";
system("make docs") == 0 or die "Failed to make docs: $?";

# update Krang website from CVS
chdir($ENV{KRANG_WEBSITE_ROOT}) or die $!;
print "Updating SVN checkout...\n";
system("svn update") == 0 or die "Failed to update CVS: $?";

# copy in docs
print "Copying docs into place.\n";
system("rm -rf docs");
system("cp -R " . catdir($ENV{KRANG_ROOT}, "docs") . " .");

# tar up website
print "Creating tar-ball.\n";
my $temp = tempdir(CLEANUP => 1);
my $tar = catfile($temp, 'krang-website.tar');
system("tar cvf $tar .");
system("gzip -9 $tar");
$tar .= ".gz";

# send the tar-ball to SF
print "Sending tar-ball to SF.\n";
my $command = Expect->spawn("scp -v $tar $ENV{SF_USERNAME}\@shell.sf.net:");
if ($command->expect(undef, 'password:')) {
    $command->send($ENV{SF_PASSWORD} . "\n");
}
$command->expect(undef);
$command->soft_close();
die "Failed to send file to SF." if $command->exitstatus() != 0;

# unpack tar-ball on SF
print "Unpacking tar-ball on SF.\n";
$command = Expect->spawn("ssh $ENV{SF_USERNAME}\@shell.sf.net");
if ($command->expect(undef, 'password:')) {
    $command->send($ENV{SF_PASSWORD} . "\n");
}
if ($command->expect(undef, '$ ')) {
    $command->send("newgrp krang\n");
}
if ($command->expect(undef, '$ ')) {
    $command->send("cd /home/groups/k/kr/krang/htdocs; tar xzvf ~/krang-website.tar.gz\n");
}
if ($command->expect(undef, '$ ')) {
    $command->send("exit\n");
}
if ($command->expect(undef, '$ ')) {
    $command->send("exit\n");
}

$command->soft_close();
die "Failed to send file to SF." if $command->exitstatus() != 0;
