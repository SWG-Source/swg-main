# ======================================================================
# LodMeshGeneratorTemplate.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package LodMeshGeneratorTemplate;
use strict;

use CustomizationVariableCollector;
use Iff;

# ======================================================================
# LodMeshGeneratorTemplate potentially-public variables.
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
# LodMeshGeneratorTemplate private variables.
# ======================================================================

my $debug = 0;
my $treeFileRelativeName;

# ======================================================================
# LodMeshGeneratorTemplate public functions.
# ======================================================================

sub install
{
	# Register handler with CustomizationVariableCollector
	CustomizationVariableCollector::registerHandler("MLOD", \&processIff);
}

# ======================================================================
# LodMeshGeneratorTemplate private functions
# ======================================================================

sub processIff
{
	# Process args.
	my $iff = shift;
	die "bad iff arg specified" if ref($iff) ne "Iff";

	$treeFileRelativeName = shift;
	die "bad tree file relative name" if !defined($treeFileRelativeName);
	print "LodMeshGeneratorTemplate: processing file [$treeFileRelativeName]\n" if $debug;

	# Ensure we're in the proper form.
	return 0 unless $iff->getCurrentName() eq "MLOD";

	$iff->enterForm("MLOD");
	{
		my $version = $iff->getCurrentName();
		if ($version eq "0000")
		{
			process_0000($iff);
		}
		else
		{
			print STDERR "LodMeshGeneratorTemplate: unsupported version tag [$version].";
			return 0;
		}
	}
	$iff->exitForm("MLOD");

	print "LodMeshGeneratorTemplate: finished processing file [$treeFileRelativeName]\n" if $debug;

	# Success.
	return 1;
}

# ----------------------------------------------------------------------

sub process_0000
{
	print "process_0000(): begin\n" if $debug;

	my $iff = shift;
	die 'bad $iff arg' if ref($iff) ne 'Iff';

	$iff->enterForm("0000");

	$iff->walkIff(\&iffWalker_0000);

	$iff->exitForm("0000");

	print "process_0000(): end\n" if $debug;
}

# ----------------------------------------------------------------------

sub iffWalker_0000
{
	my $iff		  = shift;
	die 'bad iff arg' if ref($iff) ne 'Iff';

	my $blockName = shift;
	my $isChunk	  = shift;

	printf("iffWalker_0000(): %s=[%s]\n", $isChunk ? "chunk" : "form", $blockName) if $debug;

	# Process blocks we understand.
	if ($isChunk)
	{
		if ($blockName eq 'NAME')
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
