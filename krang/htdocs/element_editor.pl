#!/usr/bin/perl -w
use Krang::lib;
use Krang::ErrorHandler;
use Krang::CGI::ElementEditor;
my $app = Krang::CGI::ElementEditor->new();
$app->run();
