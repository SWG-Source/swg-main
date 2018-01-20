# ======================================================================
# PaletteArgb.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package PaletteArgb;
use strict;

# ======================================================================
# Setup variables that can be imported by Exporter into user modules.
# ======================================================================

use vars qw(@ISA @EXPORT_OK $VERSION);
use Exporter;
$VERSION = 1.00;
@ISA	 = qw(Exporter);

# These symbols are okay to export if specifically requested.
@EXPORT_OK = qw(&getEntryCount);

# ======================================================================

my $debug = 0;

# ======================================================================

sub getEntryCount
{
	# Get the full pathname for the palette.
	my $fullPathName = shift;
	die "Invalid fullPathName arg" unless defined($fullPathName);

	# Open the file.
	my $inputFile;
	open($inputFile, '< ' . $fullPathName) or die "Failed to open palette file [$fullPathName] for reading: $!";
	binmode($inputFile) or die "Failed to set file [$fullPathName] to binary mode: $!";

	# Skip the first 22 bytes.
	seek($inputFile, 22, 0) or die "Failed to seek to palette entry count position within [$fullPathName], bad palette file: $!";

	# Collect the entry count (2 bytes starting 22 bytes in).
	my $byteAsChar;

	read($inputFile, $byteAsChar, 1) or die "Failed to read entry count byte from [$fullPathName]: $!";
	my $entryCount = ord($byteAsChar);

	read($inputFile, $byteAsChar, 1) or die "Failed to read entry count byte from [$fullPathName]: $!";
	$entryCount	   += (ord($byteAsChar) << 8);

	# Close the file.
	close($inputFile) or die "Failed to close palette file [$fullPathName]: $!";

	printf("palette entries: %5d; name=[%s]\n", $entryCount, $fullPathName) if $debug;

	return $entryCount;
}

# ======================================================================

1;
