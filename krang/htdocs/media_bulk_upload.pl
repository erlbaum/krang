#!/usr/bin/perl -w
use Krang::lib;
use Krang::ErrorHandler;
use Krang::CGI::Media::BulkUpload;
my $app = Krang::CGI::Media::BulkUpload->new();
$app->run();

