# ======================================================================
# SkeletalAppearanceTemplate.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package SkeletalAppearanceTemplate;
use strict;

use CustomizationVariableCollector;
use Iff;

# ======================================================================
# SkeletalAppearanceTemplate potentially-public variables.
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
# SkeletalAppearanceTemplate private variables.
# ======================================================================

my $debug = 0;
my $treeFileRelativeName;

# ======================================================================
# SkeletalAppearanceTemplate public functions.
# ======================================================================

sub install
{
	# Register handler with CustomizationVariableCollector
	CustomizationVariableCollector::registerHandler("SMAT", \&processIff);
}

# ======================================================================
# SkeletalAppearanceTemplate private functions
# ======================================================================

sub processIff
{
	# Process args.
	my $iff = shift;
	die "bad iff arg specified" if ref($iff) ne "Iff";

	$treeFileRelativeName = shift;
	die "bad tree file relative name" if !defined($treeFileRelativeName);
	print "SkeletalAppearanceTemplate: processing file [$treeFileRelativeName]\n" if $debug;

	# Ensure we're in the proper form.
	return 0 unless $iff->getCurrentName() eq "SMAT";

	$iff->enterForm("SMAT");
	{
		my $version = $iff->getCurrentName();
		if ($version eq "0003")
		{
			process_0003($iff);
		}
		else
		{
			print STDERR "SkeletalAppearanceTemplate: unsupported version tag [$version].";
			return 0;
		}
	}
	$iff->exitForm("SMAT");

	print "SkeletalAppearanceTemplate: finished processing file [$treeFileRelativeName]\n" if $debug;

	# Success.
	return 1;
}

# ----------------------------------------------------------------------

sub process_0003
{
	print "process_0003(): begin\n" if $debug;

	my $iff = shift;
	die 'bad $iff arg' if ref($iff) ne 'Iff';

	$iff->enterForm("0003");

	$iff->walkIff(\&iffWalker_0003);

	$iff->exitForm("0003");

	print "process_0003(): end\n" if $debug;
}

# ----------------------------------------------------------------------

sub iffWalker_0003
{
	my $iff		  = shift;
	die 'bad iff arg' if ref($iff) ne 'Iff';

	my $blockName = shift;
	my $isChunk	  = shift;

	printf("iffWalker_0003(): %s=[%s]\n", $isChunk ? "chunk" : "form", $blockName) if $debug;

	# Process blocks we understand.
	if ($isChunk)
	{
		if ($blockName eq 'MSGN')
		{
			# Handle specifying linked MeshGeneratorTemplate assets.
			while ($iff->getChunkLengthLeft() > 0)
			{
				my $meshGeneratorTemplateName = $iff->read_string();
				CustomizationVariableCollector::logAssetLink($treeFileRelativeName, $meshGeneratorTemplateName);
			}
		}
	}

	# Keep traversing.
	return 1;
}

# ======================================================================

1;
