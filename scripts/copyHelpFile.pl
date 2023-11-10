#!/usr/bin/perl -w

use strict;

use File::Copy 'cp';

my $src = "$ENV{SRCROOT}/Resources/help.txt";
my $dest = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app/help.txt";

cp $src, $dest
  or die "Couldn't copy $src to $dest: $!\n";
