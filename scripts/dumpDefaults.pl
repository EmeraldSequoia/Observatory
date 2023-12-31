#!/usr/bin/perl -w

use strict;

use File::Basename;
use File::Copy qw/cp/;
use IO::Handle;

STDOUT->autoflush(1);
STDERR->autoflush(1);

my $simulatorAppDirRoot = "$ENV{HOME}/Library/Application Support/iPhone Simulator";

my $plistAgeInDays;
my $plistFile;
my $mostRecentProduct;

my @products = "Observatory";

foreach my $xcodeVersion ("3.0", "3.1.3", "3.2", "4.0") {
    my $simulatorAppDir = "$simulatorAppDirRoot/$xcodeVersion/Applications";
    opendir DIR, $simulatorAppDir
      or die "No directory $simulatorAppDir\n";
    my @entries = grep !/\./, readdir DIR;
    closedir DIR;
    foreach my $entry (@entries) {
	foreach my $product (@products) {
	    my $path = "$simulatorAppDir/$entry/Library/Preferences/com.emeraldsequoia.$product.plist";
	    if (-e $path) {
		my $pathAge = -M $path;
		defined $pathAge or die "Couldn't determine age of '$path'\n";
		if (!(defined $plistFile) || ($pathAge < $plistAgeInDays)) {
		    $plistFile = $path;
		    $plistAgeInDays = $pathAge;
		    $mostRecentProduct = $product;
		}
	    }
	}
    }
}

defined $plistAgeInDays
  or die "No EC-based apps installed in Simulator\n";
defined $plistFile
  or die "Internal error; plistFile undefined\n";

my $plistAgeInMinutes = $plistAgeInDays * 24 * 60;

printf "Plist file (for $mostRecentProduct) was last modified %.2f minutes ago:\n", $plistAgeInMinutes;
print "$plistFile\n";

if ($plistAgeInMinutes > 60) {
    die "Your preferences file appears to be more than an hour old\n";
}

system("plutil -convert xml1 -o - \"$plistFile\"");

printf "Plist file was last modified %.2f minutes ago\n", $plistAgeInMinutes;
