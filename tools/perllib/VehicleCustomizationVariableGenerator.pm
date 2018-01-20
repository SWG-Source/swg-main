# ======================================================================
# VehicleCustomizationVariableGenerator.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package VehicleCustomizationVariableGenerator;
use strict;

use CustomizationVariableCollector;
use Perforce;
use TreeFile;

# ======================================================================
# VehicleCustomizationVariableGenerator public variables.
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
#@EXPORT_OK = qw(&buildFileLookupTable &saveFileLookupTable &loadFileLookupTable &getFullPathName);
@EXPORT_OK = qw(&install &collectData);

# ======================================================================
# VehicleCustomizationVariableGenerator private variables.
# ======================================================================

# my %handlerByTag;
my $debug = 0;
my %variableInfoByName;
my %vehicleSatToSaddleAppearanceMap;

# ======================================================================
# VehicleCustomizationVariableGenerator public functions.
# ======================================================================

sub install
{
}

# ----------------------------------------------------------------------

sub loadVehicleCustomizations
{
	# Process args.
	my $customizationsFileName = shift;

	my $fileHandle;
	open($fileHandle, '< ' . $customizationsFileName) or die "failed to load vehicle variable customizations file [$customizationsFileName]: $!";

	# Skip first two lines: the tab file header.
	$_ = <$fileHandle>;
	$_ = <$fileHandle>;

	# Grab all variable definitions.
	while (<$fileHandle>)
	{
		chomp;
		# Pattern: <name>\t<min val>\t<max val>\t<default>\t<conversion comment>
		if (m/([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t/)
		{
			my $name         = $1;
			my $minValue     = $2;
			my $maxValue     = $3;
			my $defaultValue = $4;

			print "vehicle customization definition: var=[$name], min=[$minValue], max=[$maxValue], default=[$defaultValue].\n" if $debug;
			$variableInfoByName{$name} = $minValue . ':' . $maxValue . ':' . $defaultValue;
			print "assigned as [$variableInfoByName{$name}]\n" if $debug;
		}
		else
		{
			print STDERR "failed to parse vehicle customization entry [$_] in file [$customizationsFileName]\n";
		}
	}

	close($fileHandle) or die "failed to close file handle for [$customizationsFileName]: $!";
}

# ----------------------------------------------------------------------

sub applyCustomizationsToVehicles
{
	# Handle args.
	my $appearanceTableFileName = shift;

	my $fileHandle;
	open($fileHandle, '< ' . $appearanceTableFileName) or die "failed to load vehicle variable customizations file [$appearanceTableFileName]: $!";

	# Skip first two lines: the tab file header.
	$_ = <$fileHandle>;
	$_ = <$fileHandle>;

	# Get keys for the vehicle info array.
	my @variableNameArray = sort keys %variableInfoByName;

	# Loop through all appearances.
	my @saddleAppearanceNameArray;

	while (<$fileHandle>)
	{
		chomp;
		if (m/^(\S+)/)
		{
			my $appearanceName = $1;
			print "vehicle appearance: processing [$appearanceName]\n" if $debug;
			foreach my $variableName (@variableNameArray)
			{
				my $variableInfo = $variableInfoByName{$variableName};
				my @variableInfoArray = split /:/, $variableInfo;
				my $variableCount = scalar(@variableInfoArray);
				die "Internal error: variableInfoArray does not contain expected 3 elements [$variableCount]" if $variableCount != 3;

				my $minValueInclusive = $variableInfoArray[0];
				my $maxValueExclusive = $variableInfoArray[1];
				my $defaultValue      = $variableInfoArray[2];

				CustomizationVariableCollector::logBasicRangedIntVariable($appearanceName, $variableName, $minValueInclusive, $maxValueExclusive, $defaultValue);
			}

			# Link this .sat appearance name to all saddle appearances (non-sat, static)
			# so that the top-level .sat appearance appears to expose all the customization
			# variables exposed by the non-sat, visible vehicle saddle appearances.
			my $nameArrayString = $vehicleSatToSaddleAppearanceMap{$appearanceName};
			if (defined($nameArrayString))
			{
				@saddleAppearanceNameArray = split(/:/, $nameArrayString);
				foreach my $saddleAppearanceName (@saddleAppearanceNameArray)
				{
					CustomizationVariableCollector::logAssetLink($appearanceName, $saddleAppearanceName);
				}
			}
		}
	}
}

# ----------------------------------------------------------------------

sub buildSatLinkageMap
{
	# Setup args.
	my $logicalSaddleNameMapFileName = shift;
	my $saddleAppearanceMapFileName = shift;
	
	# Load mapping of mount/vehicle appearance to logical saddle name.
	# This can be a one to many mapping.
	my %appearanceToLsmMap;
	my $fileHandle;
	my @columns;

	open($fileHandle, '< ' . $logicalSaddleNameMapFileName) or die "buildSatLinkageMap(): could not open file [$logicalSaddleNameMapFileName]: $!";

	# Skip first two lines: the tab file header.
	$_ = <$fileHandle>;
	$_ = <$fileHandle>;
	
	# Loop through rest of file.
	while (<$fileHandle>)
	{
		# Remove end of line.
		chomp();

		# Break line entry into array elements based on tab.
		@columns = split(/\t/);

		# Column 0 is sat_or_skt_name
		# Column 1 is logical_saddle_name
		my $appearanceName = $columns[0];
		my $logicalSaddleName = $columns[1];

		# Add mapping.
		if (exists $appearanceToLsmMap{$appearanceName})
		{
			$appearanceToLsmMap{$appearanceName} .= ':' . $logicalSaddleName;
		}
		else
		{
			$appearanceToLsmMap{$appearanceName} = $logicalSaddleName;
		}
	}

	close($fileHandle) or die "buildSatLinkageMap(): could not close file [$logicalSaddleNameMapFileName]: $!";

	# Load mapping of logical saddle name to saddle appearance name.
	# This can be a one to many mapping.
	my %lsmToSaddleAppearanceMap;
	
	open($fileHandle, '< ' . $saddleAppearanceMapFileName) or die "buildSatLinkageMap(): could not open file [$saddleAppearanceMapFileName]: $!";

	# Skip first two lines: the tab file header.
	$_ = <$fileHandle>;
	$_ = <$fileHandle>;

	# Loop through contents.
	while (<$fileHandle>)
	{
		# Remove end of line.
		chomp();

		# Break line entry into array elements based on tab.
		@columns = split(/\t/);

		# Column 0 is logical_saddle_name
		# Column 2 is saddle_appearance_name
		my $logicalSaddleName = $columns[0];
		my $saddleAppearanceName = $columns[2];	

		# add mapping
		if (exists $lsmToSaddleAppearanceMap{$logicalSaddleName})
		{
			$lsmToSaddleAppearanceMap{$logicalSaddleName} .= ':' . $saddleAppearanceName;
		}
		else
		{
			$lsmToSaddleAppearanceMap{$logicalSaddleName} = $saddleAppearanceName;
		}
	}

	close($fileHandle) or die "buildSatLinkageMap(): could not close file [$saddleAppearanceMapFileName]: $!";

	# Finally, build global mapping of vehicle appearance name to saddle appearance names.
	# This is a one to many mapping.
	my @logicalSaddleNameArray;
	my @saddleAppearanceNameArray;

	foreach my $vehicleAppearanceName (keys %appearanceToLsmMap)
	{
		my $lsmArrayString = $appearanceToLsmMap{$vehicleAppearanceName};
		@logicalSaddleNameArray = split(/:/, $lsmArrayString);	
		
		foreach my $logicalSaddleName (@logicalSaddleNameArray)
		{
			my $appearanceArrayString = $lsmToSaddleAppearanceMap{$logicalSaddleName};
			next if !defined($appearanceArrayString);

			@saddleAppearanceNameArray = split(/:/, $appearanceArrayString);
			foreach my $saddleAppearanceName (@saddleAppearanceNameArray)
			{
				# Add a mapping from the vehicle appearance name to this saddle appearance name.
				if (exists $vehicleSatToSaddleAppearanceMap{$logicalSaddleName})
				{
					$vehicleSatToSaddleAppearanceMap{$vehicleAppearanceName} .= ':' . $saddleAppearanceName;
				}
				else
				{
					$vehicleSatToSaddleAppearanceMap{$vehicleAppearanceName} = $saddleAppearanceName;
				}
			}
		}
	}	
}

# ----------------------------------------------------------------------

sub collectData
{
	# Process args.  Default the branch to "current" if not specified.
	my $branch = shift;
	$branch = "current" if !defined($branch);

	# Constants.
	my $vehicleDataP4Root = "//depot/swg/$branch/dsrc/sku.0/sys.shared/compiled/game/customization/";
	
	# Load up the vehicle customizations to associate with every ridable vehicle.
	my $customizationsFileName = Perforce::findOnDiskFileName($vehicleDataP4Root . "vehicle_customizations.tab");
	loadVehicleCustomizations($customizationsFileName);

	# Load up mapping of vehicle .sat appearance (invisible) to vehicle saddle appearance (visible).
	# This is a one-to-many mapping.
	my $saddleDataP4Root = "//depot/swg/$branch/dsrc/sku.0/sys.shared/compiled/game/datatables/mount/";
	my $logicalSaddleNameMapFileName = Perforce::findOnDiskFileName($saddleDataP4Root . "logical_saddle_name_map.tab");
	my $saddleAppearanceMapFileName = Perforce::findOnDiskFileName($saddleDataP4Root . "saddle_appearance_map.tab");
	buildSatLinkageMap($logicalSaddleNameMapFileName, $saddleAppearanceMapFileName);
	
	# Add appropriate variable declarations for each vehicle appearance listed in the vehicle appearances table.
	my $appearanceTableFileName = Perforce::findOnDiskFileName($vehicleDataP4Root . "vehicle_appearances.tab");
	applyCustomizationsToVehicles($appearanceTableFileName);
}

# ======================================================================

1;
