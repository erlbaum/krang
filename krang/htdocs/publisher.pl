#!/usr/bin/perl -w
use Krang::lib;
use Krang::ErrorHandler;
use Krang::CGI::Publisher;
my $app = Krang::CGI::Publisher->new();
$app->run();
