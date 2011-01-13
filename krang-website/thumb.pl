#!/usr/bin/perl -w
use lib '/home/sam/krang/lib';
use strict;
use Imager;

die "Usage: thumbmake.pl filename\n" if !-f $ARGV[0];
my $file = shift;

my $img = Imager->new();
$img->open(file=>$file) or die $img->errstr();

$file =~ s/\.[^.]*$//;

# Create smaller version
my $thumb = $img->scale(xpixels => 200);

# Autostretch individual channels
$thumb->filter(type=>'autolevels');

my $format = 'png';
$file.="-thumb.$format";
print "Storing image as: $file\n";
$thumb->write(file=>$file) or
  die $thumb->errstr;
