#!/usr/bin/perl -w
use Krang::ClassFactory qw(pkg);
use Krang::lib;
use Krang::ClassLoader 'CGI::About';
pkg('CGI::About')->new()->run();
