# ======================================================================
# MeshAppearanceTemplate.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package MeshAppearanceTemplate;
use strict;

use CustomizationVariableCollector;
use Iff;

# ======================================================================
# MeshAppearanceTemplate potentially-public variables.
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
# MeshAppearanceTemplate private variables.
# ======================================================================

my $debug = 0;
my $treeFileRelativeName;

# ======================================================================
# MeshAppearanceTemplate public functions.
# ======================================================================

sub install
{
	# Register handler with CustomizationVariableCollector
	CustomizationVariableCollector::registerHandler("MESH", \&processIff);
}

# ======================================================================
# MeshAppearanceTemplate private functions
# ======================================================================

sub processIff
{
	# Process args.
	my $iff = shift;
	die "bad iff arg specified" if ref($iff) ne "Iff";

	$treeFileRelativeName = shift;
	die "bad tree file relative name" if !defined($treeFileRelativeName);
	print "MeshAppearanceTemplate: processing file [$treeFileRelativeName]\n" if $debug;

	# Ensure we're in the proper form.
	return 0 unless $iff->getCurrentName() eq "MESH";

	$iff->enterForm("MESH");
	{
		my $version = $iff->getCurrentName();
		if ($version =~ m/^000[2-5]$/)
		{
			process_0002_0005($iff);
		}
		else
		{
			print STDERR "MeshAppearanceTemplate: unsupported version tag [$version].";
			return 0;
		}
	}
	$iff->exitForm("MESH");

	print "MeshAppearanceTemplate: finished processing file [$treeFileRelativeName]\n" if $debug;

	# Success.
	return 1;
}

# ----------------------------------------------------------------------

sub process_0002_0005
{
	print "process_0002_0005(): begin\n" if $debug;

	my $iff = shift;
	die 'bad $iff arg' if ref($iff) ne 'Iff';

	$iff->enterForm();

	$iff->walkIff(\&iffWalker_0002_0005);

	$iff->exitForm();

	print "process_0002_0005(): end\n" if $debug;
}

# ----------------------------------------------------------------------

sub iffWalker_0002_0005
{
	my $iff		  = shift;
	die 'bad iff arg' if ref($iff) ne 'Iff';

	my $blockName = shift;
	my $isChunk	  = shift;

	printf("iffWalker_0002_0005(): %s=[%s]\n", $isChunk ? "chunk" : "form", $blockName) if $debug;

	# Process blocks we understand.
	if ($isChunk)
	{
		if ($blockName eq 'NAME')
		{
			# Handle specifying linked shader templates.
			my $shaderTemplateName = $iff->read_string();
			CustomizationVariableCollector::logAssetLink($treeFileRelativeName, $shaderTemplateName);
		}
	}

	# Keep traversing.
	return 1;
}

# ======================================================================

1;
