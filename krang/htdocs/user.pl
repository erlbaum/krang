#!/usr/bin/perl -w
use Krang::lib;
use Krang::ErrorHandler;
use Krang::CGI::User;
my $app = Krang::CGI::User->new();
$app->run();
