# =====================================================================
# fixupClientBakedWearableData.pl
# Copyright 2003, Sony Online Entertainment, Inc.
# All rights reserved.
# =====================================================================

# =====================================================================

# This program is based on buildAssetCustomizationManagerData.pl.  It
# is intended to be a one-shot program used to convert the
# client-baked wearable data in the client data files to not specify
# full variable declaration information.  The program does the
# following:

# Accept a list of directories to recursively scan for CDF mif files.

# For each mif source file, do the following:

# Remove any UsePaletteCustomization or UseRangedIntCustomization
# declaration, taking not of the variable name and default value
# given.

# For the variable name, lookup if the variable is provided by any of
# the MeshGenerator assets specified in the wearable, and if so, find
# the art asset's default value.

# If the variable is not used by the LMG or any dependencies, nothing
# replaces the Use* declaration.  It was bogus and any intended
# default is pointless to preserve since it can't affect anything.

# If the variable is used and the value specified as the default in the
# Use* declaration matches the default provided by the artist, nothing
# replaces the use declaration since the object will get the default
# without specifying anything.

# If the variable is used and the value specified within the Use*
# declaration specifies an out-of-range value, nothing replaces the
# use declaration since the intent of the value can't be determined
# and we might as well do the thing that reduced data size in its
# place.

# If the variable is used and the value specified within the Use*
# declaration is within range but is different than the artist
# default, emit a WearableCustomizationSetInt(variableName, intValue).
# This declaration will override the default value of the
# customization variable.

# =====================================================================

use strict;

use Crc;
use Cwd;
use File::Find;
use File::Spec;
use File::Temp;
use TreeFile;

# =====================================================================

my $debug							= 0;
my $debugLinesPerOutputTick			= 100;
my $examineProcessedData			= 0;

my $assetLinkLineCount				= 0;
my $basicRangedIntVariableLineCount = 0;
my $paletteColorVariableLineCount	= 0;

my @directoriesToScan;
my $rawInputFileName;
my $treeFileLookupFileName;

my %assetIdByNameMap;
my %assetNameByCrcMap;
my %defaultIdByValueMap;
my %intRangeByIntRangeIdMap;
my %rangeIdByKeyMap;
my %rangeTypeByIdMap;
my %usedAssetIdByUserMap;
my %variableIdByNameMap;
my %variableUsageIdByAssetIdMap;
my %variableUsageIdByKeyMap;

my $maxAssignedAssetId		   = 0;
my $maxAssignedDefaultId	   = 0;
my $maxAssignedIntRangeId	   = 0;
my $maxAssignedPaletteId	   = 0;
my $maxAssignedRangeId		   = 0;
my $maxAssignedVariableId	   = 0;
my $maxAssignedVariableUsageId = 0;

# Data used specifically for CDF fixup process.
my $cdfDecreasedByteCount	   = 0;
my $cdfTotalByteCount		   = 0;
my $checkedCdfCount			   = 0;
my $fixedCdfCount			   = 0;

my $ignoreMissingPalettes	   = 0;
my $p4EditRetryCount		   = 10;

my %assetNameByIdMap;
my %defaultValueByIdMap;
my %paletteEntryCountByName;
my %rangeKeyByIdMap;
my %variableNameByIdMap;
my %variableUsageKeyByIdMap;

my $currentCdfFileName;

# =====================================================================

sub printUsage
{
	print "Usage: \n";
	print "	 perl fixupClientBakedWearableData.pl [-h]\n";
	print "	 perl fixupClientBakedWearableData.pl [-d] -i <rawInfoFile.dat> \n";
	print "	   [-e] -t <treefile-xlat-file.dat> directory [directory ...]\n";
	print "\n";
	print "Options:\n";
	print "	 -d: enable verbose debugging information\n";
	print "	 -e: examine (dump) processed data on STDOUT\n";
	print "	 -h: print this help\n";
	print "	 -i: the raw data output file from collectAssetCustomizationData.pl\n";
	print "	 -p: ignore missing palettes\n";
	print "	 -t: the treefile lookup data file\n";
	print "\n";
	print "		 Directories given will be scanned recursively for client data files\n";
	print "		 ending in the extension .mif.	CDF source files will be p4 edited,\n";
	print "		 cleaned up and compiled if any modifications are needed.\n";
}

# ----------------------------------------------------------------------

sub processCommandLine
{
	# Process command line options.
	my $requestHelp = 0;
	my $printHelp	= 0;

	for (; (@_ > 0) && ($_[0] =~ m/^-(.*)$/); shift)
	{
		if ($1 eq 'd')
		{
			$debug = 1;
		}
		elsif ($1 eq 'e')
		{
			$examineProcessedData = 1;
			print "examineProcessedData=$examineProcessedData\n" if $debug;
		}
		elsif ($1 eq 'i')
		{
			shift;
			$rawInputFileName = $_[0];
			print "rawInputFileName=$rawInputFileName\n" if $debug;
		}
		elsif ($1 eq 'h')
		{
			$requestHelp = 1;
			$printHelp	 = 1;
		}
		elsif ($1 eq 'p')
		{
			$ignoreMissingPalettes = 1;
			print "ignoreMissingPalettes=1\n" if $debug;
		}
		elsif ($1 eq 't')
		{
			shift;
			$treeFileLookupFileName = $_[0];
			print "treeFileLookupFileName=$treeFileLookupFileName\n" if $debug;
		}
	}

	# Take remainder as directories to scan.
	foreach (@_)
	{
		# Record directory's absolute path.
		push @directoriesToScan, Cwd::abs_path($_);
	}

	if (!$requestHelp)
	{
		#-- Validate required parameters.

		# Make sure we have a raw input file specified.
		if (!defined($rawInputFileName) || (length($rawInputFileName) < 1))
		{
			print "No raw input filename specified, specify with -i switch.\n";
			$printHelp = 1;
		}

		if (!defined($treeFileLookupFileName) || (length($treeFileLookupFileName) < 1))
		{
			print "No tree file lookup filename specified, specify with -t switch.\n";
			$printHelp = 1;
		}


		# Make sure we have at least one directory.
		if (@directoriesToScan < 1)
		{
			print "No directories specified for scanning, printing help.\n";
			$printHelp = 1;
		}
	}

	if ($printHelp)
	{
		printUsage();
		exit -1;
	}
}

# ----------------------------------------------------------------------

sub getNewAssetId
{
	# For now assign next higher unused number.	 Once we figure out how
	# many bits we really want to use, I'll want to come back and look
	# for holes in id space and fill those up.	Maybe find holes at
	# startup and add to an 'asset id holes' list that we pull from.
	my $newAssetId = $maxAssignedAssetId + 1;
	++$maxAssignedAssetId;

	return $newAssetId;
}

# ----------------------------------------------------------------------

sub getNewVariableId
{
	my $newVariableId = $maxAssignedVariableId + 1;
	++$maxAssignedVariableId;

	return $newVariableId;
}

# ----------------------------------------------------------------------

sub getNewVariableUsageId
{
	my $newVariableUsageId = $maxAssignedVariableUsageId + 1;
	++$maxAssignedVariableUsageId;

	return $newVariableUsageId;
}

# ----------------------------------------------------------------------

sub getNewDefaultId
{
	my $newDefaultId = $maxAssignedDefaultId + 1;
	++$maxAssignedDefaultId;

	return $newDefaultId;
}

# ----------------------------------------------------------------------

sub getNewRangeId
{
	my $newRangeId = $maxAssignedRangeId + 1;
	++$maxAssignedRangeId;

	return $newRangeId;
}

# ----------------------------------------------------------------------

sub getAssetId
{
	# Process args.
	my $assetName = shift;
	die "Bad asset name arg" if !defined($assetName);

	# Check if an asset id already has been assigned to this name.
	my $assetId = $assetIdByNameMap{$assetName};
	if (!defined($assetId))
	{
		# Check for a Crc dupe.	 We'll have a table mapping crc to internal asset it.
		my $crc				  = Crc::calculate($assetName);
		my $clashingAssetName = $assetNameByCrcMap{$crc};
		die "asset crc clash: same crc=$crc for asset name $assetName and $clashingAssetName" if defined($clashingAssetName);

		# Add crc entry.
		$assetNameByCrcMap{$crc} = $assetName;

		# Assign a new id.
		$assetId = getNewAssetId();
		$assetIdByNameMap{$assetName} = $assetId;
	}

	return $assetId;
}

# ----------------------------------------------------------------------

sub getVariableId
{
	# Process args.
	my $variableName = shift;
	die "Bad variable name arg" if !defined($variableName);

	# Check if a variable id already has been assigned to this name.
	my $variableId = $variableIdByNameMap{$variableName};
	if (!defined($variableId))
	{
		# Assign a new id.
		$variableId = getNewVariableId();
		$variableIdByNameMap{$variableName} = $variableId;
	}

	return $variableId;
}

# ----------------------------------------------------------------------

sub getDefaultId
{
	# Process args.
	my $defaultValue = shift;
	die "Bad default value arg" if !defined($defaultValue);

	# Check if a default id already has been assigned to this name.
	my $defaultId = $defaultIdByValueMap{$defaultValue};
	if (!defined($defaultId))
	{
		# Assign a new id.
		$defaultId = getNewDefaultId();
		$defaultIdByValueMap{$defaultValue} = $defaultId;
	}

	return $defaultId;
}

# ----------------------------------------------------------------------

sub getBasicRangedIntRangeId
{
	die "Bad number of args" if (@_ != 2);
	my $rangeKey = join(':', @_);

	# Both types of ranges operate off of the same rangeIdByKeyMap.
	my $rangeId = $rangeIdByKeyMap{$rangeKey};
	if (!defined($rangeId))
	{
		# Assign a new id.
		$rangeId = getNewRangeId();
		$rangeIdByKeyMap{$rangeKey} = $rangeId;
	}

	return $rangeId;
}

# ----------------------------------------------------------------------

sub getPaletteRangeId
{
	die "Bad number of args" if (@_ != 1);
	my $rangeKey = shift;
	
	# Both types of ranges operate off of the same rangeIdByKeyMap.
	my $rangeId = $rangeIdByKeyMap{$rangeKey};
	if (!defined($rangeId))
	{
		# Assign a new id.
		$rangeId = getNewRangeId();
		$rangeIdByKeyMap{$rangeKey} = $rangeId;
	}

	return $rangeId;
}

# ----------------------------------------------------------------------

sub getVariableUsageId
{
	die "Bad number of args" if (@_ != 3);
	my $key = join(':', @_);

	my $variableUsageId = $variableUsageIdByKeyMap{$key};
	if (!defined($variableUsageId))
	{
		# Assign a new id.
		$variableUsageId = getNewVariableUsageId();
		$variableUsageIdByKeyMap{$key} = $variableUsageId;
	}

	return $variableUsageId;
}

# ----------------------------------------------------------------------

sub processAssetLink
{
	# Validate arg count.
	die("Wrong argument count: ", join(':', @_)) if (@_ != 2);

	# Convert asset names to asset ids.
	my $userAssetId = getAssetId(shift);
	my $usedAssetId = getAssetId(shift);

	# Save asset usage info.
	if (exists $usedAssetIdByUserMap{$userAssetId})
	{
		# Add to ':'-separated list of used asset ids.
		$usedAssetIdByUserMap{$userAssetId} .= ':' . $usedAssetId;
	}
	else
	{
		# Initialize used asset id.
		$usedAssetIdByUserMap{$userAssetId} = $usedAssetId;
	}
}

# ----------------------------------------------------------------------

sub processBasicRangedIntVariable
{
	# Validate arg count.
	die("Wrong argument count: ", join(':', @_)) if (@_ != 5);

	# Get args.
	my $assetId			  = getAssetId(shift);
	my $variableId		  = getVariableId(shift);
	my $minValueInclusive = shift;
	my $maxValueExclusive = shift;
	my $defaultId		  = getDefaultId(shift);

	my $rangeId			  = getBasicRangedIntRangeId($minValueInclusive, $maxValueExclusive);
	
	# Add variableUsageId to the usage map for the asset.
	my $variableUsageId	  = getVariableUsageId($variableId, $rangeId, $defaultId);
	if (exists $variableUsageIdByAssetIdMap{$assetId})
	{
		# Append variable usage id to the map.
		$variableUsageIdByAssetIdMap{$assetId} .= ':' . $variableUsageId;
	}
	else
	{
		# Add new entry.
		$variableUsageIdByAssetIdMap{$assetId} = $variableUsageId;
	}
}

# ----------------------------------------------------------------------

sub processPaletteColorVariable
{
	# Validate arg count.
	die("Wrong argument count: ", join(':', @_)) if (@_ != 4);

	# Get args.
	my $assetId			  = getAssetId(shift);
	my $variableId		  = getVariableId(shift);
	my $rangeId			  = getPaletteRangeId(shift);
	my $defaultId		  = getDefaultId(shift);

	# Add variableUsageId to the usage map for the asset.
	my $variableUsageId	  = getVariableUsageId($variableId, $rangeId, $defaultId);
	if (exists $variableUsageIdByAssetIdMap{$assetId})
	{
		# Append variable usage id to the map.
		$variableUsageIdByAssetIdMap{$assetId} .= ':' . $variableUsageId;
	}
	else
	{
		# Add new entry.
		$variableUsageIdByAssetIdMap{$assetId} = $variableUsageId;
	}
}

# ----------------------------------------------------------------------

sub processRawInputData
{
	die "No raw input file specified, specify with -i switch" if !defined($rawInputFileName) || (length($rawInputFileName) < 1);

	print "Processing raw input file [$rawInputFileName].\n";

	my $skippedLineCount   = 0;
	my $debugTickLineCount = 0;

	my $inputFile;
	open($inputFile, "< " . $rawInputFileName) or die "Failed to open raw input file for reading: $!";

	while (<$inputFile>)
	{
		my $originalLine = $_;

		chomp();
		if (s/^L\s+//)
		{
			# Process asset linkage information.  Args are the user (main) asset and the used (subordinate,dependency) asset.
			processAssetLink(split /:/);
			++$assetLinkLineCount;

		}
		elsif (s/^I\s+//)
		{
			# Process a use case of a basic ranged int variable.
			processBasicRangedIntVariable(split /:/);
			++$basicRangedIntVariableLineCount;
		}
		elsif (s/^P\s+//)
		{
			# Process a use case of a palette color variable.
			processPaletteColorVariable(split /:/);
			++$paletteColorVariableLineCount;
		}
		else
		{
			++$skippedLineCount;
		}

		++$debugTickLineCount;
		if ($debug && ($debugTickLineCount >= $debugLinesPerOutputTick))
		{
			print STDERR ". ";
			$debugTickLineCount = 0;
		}
	}

	close($inputFile) or die "Failed to close raw input file: $!";

	# Print statistics.
	if ($debug)
	{
		print "\n";
		print "Input file processing statistics:\n";
		print "\tasset links:				 $assetLinkLineCount\n";
		print "\tbasic ranged int variables: $basicRangedIntVariableLineCount\n";
		print "\tpalette color variables:	 $paletteColorVariableLineCount\n";
		print "\tskipped lines:				 $skippedLineCount\n";
	}
}

# ----------------------------------------------------------------------

sub examineProcessedData
{
	print "max assigned variable counts:\n";
	print "maxAssignedAssetId=$maxAssignedAssetId\n";
	print "maxAssignedDefaultId=$maxAssignedDefaultId\n";
	print "maxAssignedRangeId=$maxAssignedRangeId\n";
	print "maxAssignedVariableId=$maxAssignedVariableId\n";
	print "maxAssignedVariableUsageId=$maxAssignedVariableUsageId\n";
	print "\n";

	print "assetIdByNameMap:\n";
	foreach my $key (sort keys %assetIdByNameMap)
	{
		print "\t$key=[$assetIdByNameMap{$key}]\n";
	}
	print "\n";

	print "assetNameByCrcMap:\n";
	foreach my $key (sort compare_uint32 keys %assetNameByCrcMap)
	{
		printf "\t%u=[$assetNameByCrcMap{$key}]\n", $key;
	}
	print "\n";

	print "defaultIdByValueMap:\n";
	foreach my $key (sort compare_uint32 keys %defaultIdByValueMap)
	{
		print "\t$key=[$defaultIdByValueMap{$key}]\n";
	}
	print "\n";

	print "rangeIdByKeyMap:\n";
	foreach my $key (sort keys %rangeIdByKeyMap)
	{
		print "\t$key=[$rangeIdByKeyMap{$key}]\n";
	}
	print "\n";

	print "usedAssetIdByUserMap:\n";
	foreach my $key (sort compare_uint32 keys %usedAssetIdByUserMap)
	{
		print "\t$key=[$usedAssetIdByUserMap{$key}]\n";
	}
	print "\n";

	print "variableIdByNameMap:\n";
	foreach my $key (sort keys %variableIdByNameMap)
	{
		print "\t$key=[$variableIdByNameMap{$key}]\n";
	}
	print "\n";

	print "variableUsageIdByAssetIdMap:\n";
	foreach my $key (sort compare_uint32 keys %variableUsageIdByAssetIdMap)
	{
		print "\t$key=[$variableUsageIdByAssetIdMap{$key}]\n";
	}
	print "\n";

	print "variableUsageIdByKeyMap:\n";
	foreach my $key (sort keys %variableUsageIdByKeyMap)
	{
		print "\t$key=[$variableUsageIdByKeyMap{$key}]\n";
	}
	print "\n";
}

# ---------------------------------------------------------------------

sub findFirstVariableUsage
{
	my $assetId		 = shift;
	my $variableId	 = shift;

	print "checking asset [$assetNameByIdMap{$assetId}] for variable [$variableNameByIdMap{$variableId}]\n" if $debug;

	# Check specified asset id for usage of specified variable.
	my $variableUsageIdsString = $variableUsageIdByAssetIdMap{$assetId};
	if (defined $variableUsageIdsString)
	{
		my @variableUsageIdArray   = split /:/, $variableUsageIdsString;
		foreach my $variableUsageId (@variableUsageIdArray)
		{
			my $variableUsageKey  = $variableUsageKeyByIdMap{$variableUsageId};
			my @variableUsageData = split /:/, $variableUsageKey;
			die "Bad variable usage data format, expecting 3 parts" if (@variableUsageData != 3);

			if ($variableUsageData[0] == $variableId)
			{
				print "found [$variableNameByIdMap{$variableId}] on [$assetNameByIdMap{$assetId}]\n" if $debug;
				return \@variableUsageData;
			}
		}
	}

	# Check linked assets of specified variable
	my $linkedAssetIdsString = $usedAssetIdByUserMap{$assetId};
	return undef if !defined($linkedAssetIdsString);

	my @linkedAssetIdArray = split /:/, $linkedAssetIdsString;
	foreach my $linkedAssetId (@linkedAssetIdArray)
	{
		my $result = findFirstVariableUsage($linkedAssetId, $variableId);
		return $result if defined($result);
	}

	return undef;
}

# ---------------------------------------------------------------------

sub clamp
{
	my $min   = shift;
	my $value = shift;
	my $max   = shift;

	$value = $max if ($value > $max);
	$value = $min if ($value < $min);

	return $value;
}

# ---------------------------------------------------------------------

sub getPaletteVariableInfo
{
	# Get args.
	my $meshAssetIdArrayRef = shift;
	my $variableName		= shift;
	my $palettePathName		= shift;   # this optionally can be undef() in which case palette name match validation doesn't occur.
	my $defaultIndex		= shift;

	# Variables for return state.
	my $definesVariable		= 0;
	my $samePalette			= 0;
	my $sameDefault			= 0;
	my $defaultWithinRange	= 0;
	my $clampedDefault      = 0;

	# Lookup variable id for variable name.
	my $variableId = $variableIdByNameMap{$variableName};
	if (defined($variableId))
	{
		# Find the first asset in the list that defines the variable.
		for (my $i = 0; ($i < @$meshAssetIdArrayRef) && !$definesVariable; ++$i)
		{
			# Check if this asset id defines the variable.
			my $assetId				  = $$meshAssetIdArrayRef[$i];
			my $variableUsageArrayRef = findFirstVariableUsage($assetId, $variableId);
			$definesVariable = 1 if defined($variableUsageArrayRef);
			
			if ($definesVariable)
			{
				# Get range info.
				my $rangeId	 = $$variableUsageArrayRef[1];
				my $rangeKey = $rangeKeyByIdMap{$rangeId};

				# Check if range is a palette.
				if ($rangeKey =~ m/:/)
				{
					# This isn't a palcolor variable: it probably is a basic ranged int variable.
					$definesVariable = 0;
				}
				else
				{
					# The range indicates this variable is a palette color variable.
					# Palette range keys are the palette pathname.
					my $matchPaletteVariable;

					if (!defined($palettePathName))
					{
						# Unknown if the caller-asserted palette name and the real palette name match.
						$samePalette = '?';

						# Use this palette color variable since the type is right and the variable name matches.
						$matchPaletteVariable = 1;
						print "CBW uses <unspecified palette>, variable uses [$rangeKey]\n" if $debug;
					}
					else
					{
						# Caller did assert the palette path name.  Check if they match.
						$samePalette = ($rangeKey eq $palettePathName) ? 1 : 0;
						$matchPaletteVariable = $samePalette;
						print "CBW uses palette [$palettePathName], variable uses [$rangeKey]\n" if $debug;
					}
					
					if ($matchPaletteVariable)
					{
						# Check the default info.
						my $defaultId = $$variableUsageArrayRef[2];
						$sameDefault = 1 if ($defaultValueByIdMap{$defaultId} == $defaultIndex);
						
						# Check if default is within range.
						my $paletteEntryCount = $paletteEntryCountByName{$rangeKey};
						if (!defined($paletteEntryCount))
						{
							emitCdfWarning("art data error: variable [$variableName] references an invalid palette [$rangeKey], can't validate palette range.");
							$defaultWithinRange = 0;
						}
						else
						{
							$defaultWithinRange = 1 if (defined($paletteEntryCount) && ($defaultIndex < $paletteEntryCount) && ($defaultIndex >= 0));
							emitCdfWarning(sprintf("user specified new variable override for pal color [$variableName] but value $defaultIndex is outside the valid range of [0 .. %d]", $paletteEntryCount - 1)) if !$defaultWithinRange;
							$clampedDefault = clamp(0, $defaultIndex, $paletteEntryCount - 1);
						}
					}
				}
			}
		}
	}

	return ($definesVariable, $samePalette, $sameDefault, $defaultWithinRange, $clampedDefault);
}

# ---------------------------------------------------------------------

sub getRangedIntVariableInfo
{
	my $meshAssetIdArrayRef = shift;
	my $variableName		= shift;
	my $minRangeInclusive	= shift;
	my $defaultValue		= shift;
	my $maxRangeExclusive	= shift;

	# Variables for return state.
	my $definesVariable		= 0;
	my $sameRange			= 0;
	my $sameDefault			= 0;
	my $defaultWithinRange	= 0;
	my $clampedDefault      = 0;

	my $callerSpecifiedRange = defined($minRangeInclusive) && defined($maxRangeExclusive);

	# Lookup variable id for variable name.
	my $variableId = $variableIdByNameMap{$variableName};
	if (defined($variableId))
	{
		# Find the first asset in the list that defines the variable.
		for (my $i = 0; ($i < @$meshAssetIdArrayRef) && !$definesVariable; ++$i)
		{
			# Check if this asset id defines the variable.
			my $assetId				  = $$meshAssetIdArrayRef[$i];
			my $variableUsageArrayRef = findFirstVariableUsage($assetId, $variableId);
			$definesVariable = 1 if defined($variableUsageArrayRef);
			
			if ($definesVariable)
			{
				# Check the range info.
				my $rangeId	 = $$variableUsageArrayRef[1];
				my $rangeKey = $rangeKeyByIdMap{$rangeId};
				if (!($rangeKey =~ m/:/))
				{
					# This is not a basic ranged int variable.  It probably is a palcolor variable.
					$definesVariable = 0;
				}
				else
				{
					my ($rangeMin, $rangeMax) = split /:/, $rangeKey;

					if ($callerSpecifiedRange)
					{
						$sameRange = 1 if (($minRangeInclusive == $rangeMin) && ($maxRangeExclusive == $rangeMax));
					}
					else
					{
						$sameRange = '?';
					}

					# Check the default info.
					my $defaultId = $$variableUsageArrayRef[2];
					$sameDefault  = 1 if ($defaultValueByIdMap{$defaultId} == $defaultValue);

					# Check if default is within range.
					$defaultWithinRange = 1 if (($defaultValue >= $rangeMin) && ($defaultValue < $rangeMax));
					emitCdfWarning(sprintf("user specified new variable override for ranged int [$variableName] but value $defaultValue is outside the valid range of [$rangeMin .. %d]",$rangeMax - 1)) if !$defaultWithinRange;

					$clampedDefault = clamp($rangeMin, $defaultValue, $rangeMax);
				}
			}
		}
	}

	return ($definesVariable, $sameRange, $sameDefault, $defaultWithinRange, $clampedDefault);
}

# ---------------------------------------------------------------------

sub emitCdfWarning
{
	my $warning = shift;
	print STDERR "CDF WARNING($currentCdfFileName): $warning\n";
}

# ---------------------------------------------------------------------

sub trimString
{
	# Get args.
	my $string = shift;

	# Remove leading and trailing whitespace.
	$string =~ s/^\s*//;
	$string =~ s/\s*$//;

	# Return to caller.
	return $string;
}

# ---------------------------------------------------------------------

sub processWearableLines
{
	my $lineArrayRef = shift;
	my $emitWarnings = shift;

	# Pull out mesh asset ids.
	my @meshAssetIds = ();
	foreach (@$lineArrayRef)
	{
		if ( m/UseMeshGenerator\s*\(\s*\"([^\"]+)\"\s*\)/ )
		{
			# Get asset id for the mesh generator.
			my $meshName = $1;
			my $assetId	 = $assetIdByNameMap{$meshName};

			# If the mesh doesn't exist in the map, it may just mean that it provides no customizations.  I can't warn here
			# with the data I have.	 I could warn if I incorporated the tree file data.
			if (defined($assetId))
			{
				push(@meshAssetIds, $assetId) if defined($assetId);
				print "CBW uses customizable asset: assetId=[$assetId],name=[$meshName]\n" if $debug;
			}
			else
			{
				print "CBW uses non-customizable asset name=[$meshName]\n" if $debug;
			}
		}
	}

	my $modificationCount = 0;
	for (my $i = 0; $i < @$lineArrayRef; )
	{
		my $keepLine = 1;
		my $line	 = $$lineArrayRef[$i];

		if ($line =~ m/^(\s*).*UsePaletteCustomization\s*\(([^\)]+)\)/)
		{
			# Any way we slice it, we're definitely modifying this line.
			++$modificationCount;
			
			# Handle old-style palette declaration.
			my $leadingWhitespace = $1;
			my @args = split /,/, $2;	# "varname", palettePathName, paletteIndex
			if (@args != 3)
			{
				# Trim the reported line.
				my $reportedLine = trimString($line);
				emitCdfWarning("removing invalid declaration due to wrong number of args, should be 3: [$reportedLine]") if $emitWarnings;
				$keepLine = 0;
			}
			else
			{
				# Strip quotes from variable name.
				$args[0] =~ s/[\"\s]//g;
				$args[1] =~ s/[\"\s]//g;
				
				my ($definesVariable, $samePalette, $sameDefault, $defaultWithinRange) = getPaletteVariableInfo(\@meshAssetIds, @args);
				
				# Only emit a WearableCustomizationSetInt declaration if the variable is defined
				# by one of the meshes, the variable makes use of the same palette, the default
				# is within the valid range but the variable has a different default.
				if ($definesVariable && $samePalette && $defaultWithinRange && !$sameDefault)
				{
					# Change line to WearableCustomizationSetInt directive.
					$$lineArrayRef[$i] = $leadingWhitespace . "WearableCustomizationSetInt(\"$args[0]\",$args[2])";
					print "keeping [$args[0]] due to ($definesVariable, $samePalette, $sameDefault, $defaultWithinRange)\n" if $debug;
				}
				else
				{
					# Remove the line.
					$keepLine = 0;
					print "stripping [$args[0]] due to ($definesVariable, $samePalette, $sameDefault, $defaultWithinRange)\n" if $debug;
				}
			}
		}
		elsif ($line =~ m/^(\s*).*UseRangedIntCustomization\s*\(([^\)]+)\)/)
		{
			# Any way we slice it, we're definitely modifying this line.
			++$modificationCount;
			
			# Handle old-style ranged-int declaration.
			my $leadingWhitespace = $1;
			my @args = split /,/, $2;  # "varname", minInclusive, value, maxExclusive
			if (@args != 4)
			{
				my $reportedLine = trimString($line);
				emitCdfWarning("removing invalid line due to wrong number of args, should be 4: [$reportedLine]") if $emitWarnings;
				$keepLine = 0;
			}
			else
			{
				# Strip quotes from variable name.
				$args[0] =~ s/\"//g;

				my ($definesVariable, $sameRange, $sameDefault, $defaultWithinRange) = getRangedIntVariableInfo(\@meshAssetIds, @args);
				
				# Only emit a WearableCustomizationSetInt declaration if the variable is defined
				# by one of the meshes, the variable makes use of the same range, the default
				# is within the valid range but the variable has a different default.
				if ($definesVariable && $sameRange && $defaultWithinRange && !$sameDefault)
				{
					# Change line to WearableCustomizationSetInt directive.
					$$lineArrayRef[$i] = $leadingWhitespace . "WearableCustomizationSetInt(\"$args[0]\",$args[2])";
					print "keeping [$args[0]] due to ($definesVariable, $sameRange, $sameDefault, $defaultWithinRange)\n" if $debug;
				}
				else
				{
					# Remove the line.
					$keepLine = 0;
					print "stripping [$args[0]] due to ($definesVariable, $sameRange, $sameDefault, $defaultWithinRange)\n" if $debug;
				}
			}
		}
		elsif ($line =~ m/WearableCustomizationSetInt\s*\(([^\)]*)\)/)
		{
			# Grab the args of the function call.
			my @args = split /\s*,\s*/, $1;

			# Validate arg count.
			if (@args != 2)
			{
				my $reportedLine = trimString($line);
				emitCdfWarning("WearableCusotmizationSetInt requires two args, bad line [$reportedLine]");

				# Throw out the line.
				$keepLine = 0;
				++$modificationCount;
			}
			else
			{
				# Strip quotes from variable name.
				$args[0] =~ s/\"//g;

				# Check if variable is a palette color variable.
				my ($definesVariable, $samePalette, $sameDefault, $defaultWithinRange, $clampedDefault) = getPaletteVariableInfo(\@meshAssetIds, $args[0], undef(), $args[1]);
				if ($definesVariable)
				{
					if (!$defaultWithinRange)
					{
						# Warn about default.
						my $reportedLine = trimString($line);
						emitCdfWarning("index value $args[1] out of valid range, clamping to $clampedDefault");

						# Replace the line with clamped value.
						$$lineArrayRef[$i] = "\t\t\t\tWearableCustomizationSetInt(\"$args[0]\", $clampedDefault)";
						++$modificationCount;
					}

					if ($sameDefault && $defaultWithinRange)
					{
						# No need to write this one, it's the same as the artist default.
						++$modificationCount;
						$keepLine = 0;
					}
					else
					{
						# Keep the line.
						$keepLine = 1;
					}
				}
				else
				{
					# Check if variable is some other kind of ranged int variable.
					my ($definesVariable2, $sameRange2, $sameDefault2, $defaultWithinRange2, $clampedValue2) = getRangedIntVariableInfo(\@meshAssetIds, $args[0], undef(), $args[1], undef());
					if ($definesVariable2)
					{
						if (!$defaultWithinRange2)
						{
							# Warn about default.
							my $reportedLine = trimString($line);
							emitCdfWarning("index value $args[1] out of valid range, clamping to $clampedValue2");

							# Replace the line with clamped value.
							$$lineArrayRef[$i] = "\t\t\tWearableCustomizationSetInt(\"$args[0]\", $clampedValue2)";
							++$modificationCount;
						}

						if ($sameDefault2 && $defaultWithinRange2)
						{
							# No need to write this one, it's the same as the artist default.
							++$modificationCount;
							$keepLine = 0;
						}
						else
						{
							# Keep the line.
							$keepLine = 1;
						}
					}
					else
					{
						# This variable isn't even defined by any of the assets.
						my $reportedLine = trimString($line);
						emitCdfWarning("WearableCustomizationSetInt specified for variable not provided by asset, removing [$reportedLine]");
						$keepLine = 0;
						++$modificationCount;
					}
				}
			}
		}
		elsif (!($line =~ m/(Begin|End)Wearable/) && !($line =~ m/UseMeshGenerator/) && !($line =~ m/^\s+$/))
		{
			# @todo convert this to a warning once code is working.
			print STDERR "Unsupported client-baked wearable line [$line], ignoring.\n";
		}

		# Determine what to do based on $keepLine status.
		if ($keepLine)
		{
			# Move on to next line, keep this one.
			++$i;
		}
		else
		{
			# Move on to next line, delete current line.
			splice @$lineArrayRef, $i, 1;
		}
	}

	return $modificationCount;
}

# ---------------------------------------------------------------------

sub updateCdfContents
{
	# Get args.
	my $inputFileName = shift;
	my $outputFile	  = (@_ > 0) ? shift : undef;

	# Determine if we're writing modified.
	my $writeOutput = ref($outputFile);

	# Open input file.
	my $inputFile;
	open($inputFile, '< ' . $inputFileName) or die "Failed to open [$inputFile] for reading: $!";
	
	my $modificationCount = 0;
	my $inWearable		  = 0;
	my @wearableLines;

	while (<$inputFile>)
	{
		chomp();

		# Determine if we're in a wearable declaration.
		if (!$inWearable)
		{
			$inWearable = m/BeginWearable/;
		}
		else
		{
		}

		# Process the line.
		if (!$inWearable)
		{
			# We're not processing a wearable, just write the line.
			print $outputFile "$_\n" if $writeOutput;
		}
		else
		{
			# Track the wearable line.
			push @wearableLines, $_;

			if (m/EndWearable/)
			{
				# Process the wearable lines data.	Returns the fixed up
				# set of lines in @wearableLines.
				$modificationCount += processWearableLines(\@wearableLines, !$writeOutput);

				# Write fixed up wearable block.
				if ($writeOutput)
				{
					foreach my $line (@wearableLines)
					{
						print $outputFile $line, "\n";
					}
				}

				# We're no longer in a wearable.
				$inWearable	   = 0;
				@wearableLines = ();
			}
		}
	}

	# Return the number of modifications that were/would be made.
	return $modificationCount;
}

# ---------------------------------------------------------------------

sub getCdfFileName
{
	my $iffFileName = shift;
	$iffFileName =~ s!/dsrc/!/data/!;
	$iffFileName =~ s!\.mif$!.cdf!;

	return $iffFileName;
}

# ----------------------------------------------------------------------

sub p4EditFile
{
	my $fileName	 = shift;
	my $attemptCount = 0;

	# Do a p4 edit on the file.
	do
	{
		++$attemptCount;
		my $commandResult = `p4 edit $fileName`;
		print "p4 edit $fileName: $commandResult\n" if $debug;
	} while (($? != 0) && ($attemptCount < $p4EditRetryCount));

	die "Failed to run p4 edit on $fileName, tried $attemptCount times: [$?]" if ($? != 0);
}

# ----------------------------------------------------------------------

sub runMiff
{
	my $inputFileName  = shift;
	my $outputFileName = shift;

	my $output = `miff -i $inputFileName -o $outputFileName 2>&1`;
	die "failed to run miff -i $inputFileName -o $outputFileName: $output" if ($? != 0);
	print "miff -i $inputFileName -o $outputFileName: $output\n" if $debug;
}

# ---------------------------------------------------------------------

sub fixCdf
{
	# Get args.
	my $inputFileName = shift;

	# Open the MIF and CDF for editing.
	my $cdfFileName = getCdfFileName($inputFileName);
	my @oldCdfStats = stat $cdfFileName;

	p4EditFile($inputFileName);
	p4EditFile($cdfFileName);

	# Create temp file for modification output.	 Temp file is created in
	# same directory as the input file it will replace.	 This guarantees
	# we will be able to rename the temp file when finished processing.
	my ($inputFileVolume, $inputFileDir, $unused) = File::Spec->splitpath($inputFileName);
	my $tempFileDir = File::Spec->catpath($inputFileVolume, $inputFileDir, "");
	my ($outputFile, $outputFileName) = File::Temp::tempfile(DIR => $tempFileDir);

	# Process the file contents, writing new version to $outputFile.
	updateCdfContents($inputFileName, $outputFile);

	# Close the temp output file.
	close ($outputFile) or die "Failed to close newly-written CDF mif file [$outputFileName]: $!";
	
	# Replace the CDF mif input file with the newly written version.
	rename($outputFileName, $inputFileName) or die "Failed to replace [$inputFileName] with $[outputFileName]: $!";

	# Mif the file.
	runMiff($inputFileName, $cdfFileName);

	# Collect stats.
	my @newCdfStats = stat $cdfFileName;
	
	# Track # bytes we shrank the files by and # bytes total for modified files.
	if ((@oldCdfStats >= 7) && (@newCdfStats >= 7))
	{
		my $cdfDecreasedByteCount += ($oldCdfStats[7] - $newCdfStats[7]);
		my $cdfTotalByteCount	  += $newCdfStats[7];
	}
	else
	{
		print STDERR "failed to process filesizes for [$cdfFileName], probably doesn't exist on client.\n";
	}
}

# ---------------------------------------------------------------------

sub doesCdfRequireFixing
{
	# Just run the CDF update process in the mode that does not write output.
	my $filename		  = shift;
	my $modificationCount = updateCdfContents($filename);

	# We need to update the cdf file if one or more modifications would
	# be made.
	return ($modificationCount > 0);
}

# ---------------------------------------------------------------------

sub fixCdfFindFileHandler
{
	# Ensure target is a normal file and is readable.
	if (-f && -r && m/\.mif$/i)
	{
		# Keep track of the file we're processing.
		$currentCdfFileName = $File::Find::name;

		print "Processing file [$_]\n" if $debug;
		++$checkedCdfCount;

		if (doesCdfRequireFixing($File::Find::name))
		{
			fixCdf($File::Find::name);
			++$fixedCdfCount;
		}
	}
}

# ---------------------------------------------------------------------

sub collectPaletteEntryCounts
{
	my $missingPaletteCount = 0;

	foreach my $paletteName (keys %rangeIdByKeyMap)
	{
		# Skip ranged int range data.
		next if $paletteName =~ m/:/;

		# Get the full pathname for the palette.
		my $fullPathName = TreeFile::getFullPathName($paletteName);
		if (!defined ($fullPathName))
		{
			print "Failed to find on-disk location of TreeFile-relative palette name [$paletteName]\n";
			++$missingPaletteCount;
			next;
		}

		# Open the file.
		my $inputFile;
		open($inputFile, '< ' . $fullPathName) or die "Failed to open palette file [$fullPathName] for reading: $!";
		binmode($inputFile) or die "Failed to set file [$fullPathName] to binary mode: $!";

		# Skip the first 22 bytes.
		seek($inputFile, 22, 0) or die "Failed to seek to palette entry count position within [$fullPathName], bad palette file: $!";

		# Collect the entry count (2 bytes starting 22 bytes in).
		my $byteAsChar;

		read($inputFile, $byteAsChar, 1) or die "Failed to read entry count byte from [$fullPathName]: $!";
		my $entryCount = ord($byteAsChar);

		read($inputFile, $byteAsChar, 1) or die "Failed to read entry count byte from [$fullPathName]: $!";
		$entryCount	   += (ord($byteAsChar) << 8);

		# Close the file.
		close($inputFile) or die "Failed to close palette file [$fullPathName]: $!";

		# Enter palette entry count into map.
		$paletteEntryCountByName{$paletteName} = $entryCount;
		printf("palette entries: %5d; name=[%s]\n", $entryCount, $paletteName) if $debug;
	}

	if ($missingPaletteCount > 0)
	{
		print "There are $missingPaletteCount missing palettes.\n";
		die "Missing palettes must be added before processing can continue." if !$ignoreMissingPalettes;
	}
}

# ---------------------------------------------------------------------

sub fixDirectories
{
	# Setup data needed by process.
	%assetNameByIdMap		 = reverse %assetIdByNameMap;
	%defaultValueByIdMap	 = reverse %defaultIdByValueMap;
	%rangeKeyByIdMap		 = reverse %rangeIdByKeyMap;
	%variableNameByIdMap	 = reverse %variableIdByNameMap;
	%variableUsageKeyByIdMap = reverse %variableUsageIdByKeyMap;

	# Call our find file handler on each file in the specified directories.
	&File::Find::find(\&fixCdfFindFileHandler, @directoriesToScan);

	# Print processing info.
	print  "Client Data File processing statistics:\n";
	print  "\tchecked file count:  $checkedCdfCount\n";
	print  "\tfixed file count:	   $fixedCdfCount\n";
	printf "\tmodified cdf size:   %.2f KB\n", $cdfTotalByteCount / 1024;
	printf "\tshrank cdfs by this: %.2f KB\n", $cdfDecreasedByteCount / 1024;
}

# ---------------------------------------------------------------------

sub initializeTreeFile
{
	my $treeFile;
	open($treeFile, '< ' . $treeFileLookupFileName) or die "Failed to open treefile xlat data [$treeFileLookupFileName]: $!";
	TreeFile::loadFileLookupTable($treeFile);
	close($treeFile) or die "Failed to close treefile xlat data [$treeFileLookupFileName]: $!";
}

# =====================================================================
# Main Program
# =====================================================================

# Handle the command line options.
processCommandLine(@ARGV);

# Initialize TreeFile.
initializeTreeFile();

# Process the raw input data.
processRawInputData();

# Collect palette entry count data.
collectPaletteEntryCounts();

# Write out the output data.
fixDirectories();

# Done, success.
exit 0;

# =====================================================================
