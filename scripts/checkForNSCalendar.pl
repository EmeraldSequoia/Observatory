#!/usr/bin/perl -w

use strict;

use IO::Handle;

STDOUT->autoflush(1);
STDERR->autoflush(1);

my $foundError = 0;

sub checkFile {
    my $file = shift;
    open FILE, $file
      or die "Couldn't read file $file: $!\n";
    while (<FILE>) {
	if (/(NSDateComponents|NSCalendar|NSTimeZone)/) {
	    print "Error: Found $1 in $file\n";
	    $foundError = 1;
	    last;
	}
    }
    close FILE;
}

sub checkSpecialFile {
    my $file = shift;
    open FILE, $file
      or die "Couldn't read file $file: $!\n";
    my $inSpecialBlock = 0;
    my $inSpecialInnerBlock = 0;
    while (<FILE>) {
	if (/^-.*viewDidLoad/) {
	    $inSpecialBlock = 1;
	} elsif (($inSpecialBlock && /^#ifndef NDEBUG/) || /^#ifdef ESCALENDAR_NS/) {
	    $inSpecialInnerBlock = 1;
	} elsif ($inSpecialInnerBlock && /^#endif/) {
	    $inSpecialInnerBlock = 0;
	} elsif ($inSpecialBlock && /^}/) {
	    $inSpecialBlock = 0;
	}
	if (/(NSDateComponents|NSCalendar)/) {
	    print "Error: Found $1 in $file\n";
	    $foundError = 1;
	    last;
	}
	if (!$inSpecialInnerBlock && /NSTimeZone/) {
	    print "Error: Found NSTimeZone in $file (not in special block)\n";
	    $foundError = 1;
	    last;
	}
    }
    close FILE;
}

sub checkDir {
    my $dir = shift;
    opendir DIR, $dir
      or die "Couldn't read directory $dir: $!\n";
    my @entries = grep /\.m$|\.h$/, readdir DIR;
    closedir DIR;
    foreach my $entry (@entries) {
	if ($dir eq ".") {
	    checkFile $entry;
	} elsif ($entry =~ /^ECOptionsTZRoot\.m$/) {
	    checkSpecialFile "$dir/$entry";
	} else {
	    checkFile "$dir/$entry";
	}
    }
}

checkDir ".";
checkDir "Classes";
checkDir "EC";
#checkSpecialFile "Calendar/ESCalendar.h";

if ($foundError) {
    die "No references to NSCalendar or NSDateComponents allowed outside of Calendar/Calendar.m\n";
}
