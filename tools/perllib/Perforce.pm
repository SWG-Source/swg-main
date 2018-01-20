# ======================================================================
# Perforce.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package Perforce;
use strict;

# ======================================================================
# Perforce public variables.
# ======================================================================

# our $relativePathName;

# ======================================================================
# Setup variables that can be imported by Exporter into user modules.
# ======================================================================

use vars qw(@ISA @EXPORT_OK $VERSION);
use Exporter;
$VERSION = 1.00;
@ISA	 = qw(Exporter);

# These symbols are okay to export if specifically requested.
#@EXPORT_OK = qw(&buildFileLookupTable &saveFileLookupTable &loadFileLookupTable &getFullPathName);
@EXPORT_OK = qw(&findOnDiskFileName);

# ======================================================================
# Perforce private variables.
# ======================================================================

# my $debug = 0;

# ======================================================================
# Perforce public functions.
# ======================================================================

sub findOnDiskFileName
{
	# Run p4 where.
	my $p4DepotFile = shift;
	my $output = `p4 where $p4DepotFile`;
	die "p4 where failed: [$?] [$output]" if ($? != 0);
	
	# Split p4 where output into array.	 Assumes no spaces in paths.
	my @outputInfo = split /\s+/,$output;
	my $entryCount = @outputInfo;
	die "expecting a non-zero, positive multiple of 3 items returned by p4 where, found $entryCount" if ($entryCount < 3) or (($entryCount % 3) != 0);
	
	# Return on-disk location.  The correct local client mapping will be
	# the last entry of the final triplet returned by P4.  Earlier triplets,
	# if present, appear to be "not here" minus-style mappings indicating
	# places where the file could have gone but was overridden by a client
	# spec setting.  That part doesn't appear to be documented in 'p4 help where'.
	return $outputInfo[$entryCount - 1];
}

# ======================================================================

# Indicate the module loaded successfully.
1;
