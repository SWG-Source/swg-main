# ======================================================================
# DetailAppearanceTemplate.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package DetailAppearanceTemplate;
use strict;

use CustomizationVariableCollector;
use Iff;

# ======================================================================
# DetailAppearanceTemplate potentially-public variables.
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
@EXPORT_OK = qw(&install);

# ======================================================================
# DetailAppearanceTemplate private variables.
# ======================================================================

my $debug = 0;
my $treeFileRelativeName;

# ======================================================================
# DetailAppearanceTemplate public functions.
# ======================================================================

sub install
{
	# Register handler with CustomizationVariableCollector
	CustomizationVariableCollector::registerHandler("DTLA", \&processIff);
}

# ======================================================================
# DetailAppearanceTemplate private functions
# ======================================================================

sub processIff
{
	# Process args.
	my $iff = shift;
	die "bad iff arg specified" if ref($iff) ne "Iff";

	$treeFileRelativeName = shift;
	die "bad tree file relative name" if !defined($treeFileRelativeName);
	print "DetailAppearanceTemplate: processing file [$treeFileRelativeName]\n" if $debug;

	# Ensure we're in the proper form.
	return 0 unless $iff->getCurrentName() eq "DTLA";

	$iff->enterForm("DTLA");
	{
		my $version = $iff->getCurrentName();
		if ($version =~ m/^000[1-8]$/)
		{
			process_0001_0008($iff);
		}
		else
		{
			print STDERR "DetailAppearanceTemplate: unsupported version tag [$version].";
			return 0;
		}
	}
	$iff->exitForm("DTLA");

	print "DetailAppearanceTemplate: finished processing file [$treeFileRelativeName]\n" if $debug;

	# Success.
	return 1;
}

# ----------------------------------------------------------------------

sub process_0001_0008
{
	print "process_0001_0008(): begin\n" if $debug;

	my $iff = shift;
	die 'bad $iff arg' if ref($iff) ne 'Iff';

	$iff->enterForm();

	$iff->walkIff(\&iffWalker_0001_0008);

	$iff->exitForm();

	print "process_0001_0008(): end\n" if $debug;
}

# ----------------------------------------------------------------------

sub iffWalker_0001_0008
{
	my $iff		  = shift;
	die 'bad iff arg' if ref($iff) ne 'Iff';

	my $blockName = shift;
	my $isChunk	  = shift;

	printf("iffWalker_0001_0008(): %s=[%s]\n", $isChunk ? "chunk" : "form", $blockName) if $debug;

	# Process blocks we understand.
	if ($isChunk)
	{
		if ($blockName eq 'CHLD')
		{
			# Handle specifying linked appearance template assets.
			$iff->skipBytes(4);

			# NOTE: this is sneaky: appearances are missing the leading 'appearance/'.
			#       This burned me first time around.
			my $appearanceTemplateName = 'appearance/' . $iff->read_string();
			CustomizationVariableCollector::logAssetLink($treeFileRelativeName, $appearanceTemplateName);
		}
	}

	# Keep traversing.
	return 1;
}

# ======================================================================

1;
