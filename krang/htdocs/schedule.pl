#!/usr/bin/perl -w
use Krang::lib;
use Krang::ErrorHandler;
use Krang::CGI::Schedule;
my $app = Krang::CGI::Schedule->new();
$app->run();
