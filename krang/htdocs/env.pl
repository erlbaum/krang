#!/usr/bin/perl -w
use Krang::lib;
use Krang::ErrorHandler;
use Krang::CGI;
my $app = Krang::CGI->new();
$app->run();
