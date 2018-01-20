# =====================================================================
# buildAssetCustomizationManagerData.pl
# Copyright 2003, Sony Online Entertainment, Inc.
# All rights reserved.
# =====================================================================

use strict;

use Crc;
use File::Spec;
use File::Temp;
use PaletteArgb;
use POSIX;
use TreeFile;

# =====================================================================

my $debug							= 0;
my $debugLinesPerOutputTick			= 100;
my $examineProcessedData			= 0;
my $removeEntries					= 0;

my $assetLinkLineCount				= 0;
my $basicRangedIntVariableLineCount = 0;
my $paletteColorVariableLineCount	= 0;
my $removedEntryCount				= 0;

my $acmOutputFileName;
my $assetReportFile;
my $assetReportFileName;
my $customizationIdManagerMifFileName;
my $optimizedRawFileName;
my $rawInputFileName;
my $treeFileLookupTableFileName;

my %assetIdByNameMap;
my %assetNameByCrcMap;
my %defaultIdByValueMap;
my %intRangeByIntRangeIdMap;
my %nameBlockOffsetByPaletteId;
my %nameBlockOffsetByVariableNameId;
my %paletteEntryCountByName;
my %paletteIdByNameMap;
my %rangeIdByKeyMap;
my %rangeTypeByIdMap;
my %usedAssetIdByUserMap;
my %variableIdByNameMap;
my %variableUsageIdByAssetIdMap;
my %variableUsageIdByKeyMap;

my @nameBlockStrings;
my $nameBlockLength			   = 0;

my @assetLinkageList;
my %assetLinkageListingIndexData;
my @variableUsageList;
my %variableUsageListingIndexData;

my $maxAssignedAssetId		   = 0;
my $maxAssignedDefaultId	   = 0;
my $maxAssignedIntRangeId	   = 0;
my $maxAssignedPaletteId	   = 0;
my $maxAssignedRangeId		   = 0;
my $maxAssignedVariableId	   = 0;
my $maxAssignedVariableUsageId = 0;

my $maxNameBlockOffset = (sprintf("%u", 1 << 16) - 1);

my $MAX_VALID_CUSTOMIZATION_ID = 127;

# =====================================================================

sub printUsage
{
	print "Usage: \n";
	print "	 perl buildAssetCustomizationManagerData.pl [-h]\n";
	print "\n";
	print "	 perl buildAssetCustomizationManagerData.pl [-d] [-e] -i <rawInfoFile.dat> -r\n";
	print "	   -a <badAssetReportFile.txt> -t <treeFileLookupTable.dat>\n";
	print "\n";
	print "	 perl buildAssetCustomizationManagerData.pl [-d] [-e] -i <rawInfoFile.dat>\n";
	print "	   -o <outputFileName.mif> -m <customizationIdManagerMifFile.mif>\n";
	print "	   -a <badAssetReportFile.txt> -t <treeFileLookupTable.dat>\n";
	print "\n";
	print "Options:\n";
	print "	 -a: specifies the filename to use to log asset error information\n";
	print "	 -d: enable verbose debugging information\n";
	print "	 -e: examine (dump) processed data on STDOUT\n";
	print "	 -h: print this help\n";
	print "	 -i: the raw data output file from collectAssetCustomizationData.pl\n";
	print "	 -m: specify the customization_id_manager filename to be updated, use only with -o.\n";
	print "	 -o: names the output file where asset_customization_manager mif data will be written\n";
	print "	 -r: remove unnecessary entries and output a new raw data output file\n";
	print "		 suitable for use as input to this program with the -i option.\n";
	print "		(Yes, you will need to run this program twice, run first with -r,\n";
	print "		 then run the second time without -r to get a minimal-sized data file.)\n";
	print "	 -t: specify the filename of the TreeFile lookup table file (must specify if -a is specified)\n";
}

# ----------------------------------------------------------------------

sub processCommandLine
{
	my $requestHelp = 0;
	my $printHelp	= 0;

	for (; (@_ > 0) && ($_[0] =~ m/^-(.*)$/); shift)
	{
		if ($1 eq 'a')
		{
			shift;
			$assetReportFileName = $_[0];
			print "assetReportFileName=$assetReportFileName\n" if $debug;
		}
		elsif ($1 eq 'd')
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
		elsif ($1 eq 'm')
		{
			shift;
			$customizationIdManagerMifFileName = $_[0];
			print "customizationIdManagerMifFileName=$customizationIdManagerMifFileName\n" if $debug;
		}
		elsif ($1 eq 'o')
		{
			shift;
			$acmOutputFileName = $_[0];
			print "acmOutputFileName=$acmOutputFileName\n" if $debug;
		}
		elsif ($1 eq 'r')
		{
			$removeEntries = 1;
			print "removeEntries=1\n" if $debug;
		}
		elsif ($1 eq 't')
		{
			shift;
			$treeFileLookupTableFileName = $_[0];
			print "treeFileLookupTableFileName=$treeFileLookupTableFileName\n" if $debug;
		}
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

		# Make sure we have an output file specified.
		if ($removeEntries)
		{
			# Build optimized output filename.
			if ($rawInputFileName =~ m/^(.*)(\.[^.]*)$/)
			{
				$optimizedRawFileName = $1 . '-optimized' . $2;
			}
			else
			{
				$optimizedRawFileName = $rawInputFileName . '.optimized';
			}
			print "optimizedRawFileName=$optimizedRawFileName\n" if $debug;

			# User should not specify -o option if we're building an optimized raw file.
			if ((defined $acmOutputFileName && (length($acmOutputFileName) > 0)) ||
				(defined $customizationIdManagerMifFileName && (length($customizationIdManagerMifFileName) > 0)))
			{
				print "The -o output filename and -m filename should not be specified when using -r for optimization.\n";
				$printHelp = 1;
			}
		}
		elsif ((!defined($acmOutputFileName) || (length($acmOutputFileName) < 1)))
		{
			print "No ACM output filename specified, specify with -o switch.\n";
			$printHelp = 1;
		}
	}

	if ($printHelp)
	{
		printUsage();
		exit -1;
	}
}

# ---------------------------------------------------------------------

sub getPaletteEntryCount
{
	# Get args.
	my $paletteName = shift;
	die "getPaletteEntryCount(): invalid paletteName arg" unless defined($paletteName);

	# Check if we already have the palette entry count for this palette.
	my $paletteEntryCount = $paletteEntryCountByName{$paletteName};
	if (!defined($paletteEntryCount))
	{
		# Get the full pathname for the palette.
		my $fullPathName = TreeFile::getFullPathName($paletteName);
		if (!defined ($fullPathName))
		{
			print $assetReportFile "Failed to find on-disk location of TreeFile-relative palette name [$paletteName]\n" if defined($assetReportFile);
			return 0;
		}
		else
		{
			$paletteEntryCount = PaletteArgb::getEntryCount($fullPathName);
			if (!defined($paletteEntryCount))
			{
				print $assetReportFile "PaletteArgb file [$fullPathName] is corrupt, can't be opened or not a palette file.\n" if defined($assetReportFile);
				return 0;
			}

			# Cache the palette entry count for this TreeFile-relative filename. 
			$paletteEntryCountByName{$paletteName} = $paletteEntryCount;
		}
	}

	return $paletteEntryCount;
}

# ----------------------------------------------------------------------

sub installApp
{
	# Setup the TreeFile system so we can resolve TreeFile-relative filenames
	# to the correct on-disk filename.
	die "TreeFileLookupTable filename not specified, use -t option" unless defined($treeFileLookupTableFileName);

	my $treeFileLookupTableFile;
	open($treeFileLookupTableFile, '< ' . $treeFileLookupTableFileName) or die "failed to open [$treeFileLookupTableFileName]: $!";
	TreeFile::loadFileLookupTable($treeFileLookupTableFile);
	close($treeFileLookupTableFile) or die "failed to close [$treeFileLookupTableFileName]: $!";

	# Open the art asset report file.
	if (defined($assetReportFileName))
	{
		open($assetReportFile, '> ' . $assetReportFileName) or die "Failed to open art asset report file [$assetReportFileName]: $!";

		my $timeString = strftime "%a %b %e %H:%M:%S %Y", localtime(time());
		print $assetReportFile "Art asset customization report\n";
		print $assetReportFile "Start time: $timeString\n";
	}
	else
	{
		$assetReportFile = undef();
	}
}

# ----------------------------------------------------------------------

sub removeApp
{
	# Close the art asset report file.
	if (defined($assetReportFile))
	{
		my $timeString = strftime "%a %b %e %H:%M:%S %Y", localtime(time());
		print $assetReportFile "Finish time: $timeString\n";

		close($assetReportFile) or die "Failed to close art asset report file [$assetReportFileName]: $!";
		$assetReportFile = undef();
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
	my $assetName			= shift;
	my $assetId				= getAssetId($assetName);
	my $variableId			= getVariableId(shift);
	my $paletteName			= shift;
	my $rangeId				= getPaletteRangeId($paletteName);
	my $defaultPaletteIndex = shift;

	# Validate that default palette index is within valid range, warn and clamp if not.
	my $paletteEntryCount	= getPaletteEntryCount($paletteName);
	if (($defaultPaletteIndex < 0) || ($defaultPaletteIndex >= $paletteEntryCount))
	{
		print $assetReportFile "$assetName: defines out-of-range default value [$defaultPaletteIndex] for palette [$paletteName] with ($paletteEntryCount) entries, clamping to valid range.\n" if defined($assetReportFile);
		if ($defaultPaletteIndex < 0)
		{
			$defaultPaletteIndex = 0;
		}
		else
		{
			$defaultPaletteIndex = $paletteEntryCount - 1;
		}
	}

	# Get default value index for palette index.
	my $defaultId			= getDefaultId($defaultPaletteIndex);

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

	my $outputFile;
	if ($removeEntries)
	{
		open($outputFile, "> " . $optimizedRawFileName) or die "Failed to open optimized raw file for writing [$optimizedRawFileName]: $!";
	}

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
			# Copy non-link line to optimized raw output file.
			print $outputFile $originalLine if $removeEntries;

			# Process a use case of a basic ranged int variable.
			processBasicRangedIntVariable(split /:/);
			++$basicRangedIntVariableLineCount;
		}
		elsif (s/^P\s+//)
		{
			# Copy non-link line to optimized raw output file.
			print $outputFile $originalLine if $removeEntries;

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

	if ($removeEntries)
	{
		close($outputFile) or die "Failed to close optimized raw output file: $!";
	}

	close($inputFile) or die "Failed to close raw input file: $!";

	# Print statistics.
	print "Finished processing input file:\n";
	print "\tasset links:				 $assetLinkLineCount\n";
	print "\tbasic ranged int variables: $basicRangedIntVariableLineCount\n";
	print "\tpalette color variables:	 $paletteColorVariableLineCount\n";
	print "\tskipped lines:				 $skippedLineCount\n";
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

# ----------------------------------------------------------------------

sub addNameToNameBlock
{
	# Get args.
	my $name = shift;

	# Add name to name list.
	push @nameBlockStrings, $name;

	# Remember starting offset within name block.
	my $nameBlockOffset	 = $nameBlockLength;
	die "Data format change needed: name block now offsets now require more bits." if ($nameBlockOffset > $maxNameBlockOffset);

	# Adjust name block length, add the null byte.
	$nameBlockLength += length($name) + 1;


	# Return starting offset within name block.
	return $nameBlockOffset;
}

# ----------------------------------------------------------------------
# Take all the palette and variable names in use, map names to
# index of starting string, add names to list of strings to write in
# order.
# ----------------------------------------------------------------------

sub generateNameTableBlockData
{
	# Start with palette names.

	#-- Capture unique palette names.
	my %uniquePaletteNames;
	foreach (keys %rangeIdByKeyMap)
	{
		$uniquePaletteNames{$_} = 1 if (!m/:/);
	}

	#-- Assign palette ids to name.
	$maxAssignedPaletteId = 0;
	foreach (keys %uniquePaletteNames)
	{
		$paletteIdByNameMap{$_} = ++$maxAssignedPaletteId;
	}
	die "tfiala must update data format: max # supported palettes blown [$maxAssignedPaletteId]" if $maxAssignedPaletteId >= (0x8000);

		#-- Add palette names to name table block, mapping palette ids
		#	to name block offsets.
		foreach my $paletteName (keys %uniquePaletteNames)
	{
		my $paletteId = $paletteIdByNameMap{$paletteName};
		$nameBlockOffsetByPaletteId{$paletteId} = addNameToNameBlock($paletteName);
	}

	# Handle variable pathnames.
	foreach my $variableName (sort { sprintf("%u", $variableIdByNameMap{$a}) <=> sprintf("%u", $variableIdByNameMap{$b}) } keys %variableIdByNameMap)
	{
		my $variableId = $variableIdByNameMap{$variableName};
		$nameBlockOffsetByVariableNameId{$variableId} = addNameToNameBlock($variableName);
	}
	die "tfiala must update data format: max # supported variable names blown" if $maxAssignedVariableId >= (0x8000);
	}

# ----------------------------------------------------------------------

sub writeNameTableBlock
{
	my $outputFile = shift;

	print $outputFile "\t\tchunk \"NAME\"\n";
	print $outputFile "\t\t{\n";

	foreach (@nameBlockStrings)
	{
		printf $outputFile "\t\t\tcstring \"%s\"\n", $_;
	}

	print $outputFile "\t\t}\n\n";
}

# ----------------------------------------------------------------------

sub writePaletteNameTableOffset
{
	my $outputFile = shift;

	print $outputFile "\t\tchunk \"PNOF\"\n";
	print $outputFile "\t\t{\n";

	for (my $paletteId = 1; $paletteId <= $maxAssignedPaletteId; ++$paletteId)
	{
		my $offset = $nameBlockOffsetByPaletteId{$paletteId};
		printf $outputFile "\t\t\tuint16  %u\n", defined($offset) ? $offset : -1;
	}

	print $outputFile "\t\t}\n\n";
}

# ----------------------------------------------------------------------

sub writeVariableNameTableOffset
{
	my $outputFile = shift;

	print $outputFile "\t\tchunk \"VNOF\"\n";
	print $outputFile "\t\t{\n";

	for (my $variableId = 1; $variableId <= $maxAssignedVariableId; ++$variableId)
	{
		my $offset = $nameBlockOffsetByVariableNameId{$variableId};
		printf $outputFile "\t\t\tuint16  %u\n", defined($offset) ? $offset : -1;
	}

	print $outputFile "\t\t}\n\n";
}

# ----------------------------------------------------------------------

sub writeDefaultValueTable
{
	# Get args.
	my $outputFile = shift;

	# Create a reverse mapping of %defaultIdByValueMap
	my %defaultValueByIdMap = reverse %defaultIdByValueMap;

	print $outputFile "\t\tchunk \"DEFV\"\n";
	print $outputFile "\t\t{\n";

	for (my $id = 1; $id <= $maxAssignedDefaultId; ++$id)
	{
		my $value = $defaultValueByIdMap{$id};
		printf $outputFile "\t\t\tint32	 %d\n", defined($value) ? $value : 0;
	}

	print $outputFile "\t\t}\n\n";
}

# ----------------------------------------------------------------------

sub generateRangeTypeInfoData
{
	foreach my $rangeKey (keys %rangeIdByKeyMap)
	{
		my $rangeType = 0;

		my $rangeId = $rangeIdByKeyMap{$rangeKey};
		if (!($rangeKey =~ m/:/))
		{
			# Range key is a palette pathname.	Set MSB with remainder being 
			my $paletteId = $paletteIdByNameMap{$rangeKey};
			die "paletteId for palette name [$rangeKey] not defined" if !defined($paletteId);

			# Set upper bit of 16-bit range type.
			$rangeType = 0x8000 | $paletteId;
		}
		else
		{
			# Validate that range key is really a two-part integer in the form <minrangeinclusive>:<maxrangeexclusive>
			my @range = split(/:/, $rangeKey);
			die "invalid range value count @{range}" if @range != 2;

			# Assign new integer range id to this int range.  Note integer range id and range id are two different things.
			$intRangeByIntRangeIdMap{++$maxAssignedIntRangeId} = $rangeKey;
			die "tfiala must update format: supported unique int range count was blown" if $maxAssignedIntRangeId >= (0x8000);
			$rangeType = $maxAssignedIntRangeId;
		}

		# Track the range id => range type data.
		$rangeTypeByIdMap{$rangeId} = $rangeType;
	}
}

# ----------------------------------------------------------------------

sub writeIntRangeTable
{
	# Get args.
	my $outputFile = shift;

	print $outputFile "\t\tchunk \"IRNG\"\n";
	print $outputFile "\t\t{\n";

	for (my $id = 1; $id <= $maxAssignedIntRangeId; ++$id)
	{
		my $rangeKey = $intRangeByIntRangeIdMap{$id};
		my @range	 = defined($rangeKey) ? split(/:/, $rangeKey) : (0, 1);
		die "invalid range value count @{range}" if @range != 2;

		printf $outputFile "\t\t\tint32	 %d\n", $range[0];
		printf $outputFile "\t\t\tint32	 %d\n", $range[1];
		print  $outputFile "\n";
	}

	print $outputFile "\t\t}\n\n";
}

# ----------------------------------------------------------------------

sub writeRangeTypeInfoTable
{
	# Get args.
	my $outputFile = shift;

	print $outputFile "\t\tchunk \"RTYP\"\n";
	print $outputFile "\t\t{\n";

	for (my $id = 1; $id <= $maxAssignedRangeId; ++$id)
	{
		my $rangeType = $rangeTypeByIdMap{$id};
		printf $outputFile "\t\t\tuint16 %u\n", defined($rangeType) ? $rangeType : 0;
	}

	print $outputFile "\t\t}\n\n";
}

# ----------------------------------------------------------------------

sub writeVariableUsageCompositionTable
{
	# Get args.
	my $outputFile = shift;

	print $outputFile "\t\tchunk \"UCMP\"\n";
	print $outputFile "\t\t{\n";

	my %variableUsageKeyByIdMap = reverse %variableUsageIdByKeyMap;

	for (my $id = 1; $id <= $maxAssignedVariableUsageId; ++$id)
	{
		my $usageKey	 = $variableUsageKeyByIdMap{$id};
		my @componentIds = defined($usageKey) ? split(/:/, $usageKey) : (0, 0, 0);
		die "invalid componentIds value count @{componentIds}" if @componentIds != 3;

		die "tfiala must update format: valid unique variable id range blown" if $componentIds[0] > 65536;
		die "tfiala must update format: valid unique range id range blown" if $componentIds[1] > 65536;
		die "tfiala must update format: valid unique default value id range blown" if $componentIds[2] > 65536;

		printf $outputFile "\t\t\tuint16	 %u\n", $componentIds[0];
		printf $outputFile "\t\t\tuint16	 %u\n", $componentIds[1];
		printf $outputFile "\t\t\tuint16	 %u\n", $componentIds[2];
		print  $outputFile "\n";
	}

	print $outputFile "\t\t}\n\n";
}

# ----------------------------------------------------------------------

sub generateVariableUsageListingData
{
	foreach my $assetId (sort compare_uint32 keys %variableUsageIdByAssetIdMap)
	{
		my $usageIdListAsString = $variableUsageIdByAssetIdMap{$assetId};
		die "usage id list as string mapping to asset id $assetId was undefined" if !defined($usageIdListAsString);

		my @usageIdArray = split /:/, $usageIdListAsString;
		my $listingCount = scalar(@usageIdArray);
		die "usage id list had no entries for asset id $assetId" if ($listingCount < 1);
		
		my $firstListingIndex = scalar(@variableUsageList);
		push @variableUsageList, @usageIdArray;
		
		$variableUsageListingIndexData{$assetId} = $firstListingIndex . ':' . $listingCount;
	}
}

# ----------------------------------------------------------------------

sub writeVariableUsageListingTable
{
	my $outputFile = shift;

	print $outputFile "\t\tchunk \"ULST\"\n";
	print $outputFile "\t\t{\n";

	foreach (@variableUsageList)
	{
		printf $outputFile "\t\t\tuint16 %u\n", $_;
		die "variable usage index $_ out of valid range" if ($_ > 0xFFFF);
	}

	print $outputFile "\t\t}\n\n";
}

# ----------------------------------------------------------------------

sub writeVariableUsageIndexTable
{
	# Get args.
	my $outputFile = shift;

	print $outputFile "\t\tchunk \"UIDX\"\n";
	print $outputFile "\t\t{\n";

	foreach my $assetId (sort compare_uint32 keys %variableUsageListingIndexData)
	{
		my $indexDataAsString = $variableUsageListingIndexData{$assetId};
		die "invalid indexDataAsString: undefined for $assetId" if !defined($indexDataAsString);

		my @indexDataArray = split(/:/, $indexDataAsString);
		die "invalid index data from string $indexDataAsString: should have 2 parts for asset $assetId" if (@indexDataArray != 2);

		die "tfiala must update format: valid unique asset id range blown"		 if ($assetId			> 0xFFFF);
		die "tfiala must update format: valid listing start index bitsize blown" if ($indexDataArray[0] > 0xFFFF);
		die "tfiala must update format: valid listing count blown"				 if ($indexDataArray[1] > 255);

		printf $outputFile "\t\t\tuint16  %u\n", $assetId;
		printf $outputFile "\t\t\tuint16  %u\n", $indexDataArray[0];
		printf $outputFile "\t\t\tuint8	  %u\n", $indexDataArray[1];
		print  $outputFile "\n";
	}

	print $outputFile "\t\t}\n\n";
}

# ----------------------------------------------------------------------
# Linkage
# ----------------------------------------------------------------------

sub generateAssetLinkageListingData
{
	foreach my $assetId (sort compare_uint32 keys %usedAssetIdByUserMap)
	{
		my $linkageIdListAsString = $usedAssetIdByUserMap{$assetId};
		die "linkage id list as string mapping to asset id $assetId was undefined" if !defined($linkageIdListAsString);

		my @linkageIdArray = split /:/, $linkageIdListAsString;
		my $listingCount = scalar(@linkageIdArray);
		die "linkage id list had no entries for asset id $assetId" if ($listingCount < 1);
		
		my $firstListingIndex = scalar(@assetLinkageList);
		push @assetLinkageList, @linkageIdArray;
		
		$assetLinkageListingIndexData{$assetId} = $firstListingIndex . ':' . $listingCount;
	}
}

# ----------------------------------------------------------------------

sub writeAssetLinkageListingTable
{
	my $outputFile = shift;

	print $outputFile "\t\tchunk \"LLST\"\n";
	print $outputFile "\t\t{\n";

	foreach (@assetLinkageList)
	{
		printf $outputFile "\t\t\tuint16 %u\n", $_;
		die "asset linkage index $_ out of valid range" if ($_ > 0xFFFF);
	}

	print $outputFile "\t\t}\n\n";
}

# ----------------------------------------------------------------------

sub writeAssetLinkageIndexTable
{
	# Get args.
	my $outputFile = shift;

	print $outputFile "\t\tchunk \"LIDX\"\n";
	print $outputFile "\t\t{\n";

	foreach my $assetId (sort compare_uint32 keys %assetLinkageListingIndexData)
	{
		my $indexDataAsString = $assetLinkageListingIndexData{$assetId};
		die "invalid indexDataAsString: undefined for $assetId" if !defined($indexDataAsString);

		my @indexDataArray = split(/:/, $indexDataAsString);
		die "invalid index data from string $indexDataAsString: should have 2 parts for asset $assetId" if (@indexDataArray != 2);

		die "tfiala must update format: valid unique asset id range blown"		 if ($assetId			> 0xFFFF);
		die "tfiala must update format: valid listing start index bitsize blown" if ($indexDataArray[0] > 0xFFFF);
		die "tfiala must update format: valid listing count blown"				 if ($indexDataArray[1] > 255);

		printf $outputFile "\t\t\tuint16  %u\n", $assetId;
		printf $outputFile "\t\t\tuint16  %u\n", $indexDataArray[0];
		printf $outputFile "\t\t\tuint8	  %u\n", $indexDataArray[1];
		print  $outputFile "\n";
	}

	print $outputFile "\t\t}\n\n";
}

# ----------------------------------------------------------------------

sub compare_uint32
{
	sprintf("%u", $a) <=> sprintf("%u", $b);
}

# ----------------------------------------------------------------------

sub writeAssetCrcToAssetIdIndexTable
{
	# Get args.
	my $outputFile = shift;

	print $outputFile "\t\tchunk \"CIDX\"\n";
	print $outputFile "\t\t{\n";

	foreach my $assetCrc (sort compare_uint32 keys %assetNameByCrcMap)
	{
		# Get asset id for asset name crc.
		my $assetName = $assetNameByCrcMap{$assetCrc};
		die "assetCrc [$assetCrc] mapped to undefined name" if !defined($assetName);

		my $assetId = $assetIdByNameMap{$assetName};
		die "assetName [$assetName] mapped to undefined asset id" if !defined($assetId);

		die "tfiala must update format: valid unique asset id range blown" if ($assetId > 0xFFFF);

		printf $outputFile "\t\t\tuint32  %u\n", $assetCrc;
		printf $outputFile "\t\t\tuint16  %u\n", $assetId;
		print  $outputFile "\n";
	}

	print $outputFile "\t\t}\n\n";
}

# ----------------------------------------------------------------------

sub writeOutputData
{
	# Examine processed data structures if requested.
	examineProcessedData() if ($examineProcessedData);

	print "Writing AssetCustomizationManager data to file [$acmOutputFileName].\n";

	# Open the output file.
	my $outputFile;
	open($outputFile, "> " . $acmOutputFileName) or die "Failed to open output file [$acmOutputFileName]: $!";

	my $timeString = POSIX::strftime "%a %b %e %H:%M:%S %Y", localtime(time());

	print $outputFile "// AssetCustomizationManager file.\n";
	print $outputFile "// Generated: $timeString\n\n";

	print $outputFile 'form "ACST"' . "\n";
	print $outputFile "{\n";

	print $outputFile "\tform \"0000\"\n";
	print $outputFile "\t{\n";

	generateNameTableBlockData();
	writeNameTableBlock($outputFile);
	writePaletteNameTableOffset($outputFile);
	writeVariableNameTableOffset($outputFile);

	writeDefaultValueTable($outputFile);

	generateRangeTypeInfoData();
	writeIntRangeTable($outputFile);
	writeRangeTypeInfoTable($outputFile);

	writeVariableUsageCompositionTable($outputFile);

	generateVariableUsageListingData();
	writeVariableUsageListingTable($outputFile);
	writeVariableUsageIndexTable($outputFile);

	generateAssetLinkageListingData();
	writeAssetLinkageListingTable($outputFile);
	writeAssetLinkageIndexTable($outputFile);

	writeAssetCrcToAssetIdIndexTable($outputFile);

	print $outputFile "\t}\n";

	print $outputFile "}\n";

	# Get output file stats.
	my @outputFileStat = stat($outputFile);

	# Close the output file.
	close($outputFile) or die "Failed to close output file [$acmOutputFileName]: $!";

	if ($debug)
	{
		my $fileSizeInKb = int($outputFileStat[7] / 1024);
		print "Successfully wrote output file [$acmOutputFileName]: $fileSizeInKb KB\n";
	}
}

# ----------------------------------------------------------------------

sub buildUserAssetIdHash
{
	my $userAssetIdsByUsedIdRef = {};

	foreach my $userAssetId (keys %usedAssetIdByUserMap)
	{
		my $usedAssetIdsInString = $usedAssetIdByUserMap{$userAssetId};
		my @usedAssetIdArray	 = split /:/, $usedAssetIdsInString;
		foreach my $usedAssetId (@usedAssetIdArray)
		{
			if (exists $$userAssetIdsByUsedIdRef{$usedAssetId})
			{
				$$userAssetIdsByUsedIdRef{$usedAssetId} .= ':' . $userAssetId;
			}
			else
			{
				$$userAssetIdsByUsedIdRef{$usedAssetId} = $userAssetId;
			}
		}
	}

	return $userAssetIdsByUsedIdRef;
}

# ----------------------------------------------------------------------

sub deleteAssetIfNotNeeded
{
	my $assetId			    = shift;
	my $assetNameByIdMapRef = shift;
	my $userAssetIdsMapRef  = shift;
	my $usedAssetIdsMapRef  = shift;

	# Check if this linked asset provides any variables.
	my $providesVariables = exists $variableUsageIdByAssetIdMap{$assetId};
	if (!$providesVariables)
	{
		# It doesn't provide any variables.	 Check if it links (depends on) another
		# asset (which could provide variables).
		my $dependsOnAnotherAsset = exists $$usedAssetIdsMapRef{$assetId};
		if (!$dependsOnAnotherAsset)
		{
			# It doesn't depend on (i.e. doesn't link to) another asset.  Therefore
			# we can safely remove this asset since it contributes no information
			# for finding customization variable usage.
			++$removedEntryCount;

			if ($debug)
			{
				my $assetName = $$assetNameByIdMapRef{$assetId};
				print "Deleting asset id $assetId [$assetName]:it doesn't provide variables and it doesn't link to other assets.\n";
			}

			# Delete the asset name reference.  This is how we tell the controlling loop that it is
			# about to process an already-removed entry.
			delete $$assetNameByIdMapRef{$assetId};
			
			# Delete the link to this asset from the user asset ids.
			my $userAssetIdsAsString = $$userAssetIdsMapRef{$assetId};
			if (defined $userAssetIdsAsString)
			{
				my @userAssetIdsArray = split /:/, $userAssetIdsAsString;
				foreach my $userAssetId (@userAssetIdsArray)
				{
					# Find the used id entry and remove it from this user.	Delete the
					# used link entry if no items remain after removing this one.
					my $usedAssetIdStringForUser = $$usedAssetIdsMapRef{$userAssetId};
					if (defined $usedAssetIdStringForUser)
					{
						# Remove any references to the now-deleted asset from other assets that linked to it.
						my @usedAssetIdArrayForUser = split /:/, $usedAssetIdStringForUser;
						my $removeCount = 0;

						for (my $i = 0; $i < @usedAssetIdArrayForUser;)
						{
							if ($usedAssetIdArrayForUser[$i] eq $assetId)
							{
								# This entry marks a link to the now-removed asset, so remove this reference.
								splice @usedAssetIdArrayForUser, $i, 1;
								
								# Keep $i the same since a new element just moved into this spot.
								++$removeCount;
							}
							else
							{
								# Look at next element.
								++$i;
							}
						}

						if ($removeCount)
						{
							# Check if there's still any links to another asset.
							if (@usedAssetIdArrayForUser > 0)
							{
								# There are still links to other assets, reset the list.
								$$usedAssetIdsMapRef{$userAssetId} = join ':', @usedAssetIdArrayForUser;
							}
							else
							{
								# There are no more links to other assets, remove the used asset map entry for the user.
								delete $$usedAssetIdsMapRef{$userAssetId};

								# Since there's no links to other assets, check if this user asset is now ripe for plucking.
								deleteAssetIfNotNeeded($userAssetId, $assetNameByIdMapRef, $userAssetIdsMapRef, $usedAssetIdsMapRef);
							}
						}
						
					}
				}
			}
		}
	}
}

# ----------------------------------------------------------------------

sub removeEntries
{
	# Once we do this, we lose asset usage information for anything that doesn't
	# provide customization-related information.
	print "Optimizing: asset data output useful only for customization info lookup.\n";

	# One strategy: remove any assets that don't link to another asset
	# and don't use any customization variables.  Then process any
	# assets that linked to (were dependent on) the just-removed asset.
	# This will remove dead entries that are unneeded.
	
	#-- Get a list of asset ids to process.	 This is the entire list of
	#	unique asset IDs known within the dataset.
	my @assetIdList = values %assetIdByNameMap;

	#-- We'll want a reverse dependency tree that lets us look up
	#	users based on used assets.	 The output process records the
	#	reverse.
	my $userAssetIdsRefMap = buildUserAssetIdHash();
	# Reverse the pathname -> assetid map.
	my %assetNameByIdMap = reverse %assetIdByNameMap;


	foreach my $assetId (@assetIdList)
	{
		my $stillExists = exists $assetNameByIdMap{$assetId};
		if ($stillExists)
		{
			deleteAssetIfNotNeeded($assetId, \%assetNameByIdMap, $userAssetIdsRefMap, \%usedAssetIdByUserMap);
		}
		else
		{
			print STDERR "skipping removal check for asset id $assetId because it appears to be deleted.\n" if $debug;
		}
	}

	#-- Append still-existing used link entries to optimized raw filename.
	print "Marked $removedEntryCount assets out of ", scalar(@assetIdList), " for removal.\n";
	print "Writing new link entries to optimized output file [$optimizedRawFileName].\n";

	my $outputFile;
	open($outputFile, ">> " . $optimizedRawFileName) or die "Failed to open [$optimizedRawFileName] for append: $!";

	my $newLinkLineCount = 0;

	foreach my $userAssetId (keys %usedAssetIdByUserMap)
	{
		my $userAssetName = $assetNameByIdMap{$userAssetId};
		defined($userAssetName) or die "Failed to lookup asset name for asset id $userAssetId";

		my $usedAssetIdsAsString = $usedAssetIdByUserMap{$userAssetId};
		if (defined $usedAssetIdsAsString)
		{
			my @usedAssetIdArray = split /:/, $usedAssetIdsAsString;
			foreach my $usedAssetId (@usedAssetIdArray)
			{
				my $usedAssetName = $assetNameByIdMap{$usedAssetId};
				defined($usedAssetName) or die "Failed to lookup asset name for asset id $usedAssetId";

				printf $outputFile "L $userAssetName:$usedAssetName\n";
				++$newLinkLineCount;
			}
		}
	}

	# Close the output file.
	close($outputFile) or die "Failed to close optimized output file [$optimizedRawFileName]: $!";

	#-- Print link statistics.
	print  "Link statistics:\n";
	print  "\tinitial count:	   $assetLinkLineCount\n";
	print  "\toptimized count:	   $newLinkLineCount\n";
	printf "\tremoval percentage:  %.2f%%\n", 100.0 * ($assetLinkLineCount - $newLinkLineCount) / $assetLinkLineCount;
}

# ---------------------------------------------------------------------

sub loadCustomizationIdManagerMif
{
	# Create a hash mapping each id to a filename.
	my $cimVariableNameByIdRef = {};

	# Open the mif file.
	my $inputFile;
	open ($inputFile, "< " . $customizationIdManagerMifFileName) or die "Failed to open file [$customizationIdManagerMifFileName] for reading: $!";

	# Process the contents.
	my $currentId = 0;
	my $largestId = 0;
	while (<$inputFile>)
	{
		if (m/int16\s+(\d+)/)
		{
			$currentId = $1;
			$largestId = $currentId if $currentId > $largestId;
		}
		elsif (m/cstring\s+\"([^\"]+)\"/)
		{
			$$cimVariableNameByIdRef{$currentId} = $1;
			print "CustomizationIdManager (read): mapping id $currentId to $1\n" if $debug;
		}
	}

	# Close the mif file.
	close ($inputFile) or die "Failed to close file [$customizationIdManagerMifFileName]: $!";

	return ($cimVariableNameByIdRef, $largestId);
}

# ---------------------------------------------------------------------

sub assignNewCustomizationIdManagerEntries
{
	my $cidVariableNameByIdRef = shift;
	my $largestAssignedId	   = shift;

	my %cidIdByNameMap = reverse %$cidVariableNameByIdRef;
	my $newEntryCount  = 0;

	foreach my $variableName (keys %variableIdByNameMap)
	{
		if (!exists $cidIdByNameMap{$variableName})
		{
			# Assign id to the new variable name.
			my $newId = ++$largestAssignedId;

			print STDERR "New variable name [$variableName] assigned CIM id $newId\n";
			
			$cidIdByNameMap{$variableName}	 = $newId;
			$$cidVariableNameByIdRef{$newId} = $variableName;

			++$newEntryCount;
		}
	}

	# Return non-zero if we added any entries.
	return ($newEntryCount > 0);
}

# ---------------------------------------------------------------------

sub writeCustomizationIdManagerMif
{
	# Get args.
	my $cidVariableNameByIdRef = shift;
	my %cidVariableIdByName	   = reverse %$cidVariableNameByIdRef;

	# Validate max # of assignable IDs as supported by current database/string persistence format.
	my @sortedIds = sort {$b <=> $a} keys %$cidVariableNameByIdRef;
	if (scalar(@sortedIds) > 0)
	{
		my $maxUsedId = $sortedIds[0];
		die "Customization id manager supports max id of $MAX_VALID_CUSTOMIZATION_ID but application now needs $maxUsedId.  CustomizationData string persistence requires update or unnecessary new customization variable names must be removed" if ($maxUsedId > $MAX_VALID_CUSTOMIZATION_ID);
	}

	# Find directory for cim mif file.	We'll build new data into a temporary file in the same directory.
	my ($volumeName, $dirName, $unusedFileName) = File::Spec->splitpath($customizationIdManagerMifFileName);
	my $tempFileDir = File::Spec->catpath($volumeName, $dirName, "");
	print "tempFileDir=$tempFileDir\n" if $debug;

	# Create the tempfile.
	my ($outputFile, $outputFileName) = File::Temp::tempfile(DIR => $tempFileDir);
	die "failed to create tempfile: $!" if !defined($outputFile);

	my $timeString = strftime "%a %b %d %H:%M:%S %Y", localtime(time());

	print $outputFile "// ======================================================================\n";
	print $outputFile "// Output generated by Perl script \"$0\"\n";
	print $outputFile "// Generation time: $timeString\n";
	print $outputFile "//\n";
	print $outputFile "// Do not hand-edit this file!  It is generated by the build process.\n";
	print $outputFile "// Changing values from a previous run without a database update will\n";
	print $outputFile "// invalidate database-stored customization data.\n";
	print $outputFile "// ======================================================================\n\n";
	
	print $outputFile "form \"CIDM\"\n";
	print $outputFile "{\n";
	print $outputFile "\tform \"0001\"\n";
	print $outputFile "\t{\n";
	print $outputFile "\t\tchunk \"DATA\"\n";
	print $outputFile "\t\t{\n";

	foreach my $variableName (sort { $cidVariableIdByName{$a} <=> $cidVariableIdByName{$b} } keys %cidVariableIdByName)
	{
		print $outputFile "\t\t\tint16\t$cidVariableIdByName{$variableName}\n";
		print $outputFile "\t\t\tcstring\t\"$variableName\"\n\n";
	}

	print $outputFile "\t\t}\n";
	print $outputFile "\t}\n";
	print $outputFile "}\n";

	close($outputFile) or die "Failed to close CIM file [$outputFileName]: $!";

	# Rename temporary file to real name now that it's been created successfully.
	rename $outputFileName, $customizationIdManagerMifFileName;

	print "<success: wrote new customization id manager data file [$customizationIdManagerMifFileName]>\n" if $debug;
}

# ---------------------------------------------------------------------

sub updateCustomizationIdManagerData
{
	# Load the customization id manager data file.
	my ($cidVariableNameByIdRef, $largestAssignedId) = loadCustomizationIdManagerMif;

	# Add any missing entries from variable name data.
	my $updateNeeded = assignNewCustomizationIdManagerEntries($cidVariableNameByIdRef, $largestAssignedId);

	# Write the customization id manager data file.
	writeCustomizationIdManagerMif($cidVariableNameByIdRef);
}

# =====================================================================
# Main Program
# =====================================================================

processCommandLine(@ARGV);

# Initialize the program.
installApp();

# Process the raw input data.
processRawInputData();

# This program operates in two mutually-exclusive modes: normal output mode
# and remove-unneeded-entries mode.
if ($removeEntries)
{
	# Optimize the amount of data in the data file by removing
	# entries that do not help us find used customization variables.
	removeEntries();
}
else
{
	# Write out the output data.
	writeOutputData();

	# Update customization id manager data.
	if (defined($customizationIdManagerMifFileName))
	{
		updateCustomizationIdManagerData();
	}
	else
	{
		print STDERR "Warning: customization id manager data not updated, please use -m flag.\n";
	}
}

# Cleanup - counterpart to initialize function.
removeApp();

# Done, success.
exit 0;

# =====================================================================
