# ======================================================================
# SkeletalMeshGeneratorTemplate.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package SkeletalMeshGeneratorTemplate;
use strict;

use CustomizationVariableCollector;
use Iff;

# ======================================================================
# SkeletalMeshGeneratorTemplate potentially-public variables.
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
# SkeletalMeshGeneratorTemplate private variables.
# ======================================================================

my $debug = 0;
my $treeFileRelativeName;

# ======================================================================
# SkeletalMeshGeneratorTemplate public functions.
# ======================================================================

sub install
{
	# Register handler with CustomizationVariableCollector
	CustomizationVariableCollector::registerHandler("SKMG", \&processIff);
}

# ======================================================================
# SkeletalMeshGeneratorTemplate private functions
# ======================================================================

sub processIff
{
	# Process args.
	my $iff = shift;
	die "bad iff arg specified" if ref($iff) ne "Iff";

	$treeFileRelativeName = shift;
	die "bad tree file relative name" if !defined($treeFileRelativeName);
	print "SkeletalMeshGeneratorTemplate: processing file [$treeFileRelativeName]\n" if $debug;

	# Ensure we're in the proper form.
	return 0 unless $iff->getCurrentName() eq "SKMG";

	$iff->enterForm("SKMG");
	{
		my $version = $iff->getCurrentName();
		if ($version eq "0003")
		{
			process_0003($iff);
		}
		elsif ($version eq "0004")
		{
			process_0004($iff);
		}
		else
		{
			print STDERR "SkeletalMeshGeneratorTemplate: unsupported version tag [$version].";
			return 0;
		}
	}
	$iff->exitForm("SKMG");

	# Handle special cases.	 mon_f_body* and trn_f_body* need to export a "fake"
	# variable that they don't really use.	/shared_owner/blend_flat_chest with
	# a range of 255 - 256 and default 255 must be used.  Generate it here.
	# This causes female clothing to take on the appropriate value for the species.
	if ($treeFileRelativeName =~ m/(trn|mon)_f_body/)
	{
		my $variableFullName = '/shared_owner/blend_flat_chest';
		my $rangeMinInclusive = 255;
		my $rangeMaxExclusive = 256;
		my $defaultValue = 255;
		CustomizationVariableCollector::logBasicRangedIntVariable($treeFileRelativeName, $variableFullName, $rangeMinInclusive, $rangeMaxExclusive, $defaultValue);
	}

	print "SkeletalMeshGeneratorTemplate: finished processing file [$treeFileRelativeName]\n" if $debug;

	# @todo: remove this.
	# exit -100;

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
	$iff->walkIff(\&iffWalker_0003_0004);
	$iff->exitForm("0003");

	print "process_0003(): end\n" if $debug;
}

# ----------------------------------------------------------------------

sub process_0004
{
	print "process_0004(): begin\n" if $debug;

	my $iff = shift;
	die 'bad $iff arg' if ref($iff) ne 'Iff';

	$iff->enterForm("0004");
	$iff->walkIff(\&iffWalker_0003_0004);
	$iff->exitForm("0004");

	print "process_0004(): end\n" if $debug;
}

# ----------------------------------------------------------------------

sub iffWalker_0003_0004
{
	my $iff = shift;
	die 'bad iff arg' if ref($iff) ne 'Iff';

	my $blockName = shift;
	my $isChunk	  = shift;

	printf("iffWalker_0003(): %s=[%s]\n", $isChunk ? "chunk" : "form", $blockName) if $debug;

	# Process blocks we understand.
	if ($isChunk)
	{
		if ($blockName eq 'TRT ')
		{
			# Capture texture renderer template linkage info.
			my $textureRendererTemplateName = $iff->read_string();
			CustomizationVariableCollector::logAssetLink($treeFileRelativeName, $textureRendererTemplateName);
		}
	}
	else
	{
		# Processing a form.
		if ($blockName eq 'BLT ')
		{
			# Process the blend target.
			$iff->enterChunk("INFO");

			$iff->skipBytes(8);
			my $variableShortName = $iff->read_string();

			$iff->exitChunk("INFO");

			# Check for some common variable naming errors.
			if (!($variableShortName =~ m/^blend_/) ||
				($variableShortName =~ m/shape$/i) ||
				($variableShortName =~ m/skincluster/i) ||
				($variableShortName =~ m/[A-Za-z]\d/) ||
				($variableShortName =~ m/\dshap/i) ||
				($variableShortName =~ m/sizxe/i) ||
				($variableShortName =~ m/_$/i) ||
				($variableShortName =~ m/(^|_)([a-zA-Z]+)_\2/)
				)
			{
				# Ignore this variable --- it is not properly named.  Keep processing.
				print STDERR "MGN warning:$treeFileRelativeName malformed blend shape variable name $variableShortName will be ignored.\n";
				return 1;
			}

			my $variableFullName = '/shared_owner/' . $variableShortName;

			# Determine range based on variable name and source asset name.
			my $rangeMinInclusive = 0;
			my $rangeMaxExclusive = 256;
			my $defaultValue	  = 0;

			# Handle breasts.
			if ($variableShortName =~ m/blend_flat_chest/)
			{
				if ($treeFileRelativeName =~ m!/(trn|mon)_!)
				{
					# Trandoshan female and Mon Calamari female don't allow breasts.
					# They may only be 255.
					$rangeMinInclusive = 255;
					$rangeMaxExclusive = 256;
					$defaultValue = 255;
				}
				elsif ($treeFileRelativeName =~ m/_f_body/)
				{
					# All other species bodies allow this breast range.
					$rangeMinInclusive = -155;
					$rangeMaxExclusive = 156;
				}
				else
				{
					# All else is assumed to be clothing and must be able to work the full range.
					$rangeMinInclusive = -155;
					$rangeMaxExclusive =  256;
				}
			}

			# Declare that we use this blend shape variable.
			CustomizationVariableCollector::logBasicRangedIntVariable($treeFileRelativeName, $variableFullName, $rangeMinInclusive, $rangeMaxExclusive, $defaultValue);

			# Tell caller we don't want to process anything else at this level but we do still want to traverse.
			return 0;
		}
		elsif ($blockName eq 'PSDT')
		{
			# Capture shader template linkage info.
			$iff->enterChunk('NAME');
			my $shaderTemplateName = $iff->read_string();
			$iff->exitChunk('NAME');

			CustomizationVariableCollector::logAssetLink($treeFileRelativeName, $shaderTemplateName);

			# Tell caller we don't want to process anything else at this level but we do still want to traverse.
			return 0;
		}
	}

	# Keep traversing.
	return 1;
}

# ======================================================================

1;
