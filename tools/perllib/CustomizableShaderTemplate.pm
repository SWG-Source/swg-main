# ======================================================================
# CustomizableShaderTemplate.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package CustomizableShaderTemplate;
use strict;

use CustomizationVariableCollector;
use Iff;

# ======================================================================
# CustomizableShaderTemplate potentially-public variables.
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
# CustomizableShaderTemplate private variables.
# ======================================================================

my $debug = 0;
my $treeFileRelativeName;

# ======================================================================
# CustomizableShaderTemplate public functions.
# ======================================================================

sub install
{
	# Register handler with CustomizationVariableCollector
	CustomizationVariableCollector::registerHandler("CSHD", \&processIff);
}

# ======================================================================
# CustomizableShaderTemplate private functions
# ======================================================================

sub processIff
{
	# Process args.
	my $iff = shift;
	die "bad iff arg specified" if ref($iff) ne "Iff";

	$treeFileRelativeName = shift;
	die "bad tree file relative name" if !defined($treeFileRelativeName);
	print "CustomizableShaderTemplate: processing file [$treeFileRelativeName]\n" if $debug;

	# Ensure we're in the proper form.
	return 0 unless $iff->getCurrentName() eq "CSHD";

	$iff->enterForm("CSHD");
	{
		my $version = $iff->getCurrentName();
		if ($version eq "0001")
		{
			process_0001($iff);
		}
		else
		{
			print STDERR "CustomizableShaderTemplate: unsupported version tag [$version].";
			return 0;
		}
	}
	$iff->exitForm("CSHD");

	print "CustomizableShaderTemplate: finished processing file [$treeFileRelativeName]\n" if $debug;

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
	my $iff = shift;
	die 'bad iff arg' if ref($iff) ne 'Iff';

	my $blockName = shift;
	my $isChunk	  = shift;

	printf("iffWalker_0001(): %s=[%s]\n", $isChunk ? "chunk" : "form", $blockName) if $debug;

	# Process blocks we understand.
	if ($isChunk)
	{
		if ($blockName eq 'AMCL')
		{
			# Handle material ambient color.
			my $variableShortName = $iff->read_string();
			my $variableIsPrivate = $iff->read_uint8();
			my $palettePathName	  = $iff->read_string();
			my $defaultIndex	  = $iff->read_uint32();

			my $variableFullName  = ($variableIsPrivate ? '/private/' : '/shared_owner/') . $variableShortName;
			CustomizationVariableCollector::logPaletteColorVariable($treeFileRelativeName, $variableFullName, $palettePathName, $defaultIndex);
		}
		elsif ($blockName eq 'DFCL')
		{
			# Handle material diffuse color.
			my $variableShortName = $iff->read_string();
			my $variableIsPrivate = $iff->read_uint8();
			my $palettePathName	  = $iff->read_string();
			my $defaultIndex	  = $iff->read_uint32();

			my $variableFullName  = ($variableIsPrivate ? '/private/' : '/shared_owner/') . $variableShortName;
			CustomizationVariableCollector::logPaletteColorVariable($treeFileRelativeName, $variableFullName, $palettePathName, $defaultIndex);
		}
		elsif ($blockName eq 'EMCL')
		{
			# Handle material emissive color.
			my $variableShortName = $iff->read_string();
			my $variableIsPrivate = $iff->read_uint8();
			my $palettePathName	  = $iff->read_string();
			my $defaultIndex	  = $iff->read_uint32();

			my $variableFullName  = ($variableIsPrivate ? '/private/' : '/shared_owner/') . $variableShortName;
			CustomizationVariableCollector::logPaletteColorVariable($treeFileRelativeName, $variableFullName, $palettePathName, $defaultIndex);
		}
		elsif ($blockName eq 'PAL ')
		{
			# Handle TextureFactor customization
			my $variableShortName = $iff->read_string();
			my $variableIsPrivate = $iff->read_uint8();
			$iff->skipBytes(4);
			my $palettePathName	  = $iff->read_string();
			my $defaultIndex	  = $iff->read_uint32();

			my $variableFullName  = ($variableIsPrivate ? '/private/' : '/shared_owner/') . $variableShortName;
			CustomizationVariableCollector::logPaletteColorVariable($treeFileRelativeName, $variableFullName, $palettePathName, $defaultIndex);
		}

		elsif ($blockName eq 'TX1D')
		{
			$iff->skipBytes(6);
			my $rangeMaxExclusive = $iff->read_uint16();
			my $variableShortName = $iff->read_string();
			my $variableIsPrivate = $iff->read_uint8();
			my $defaultValue	  = $iff->read_uint16();

			my $rangeMinInclusive = 0;
			my $variableFullName  = ($variableIsPrivate ? '/private/' : '/shared_owner/') . $variableShortName;
			CustomizationVariableCollector::logBasicRangedIntVariable($treeFileRelativeName, $variableFullName, $rangeMinInclusive, $rangeMaxExclusive, $defaultValue);
		}
	}

	# Keep traversing.
	return 1;
}

# ======================================================================

1;
