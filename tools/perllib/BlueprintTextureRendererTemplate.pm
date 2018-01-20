# ======================================================================
# BlueprintTextureRendererTemplate.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package BlueprintTextureRendererTemplate;
use strict;

use CustomizationVariableCollector;
use Iff;

# ======================================================================
# BlueprintTextureRendererTemplate potentially-public variables.
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
# BlueprintTextureRendererTemplate private variables.
# ======================================================================

my $debug = 0;
my $treeFileRelativeName;

# ======================================================================
# BlueprintTextureRendererTemplate public functions.
# ======================================================================

sub install
{
	# Register handler with CustomizationVariableCollector
	CustomizationVariableCollector::registerHandler("BTRT", \&processIff);
}

# ======================================================================
# BlueprintTextureRendererTemplate private functions
# ======================================================================

sub processIff
{
	# Process args.
	my $iff = shift;
	die "bad iff arg specified" if ref($iff) ne "Iff";

	$treeFileRelativeName = shift;
	die "bad tree file relative name" if !defined($treeFileRelativeName);
	print "BlueprintTextureRendererTemplate: processing file [$treeFileRelativeName]\n" if $debug;

	# Ensure we're in the proper form.
	return 0 unless $iff->getCurrentName() eq "BTRT";

	$iff->enterForm("BTRT");
	{
		my $version = $iff->getCurrentName();
		if ($version eq "0001")
		{
			process_0001($iff);
		}
		else
		{
			print STDERR "BlueprintTextureRendererTemplate: unsupported version tag [$version].";
			return 0;
		}
	}
	$iff->exitForm("BTRT");

	print "BlueprintTextureRendererTemplate: finished processing file [$treeFileRelativeName]\n" if $debug;

	# Success.
	return 1;
}

# ----------------------------------------------------------------------

sub process_0001
{
	print "process_0001(): begin\n" if $debug;

	my $iff = shift;
	die 'bad $iff arg' if ref($iff) ne 'Iff';

	$iff->enterForm("0001");

	$iff->walkIff(\&iffWalker_0001);

	$iff->exitForm("0001");

	print "process_0001(): end\n" if $debug;
}

# ----------------------------------------------------------------------

sub iffWalker_0001
{
	my $iff		  = shift;
	die 'bad iff arg' if ref($iff) ne 'Iff';

	my $blockName = shift;
	my $isChunk	  = shift;

	printf("iffWalker_0001(): %s=[%s]\n", $isChunk ? "chunk" : "form", $blockName) if $debug;

	# Process blocks we understand.
	if ($isChunk)
	{
		if ($blockName eq 'STFP')
		{
			# Handle SetShaderTextureFactorFromPalette: palettized variable.
			$iff->skipBytes(6);
			my $palettePathName	  = $iff->read_string();
			my $variableShortName = $iff->read_string();
			my $variableIsPrivate = $iff->read_uint8();
			
			my $defaultIndex = 0;

			my $variableFullName  = ($variableIsPrivate ? '/private/' : '/shared_owner/') . $variableShortName;
			CustomizationVariableCollector::logPaletteColorVariable($treeFileRelativeName, $variableFullName, $palettePathName, $defaultIndex);
		}
		elsif ($blockName eq 'SST1')
		{
			# Handle SetShaderTexture1d: ranged int variable.
			$iff->skipBytes(12);
			my $variableShortName = $iff->read_string();
			my $rangeMaxExclusive = $iff->read_uint32();

			my $variableIsPrivate = 1;
			my $rangeMinInclusive = 0;
			my $defaultIndex	  = 0;

			my $variableFullName  = ($variableIsPrivate ? '/private/' : '/shared_owner/') . $variableShortName;
			CustomizationVariableCollector::logBasicRangedIntVariable($treeFileRelativeName, $variableFullName, $rangeMinInclusive, $rangeMaxExclusive, $defaultIndex);
		}
		elsif ($blockName eq 'SST2')
		{
			die "-TRF- need to implement SST2 parsing in BlueprintTextureRendererTemplate.pm";
		}
		elsif ($blockName eq 'STF ')
		{
			die "-TRF- need to implement STF parsing in BlueprintTextureRendererTemplate.pm";
		}
		elsif ($blockName eq 'STFA')
		{
			die "-TRF- need to implement STFA parsing in BlueprintTextureRendererTemplate.pm";
		}
	}
	else
	{
		# Processing a form.
		if ($blockName eq 'SHTM')
		{
			$iff->enterChunk("INFO");
			my $shaderTemplateCount = $iff->read_uint32();
			$iff->exitChunk("INFO");

			for (my $i = 0; $i < $shaderTemplateCount; ++$i)
			{
				$iff->enterChunk("NAME");

				my $shaderTemplateName = $iff->read_string();
				CustomizationVariableCollector::logAssetLink($treeFileRelativeName, $shaderTemplateName);

				$iff->exitChunk("NAME");
			}

			# We've processed the form, don't let walker try to traverse into it, but keep traversing the rest.
			return 0;
		}
	}

	# Keep traversing.
	return 1;
}

# ======================================================================

1;
