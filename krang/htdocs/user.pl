#!/usr/bin/perl -w
use Krang::ClassFactory qw(pkg);
use Krang::lib;
use Krang::ClassLoader 'ErrorHandler';
use Krang::ClassLoader 'CGI::User';
my $app = pkg('CGI::User')->new();
$app->run();
