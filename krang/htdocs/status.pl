#!/usr/bin/perl -w
use Krang::lib;
use Krang::ErrorHandler;
use Krang::CGI::Status;
my $app = Krang::CGI::Status->new();
$app->run();
