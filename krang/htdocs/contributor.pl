#!/usr/bin/perl -w
use Krang::ClassFactory qw(pkg);
use Krang::lib;

use Krang::ClassLoader 'CGI::Contrib';
my $app = pkg('CGI::Contrib')->new();
$app->run();
