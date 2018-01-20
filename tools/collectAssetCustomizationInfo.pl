# ======================================================================
# collectAssetCustomizationInfo.pl
# Copyright 2003, Sony Online Entertainment, Inc.
# All rights reserved.
# ======================================================================

use strict;

use AppearanceTemplate;
use BlueprintTextureRendererTemplate;
use ComponentAppearanceTemplate;
use CustomizableShaderTemplate;
use CustomizationVariableCollector;
use DetailAppearanceTemplate;
use LightsaberAppearanceTemplate;
use LodMeshGeneratorTemplate;
use MeshAppearanceTemplate;
use PortalAppearanceTemplate;
use SkeletalAppearanceTemplate;
use SkeletalMeshGeneratorTemplate;
use SwitchShaderTemplate;
use TreeFile;
use VehicleCustomizationVariableGenerator;

# ======================================================================

my $branch = "current";
my $debug = 0;
my $treeFileLookupDataFile;

# ======================================================================

sub printUsage
{
	print "Usage:\n";
	print "\tperl collectAssetCustomizationInfo.pl [-d] [-h] [-b <branch>] -t <treefile lookup filename>\n";
	print "\n";
	print "-d: if specified, turns on debugging info (Default: off)\n";
	print "-h: print this help\n";
	print "-t: loads the TreeFile lookup data from the specified filename\n";
}

# ----------------------------------------------------------------------

sub processCommandLineArgs
{
	my $printHelp = 0;
	my $requestedHelp = 0;

	# Grab options from commandline.
	while ((scalar @_) && !$printHelp)
	{
		if ($_[0] =~ m/^-h/)
		{
			$printHelp	   = 1;
			$requestedHelp = 1;
		}
		elsif ($_[0] =~ m/^-b/)
		{
			shift;
			$branch = $_[0];
			if (!defined($branch))
			{
				print "User must specify a branch name after the -t option, printing help.\n";
				$printHelp = 1;
			}
			else
			{
				print "\$branch=[$branch]\n" if $debug;
			}
		}
		elsif ($_[0] =~ m/^-d/)
		{
			$debug = 1;
		}
		elsif ($_[0] =~ m/^-t/)
		{
			shift;
			$treeFileLookupDataFile = $_[0];
			if (!defined($treeFileLookupDataFile))
			{
				print "User must specify a treefile lookup data filename after the -t option, printing help.\n";
				$printHelp = 1;
			}
			else
			{
				print "\$treeFileLookupDataFile=[$treeFileLookupDataFile]\n" if $debug;
			}
		}
		else
		{
			print "Unsupported option [$_[0]], printing help.\n";
			$printHelp = 1;
		}

		# Shift past current argument.
		shift;
	}

	# Check if we're missing anything required.
	if (!$requestedHelp)
	{
		if (!defined($treeFileLookupDataFile))
		{
			print "No TreeFile lookup data file specified, printing usage info.\n";
			$printHelp = 1;
		}
	}

	if ($printHelp)
	{
		printUsage();
		exit ($requestedHelp ? 0 : -1);
	}
}

# ----------------------------------------------------------------------

sub initialize
{
	# Initialize data handlers.
	&AppearanceTemplate::install();
	&BlueprintTextureRendererTemplate::install();
	&ComponentAppearanceTemplate::install();
	&CustomizableShaderTemplate::install();
	&DetailAppearanceTemplate::install();
	&LightsaberAppearanceTemplate::install();
	&LodMeshGeneratorTemplate::install();
	&MeshAppearanceTemplate::install();
	&PortalAppearanceTemplate::install();
	&SkeletalAppearanceTemplate::install();
	&SkeletalMeshGeneratorTemplate::install();
	&SwitchShaderTemplate::install();
	&VehicleCustomizationVariableGenerator::install();

	# Open the TreeFile lookup datafile.
	my $dataFileHandle;
	die "Failed to open [$treeFileLookupDataFile]: $!" unless open($dataFileHandle, "< " . $treeFileLookupDataFile);

	# Initialize the treefile.
	TreeFile::loadFileLookupTable($dataFileHandle);

	# Close the TreeFile lookup datafile.
	die "Failed to close [$treeFileLookupDataFile]: $!" unless close($dataFileHandle);
}

# ======================================================================
# Main Program
# ======================================================================

# Handle command line.
processCommandLineArgs(@ARGV);

# Initialize subsystems (e.g. TreeFile)
initialize();

# Setup the list of patterns to match against
# TreeFile-relative filenames.	Any files in the TreeFile system 
# that match one of these patterns will be processed by the
# CustomizationVariableCollector.

my @processFilePatterns =
	(
	 '^texturerenderer/.+\.trt$', '^shader/.+\.sht$',
	 '^appearance/.+\.(apt|cmp|lmg|lod|lsb|mgn|msh|sat|pob)$'
# ---
# TEST ENTRIES: don't include these for real processing, used to test formats one-at-a-time.
# ---
#	 '^appearance/.+\.sat$'
#	 '^appearance/.+\.mgn$'
#	  '^shader/.+\.sht$'
#	  '^appearance/.+\.lsb$'
#	  '^appearance/.+\.lod$'
#	  '^appearance/.+\.apt$'
#	 '^appearance/.+\.msh$'
#	 '^appearance/.+\.cmp$'
# ---
	 );

CustomizationVariableCollector::collectData(@processFilePatterns);

# Handle vehicle customization steps that cannot be handled by analyzing IFF file contents.
VehicleCustomizationVariableGenerator::collectData($branch);
