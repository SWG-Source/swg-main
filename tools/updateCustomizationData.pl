#!/usr/bin/perl

use strict;

use Perforce;

# ----------------------------------------------------------------------

sub appendNonCommentContents
{
	my $sourceFileName = shift;
	my $targetFileName = shift;

	# Only append if the source file exists.
	if (-f $sourceFileName)
	{
		# Append the non-comment, non-empty lines of $sourceFileName to $targetFileName.
		my $sourceFileHandle;
		open($sourceFileHandle, "< $sourceFileName") or die "failed to open file name [$sourceFileName] for reading: $!";
		print "Appending contents of file [$sourceFileName] to file [$targetFileName].\n";

		my $targetFileHandle;
		open($targetFileHandle, ">> $targetFileName") or die "failed to open file name [$targetFileName] for appending: $!";

		while (<$sourceFileHandle>)
		{
			chomp();

			# Skip comment lines or blank lines.
			next if (m/^\s*\#/) or (m/^\s*$/);

			# Append to the target file.
			print $targetFileHandle "$_\n";
		}

		close($targetFileHandle) or die "failed to close append file [$targetFileName]: $!";
		close($sourceFileHandle) or die "failed to close source file [$sourceFileName]: $!";
	}
}

# ----------------------------------------------------------------------

sub sortUnique
{
	my ($inputFileName, $outputFileName) = @_;
	
	open(my $inputFile, '< ' . $inputFileName) or die ("failed to open [$inputFileName]: $!");
	my @lines = <$inputFile>;
	close($inputFile) or die ("failed to close [$inputFileName]: $!");
	
	open(my $outputFile, '> ' . $outputFileName) or die ("failed to open [$outputFileName]: $!");
	
	my %dataHash = map { $_ => 1 } @lines;
	print $outputFile sort keys %dataHash;

	close($outputFile) or die ("failed to close [$outputFileName]: $!");
}

# ----------------------------------------------------------------------

die "usage: updateCustomizationData.pl [-s <skipToStep>] branchName" if @ARGV < 1;

# ----------------------------------------------------------------------

# Process args.
my $skipToStep = 0;
my $debug	   = 0;

if ($ARGV[0] eq '-d')
{
	shift;
	$debug = 1;
}

if ($ARGV[0] eq '-s')
{
	shift;
	die "-s <skipToStep> requires a step number. I don't understand [$ARGV[0]]" if !($ARGV[0] =~ m/^\d+$/);
	$skipToStep = $ARGV[0];
	shift;
}
elsif ($ARGV[0] =~ m/^-/)
{
	die "unsupported option $ARGV[0]";
}

# Get branch.
my $branch = shift;
$branch =~ m/^(current|test|live|x1|x2|s0|s1|s2|s3|s4|s5|s6|s7|s8|s9)$/ or die "specified branch is unknown.";
print "Using branch: $branch\n";

# Checkout customization-related files.
my $commandOutput;
my $scriptName;

print "Step 1: Checking out customization-related files.\n";
$commandOutput = `p4 edit //depot/swg/$branch/dsrc/sku.0/sys.shared/compiled/game/customization/*.mif //depot/swg/$branch/data/sku.0/sys.shared/compiled/game/customization/*.iff`;
die "p4 edit failed on customization files: [$?] [$commandOutput]" if ($? != 0);

# Generate treefile lookup table.
my $treefileLookupDataFileName;

if ($skipToStep <= 2)
{
	print "Step 2: Generating treefile lookup table.\n";
	$scriptName    = Perforce::findOnDiskFileName("//depot/swg/$branch/tools/buildTreeFileLookupTable.pl");
	$commandOutput = `perl $scriptName $branch`;
	$commandOutput =~ m/treefile lookup pathname: \[([^\]]+)\]/ or die "failed to find treefile lookup table name from output:\n$commandOutput";
	$treefileLookupDataFileName = $1;
}
else
{
	print "Looking for treefile lookup table:\n" if $debug;
	my @filenameChoices = glob "treefile-xlat-$branch-*.dat";
	die "Could not find treefile lookup table matching filename 'treefile-xlat-$branch-*.dat': $!" if (@filenameChoices < 1);

	# Use the highest-numbered change list.
	my $changelist = 0;

	foreach my $filename (@filenameChoices)
	{
		print "\tchecking $filename\n" if $debug;
		if ($filename =~ m/treefile-xlat-$branch-(\d+)/)
		{
			if ($1 > $changelist)
			{
				$changelist = $1;
				$treefileLookupDataFileName = $filename;
			}
		}
		
	}
	die "Failed to find a suitable treefile lookup table, can't skip step 2" if !defined($treefileLookupDataFileName);

	print "Using treefile lookup table: $treefileLookupDataFileName\n";
}

# Collect raw customization info.
my $unoptimizedCustomizationInfoFileName = "custinfo-raw.dat";

if ($skipToStep <= 3)
{
	print "Step 3a: Collecting unoptimized customization variable and linkage info from all assets.\n";
	$scriptName = Perforce::findOnDiskFileName("//depot/swg/$branch/tools/collectAssetCustomizationInfo.pl");
	`perl $scriptName -b $branch -t $treefileLookupDataFileName > $unoptimizedCustomizationInfoFileName`;
	die "Failed to collect unoptimized assets [$?]" if ($? != 0);

	# Append contents of force_add_variable_usage.dat to the raw data.
	print "Step 3b: Appending forced variable usage information.\n";
	my $forceAddInfoFileName = Perforce::findOnDiskFileName("//depot/swg/$branch/dsrc/sku.0/sys.shared/compiled/game/customization/force_add_variable_usage.dat");
	appendNonCommentContents($forceAddInfoFileName, $unoptimizedCustomizationInfoFileName);
}

# Optimize the customization info.
my $optimizedCustomizationInfoFileName = "custinfo-raw-optimized.dat";
my $optimizedUniqueCustomizationInfoFileName = "custinfo-raw-optimized-unique.dat";
my $artAssetReportFileName			   = "art-asset-customization-report.log";

$scriptName = Perforce::findOnDiskFileName("//depot/swg/$branch/tools/buildAssetCustomizationManagerData.pl");

if ($skipToStep <= 4)
{
	print "Step 4a: Optimizing customization variable info.\n";
	my $debugFlag = $debug ? '-d' : '';
	print "Executing: [perl $scriptName $debugFlag -a $artAssetReportFileName -i $unoptimizedCustomizationInfoFileName -r -t $treefileLookupDataFileName]\n" if $debug;
	$commandOutput = `perl $scriptName $debugFlag -a $artAssetReportFileName -i $unoptimizedCustomizationInfoFileName -r -t $treefileLookupDataFileName`;
	if ($? != 0)
	{
		die "Failed to optimize customization info: [$?]\n$commandOutput" if ($? != 0);
	}
	else
	{
		print "output begin:\n$commandOutput\noutput end\n" if $debug;
	}

	# Remove duplicate lines from the custoimzation info.
	print "Step 4b: Removing duplicate entries from optimized customization info.\n";
	sortUnique($optimizedCustomizationInfoFileName, $optimizedUniqueCustomizationInfoFileName);
}

# Build asset_customization_manager.mif and customization_id_manager.mif data.
my $acmMifFileName = Perforce::findOnDiskFileName("//depot/swg/$branch/dsrc/sku.0/sys.shared/compiled/game/customization/asset_customization_manager.mif");
die "Failed to find asset_customization_manager.mif's location on disk" if !defined($acmMifFileName) || !length($acmMifFileName);

my $cimMifFileName = Perforce::findOnDiskFileName("//depot/swg/$branch/dsrc/sku.0/sys.shared/compiled/game/customization/customization_id_manager.mif");
die "Failed to find customization_id_manager.mif's location on disk" if !defined($cimMifFileName) || !length($cimMifFileName);

if ($skipToStep <= 5)
{
	print "Step 5: Building asset customization manager and customization id manager data.\n";
	$commandOutput = `perl $scriptName -i $optimizedUniqueCustomizationInfoFileName -o $acmMifFileName -m $cimMifFileName -t $treefileLookupDataFileName`;
	die "Failed to build asset customization info from optimized asset info: [$?]\n$commandOutput" if ($? != 0);
}

# Miff the output.
my $acmIffFileName = Perforce::findOnDiskFileName("//depot/swg/$branch/data/sku.0/sys.shared/compiled/game/customization/asset_customization_manager.iff");
die "Failed to find asset_customization_manager.iff's location on disk" if !defined($acmIffFileName) || !length($acmIffFileName);

my $cimIffFileName = Perforce::findOnDiskFileName("//depot/swg/$branch/data/sku.0/sys.shared/compiled/game/customization/customization_id_manager.iff");
die "Failed to find customization_id_manager.iff's location on disk" if !defined($cimIffFileName) || !length($cimIffFileName);

if ($skipToStep <= 6)
{
	print "Step 6a: Running miff on optimized asset customization manager data.\n";
	$commandOutput = `miff -i $acmMifFileName -o $acmIffFileName 2>&1`;
	die "Failed to miff -i $acmMifFileName -o $acmIffFileName: [$?] [$commandOutput]" if ($? != 0);

	print "Step 6b: Running miff on customization id manager file.\n";
	$commandOutput = `miff -i $cimMifFileName -o $cimIffFileName 2>&1`;
	die "Failed to miff -i $cimMifFileName -o $cimIffFileName: [$?] [$commandOutput]" if ($? != 0);
}

print "Done.  User is responsible for checking in changes to perforce and cleaning up temporary files.\n";
