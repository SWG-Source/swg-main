# ======================================================================
# LightsaberAppearanceTemplate.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package LightsaberAppearanceTemplate;
use strict;

use CustomizationVariableCollector;
use Iff;

# ======================================================================
# LightsaberAppearanceTemplate potentially-public variables.
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
# LightsaberAppearanceTemplate private variables.
# ======================================================================

my $debug = 0;
my $treeFileRelativeName;

# ======================================================================
# LightsaberAppearanceTemplate public functions.
# ======================================================================

sub install
{
	# Register handler with CustomizationVariableCollector
	CustomizationVariableCollector::registerHandler("LSAT", \&processIff);
}

# ======================================================================
# LightsaberAppearanceTemplate private functions
# ======================================================================

sub processIff
{
	# Process args.
	my $iff = shift;
	die "bad iff arg specified" if ref($iff) ne "Iff";

	$treeFileRelativeName = shift;
	die "bad tree file relative name" if !defined($treeFileRelativeName);
	print "LightsaberAppearanceTemplate: processing file [$treeFileRelativeName]\n" if $debug;

	# Ensure we're in the proper form.
	return 0 unless $iff->getCurrentName() eq "LSAT";

	$iff->enterForm("LSAT");
	{
		my $version = $iff->getCurrentName();
		if ($version eq "0000")
		{
			process_0000($iff);
		}
		else
		{
			print STDERR "LightsaberAppearanceTemplate: unsupported version tag [$version].";
			return 0;
		}
	}
	$iff->exitForm("LSAT");

	print "LightsaberAppearanceTemplate: finished processing file [$treeFileRelativeName]\n" if $debug;

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
		if ($blockName eq 'BASE')
		{
			# Handle specifying linked appearanceTemplate assets for blade hilt.
			while ($iff->getChunkLengthLeft() > 0)
			{
				my $appearanceTemplateName = $iff->read_string();
				CustomizationVariableCollector::logAssetLink($treeFileRelativeName, $appearanceTemplateName);
			}
		}
		elsif ($blockName eq 'SHDR')
		{
			# Handle specifying linked shader name used for blade.
			my $shaderTemplateName = $iff->read_string();
			CustomizationVariableCollector::logAssetLink($treeFileRelativeName, $shaderTemplateName);
		}
	}

	# HACK???
	# The C++ code for the Lightsaber appearance depends on this Customization variable to implement
	# the alternate shader scheme (used for lava sabers). This variable is not referenced by any other
	# kind of asset, but if the CustomizationVariableCollector doesn't find it, it cannot be used.
	# We could make it part of the LightsaberAppearanceTemplate, but it would effectively be hard-coded there,
	# and never change across instances of that template. So I am hard-coding it here, to express the 
	# code's implicit dependency.
	# Upping this variable from 2 to 16 for Permafrost saber and any others we think of, so no one needs
	# to find this crazy line of code again. - Matt B. 9/18/08
	CustomizationVariableCollector::logBasicRangedIntVariable($treeFileRelativeName, "private/alternate_shader_blade", 0, 16, 0);


	# Keep traversing.
	return 1;
}

# ======================================================================

1;
