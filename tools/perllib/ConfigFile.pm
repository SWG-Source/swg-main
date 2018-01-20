# ======================================================================
# Perl SOE config file access
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package ConfigFile;
use strict;

# ======================================================================
# Setup variables that can be imported by Exporter into user modules.
# ======================================================================

use vars qw(@ISA @EXPORT_OK $VERSION);
use Exporter;
$VERSION = 1.00;
@ISA	 = qw(Exporter);

# These symbols are okay to export if specifically requested.
@EXPORT_OK = qw(&processConfigFile &getVariableAsArray &getVariablesMatchingRegex);

# ======================================================================
# ConfigFile private variables.
# ======================================================================

my %sectionHash;
my $debug = 0;
my $currentSectionName = "global";

# ======================================================================
# ConfigFile public functions.
# ======================================================================

# Forward declare this so it can be called within processConfigFile.
sub processConfigFile;

sub processConfigFile
{
	my $fileName = shift;
	print "BEGIN: processing file [$fileName].\n" if $debug;

	# Convert backslashes to forward slashes.
	$fileName =~ s!\\!/!g;
	
	# Strip off directory path for use in include resolution.
	my $directoryPath = $fileName;
	$directoryPath =~ s!^(.*/)[^/]+$!$1!;

	my $file;
	open($file, '<' . $fileName) or die "failed to open file [$fileName]: $!";

	while (<$file>)
	{
		chomp();
		my $line = $_;

		if ($line =~ m/\.include\s*\"([^\"]*)\"/)
		{
			my $fullIncludePath = $directoryPath . $1;
			print "Found include directive for file [$1], using full path [$fullIncludePath].\n" if $debug;
			processConfigFile $fullIncludePath;
		}
		elsif ($line =~ m/\[\s*(\w+)\s*\]/)
		{
			print "Found start of section [$1]\n" if $debug;
			$currentSectionName = $1;
			
		}
		elsif ($line =~ m/\s*(\w+)\s*=\s*([^\s]+)/)
		{
			print "\tvariable [$1] = [$2]\n" if $debug;

			# Make sure array reference exists for this section variable.
			if (!defined($sectionHash{$currentSectionName}->{$1}))
			{
				$sectionHash{$currentSectionName}->{$1} = [];
			}

			# Add value to array of values for this given section variable name.
			my $arrayRef = $sectionHash{$currentSectionName}->{$1};
			push(@$arrayRef,$2);
		}
	}

	close($file);
	print "END: processing file [$fileName].\n" if $debug;
}

# ----------------------------------------------------------------------
# @syntax  getValueAsArray(sectionName,variableName)
#
# @return  an array containing copies of all values assigned to the 
#		   specified variable, one value per array entry.
# ----------------------------------------------------------------------

sub getVariableAsArray
{
	# Get hash mapping variables to value arrays for the given section name.
	my $sectionName	 = shift;
	if (!exists $sectionHash{$sectionName})
	{
		# Section name didn't appear.
		return ();
	}
	my $sectionHashRef = $sectionHash{$sectionName};

	# Get array of values for the specified variable name.
	my $variableName = shift;
	if (!exists $$sectionHashRef{$variableName})
	{
		# Variable name didn't appear in section.
		return ();
	}
	my $valueArrayRef = $$sectionHashRef{$variableName};

	# Return a copy of the value array.
	return @$valueArrayRef;
}

# ----------------------------------------------------------------------
# @syntax  getVariablesMatchingRegex(sectionName, variableNameRegex)
#
# @return  a hash of all variables with a name matching variableNameRegex
#		   within the given section name.  Each key is the name of a variable;
#		   the value for each key is an array reference where the array contains
#		   copies of all values assigned to the variable name.
# ----------------------------------------------------------------------

sub getVariablesMatchingRegex
{
	# Get hash mapping variables to value arrays for the given section name.
	my $sectionName	 = shift;
	if (!exists $sectionHash{$sectionName})
	{
		# Section name didn't appear.
		return ();
	}
	my $sectionHashRef = $sectionHash{$sectionName};

	# Test all variables in the section against $variableNameRegex.
	my $variableNameRegex = shift;
	my %returnHash = ();

	foreach my $variableName (keys %$sectionHashRef)
	{
		if ($variableName =~ m/$variableNameRegex/)
		{
			# Return a reference to an array containing value entries for the variable.
			$returnHash{$variableName} = [ getVariableAsArray($sectionName, $variableName) ];
		}
	}

	return %returnHash;
}

# ======================================================================

1;
