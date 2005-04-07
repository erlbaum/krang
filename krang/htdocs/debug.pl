#!/usr/bin/perl -w
use Krang::ClassFactory qw(pkg);
use Krang::lib;
use Krang::ClassLoader 'CGI::Debug';
pkg('CGI::Debug')->new()->run();
