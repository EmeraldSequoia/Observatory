#!/usr/bin/perl -w

use strict;

my $src = "$ENV{SRCROOT}/Resources/help.txt";
my $dest = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app/help.txt";

# Version line substituted for EMERALD_VERSION_STRING in help.txt.  recordSVNVersion.pl used to do this
# from the git version, but it disables itself for GitHub builds, so take the version from the Info.plist.
sub plistValue {
    my $key = shift;
    my $plist = "$ENV{SRCROOT}/$ENV{PRODUCT_NAME}-Info.plist";
    chomp(my $value = `/usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null`);
    return $value;
}

my $shortVersion = plistValue "CFBundleShortVersionString";
my $bundleVersion = plistValue "CFBundleVersion";
$shortVersion
  or die "Couldn't read CFBundleShortVersionString from $ENV{PRODUCT_NAME}-Info.plist\n";
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
