#!/usr/bin/perl -w
use Krang::lib;
use Krang::ErrorHandler;
use Krang::CGI::Group;
my $app = Krang::CGI::Group->new();
$app->run();
