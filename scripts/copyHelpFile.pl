#!/usr/bin/perl -w

use strict;

my $src = "$ENV{SRCROOT}/Resources/help.txt";
my $dest = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app/help.txt";

# Version line substituted for EMERALD_VERSION_STRING in help.txt.  recordSVNVersion.pl used to do this
# from the git version, but it disables itself for GitHub builds.  The Info.plist just refers to the
# MARKETING_VERSION and CURRENT_PROJECT_VERSION build settings (the target's Version and Build fields),
# and Xcode passes build settings to script phases in the environment, so take them from there.
my $shortVersion = $ENV{MARKETING_VERSION};
my $bundleVersion = $ENV{CURRENT_PROJECT_VERSION};
$shortVersion
  or die "MARKETING_VERSION is not set; set the target's Version in Xcode\n";
if (!$bundleVersion) {
    $bundleVersion = $shortVersion;
}

my $configuration = $ENV{CONFIGURATION} || "";
my $versionLine = "Emerald Observatory Version $shortVersion ($bundleVersion)";
if ($configuration !~ /distrib/i) {  # Distribution builds get the bare version, everything else says more
    my $buildDate = localtime;
    $versionLine .= " [$configuration]; Built $buildDate";
}

open SRC, $src
  or die "Couldn't read $src: $!\n";
open DEST, ">$dest"
  or die "Couldn't write $dest: $!\n";
while (<SRC>) {
    s/EMERALD_VERSION_STRING/$versionLine/g;
    print DEST $_;
}
close DEST;
close SRC;
