#!/usr/bin/perl -w
use Krang::ClassFactory qw(pkg);
use Krang::ClassLoader 'ErrorHandler';
use Krang::ClassLoader 'CGI::Trash';
pkg('CGI::Trash')->new(
##    PARAMS => {
# TODO
##        PACKAGE_ASSETS => { story => [qw(read-only edit)] },
##        RUNMODE_ASSETS => {
##        },
##    },
)->run();
