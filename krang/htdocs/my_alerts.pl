#!/usr/bin/perl -w
use Krang::lib;
use Krang::ErrorHandler;
use Krang::CGI::MyAlerts;
my $app = Krang::CGI::MyAlerts->new();
$app->run();
