#!/usr/bin/perl -w
use Krang::lib;
use Krang::ErrorHandler;
use Krang::CGI::ListGroup;
my $app = Krang::CGI::ListGroup->new();
$app->run();
