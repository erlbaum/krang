#!/usr/bin/perl -w
use Krang::ClassFactory qw(pkg);
use Krang::lib;
use Krang::ClassLoader 'ErrorHandler';
use Krang::ClassLoader 'CGI::Help';
pkg('CGI::Help')->new()->run();
