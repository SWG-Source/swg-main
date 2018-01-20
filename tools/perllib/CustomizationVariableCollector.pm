# ======================================================================
# CustomizationVariableCollector.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package CustomizationVariableCollector;
use strict;

use Iff;
use TreeFile;

# ======================================================================
# CustomizationVariableCollector public variables.
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
@EXPORT_OK = qw(&logAssetLink &logPaletteColorVariable &logBasicRangedIntVariable &collectData);

# ======================================================================
# CustomizationVariableCollector private variables.
# ======================================================================

my %handlerByTag;
my $debug = 0;

# ======================================================================
# CustomizationVariableCollector public functions.
# ======================================================================

# ----------------------------------------------------------------------
# Collection Output Format
#
# Asset Linkage Information:
#	L userAssetTreeFilePath:usedAssetTreeFilePath
#
# Customization Variable Usage:
#
#	Palette Color Variable Type:
#	  P assetTreeFilePath:variablePathName:paletteFilename:defaultIndex
#
#	Basic Ranged Int Type:
#	  I assetTreeFilePath:variablePathName:minValue:maxValuePlusOne:defaultValue
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
# @syntax  logAssetLink(assetPathName, subordinateAssetPathName)
#
# Used to indicate that assetPathName makes use of
# subordianteAssetPathName.	 A user of assetPathName will get
# customization variables it declares and any variables declared by
# everything assetPathName links to directly
# (i.e. subordinateAssetPathName) and indirectly (e.g. things that
# subordinateAssetPathName links to and so on).
# ----------------------------------------------------------------------

sub logAssetLink
{
	my $assetPathName = shift;
	die "assetPathName arg not specified" if !defined ($assetPathName);
	$assetPathName =~ s!\\!/!g;

	my $subordinateAssetPathName = shift;
	die "subordinateAssetPathName arg not specified" if !defined ($subordinateAssetPathName);
	$subordinateAssetPathName =~ s!\\!/!g;

	if ($subordinateAssetPathName eq $assetPathName)
	{
		return;
	}

	print "L $assetPathName:$subordinateAssetPathName\n";
}

# ----------------------------------------------------------------------
# @syntax  logPaletteColorVariable(assetPathName, variablePathName, palettePathName, defaultIndex)
#
# Used to indicate that the specified assetPathName makes use of a
# variable named variablePathName.	The variable controls a palette
# color selected from palettePathName.	A reasonable default color for
# the asset is the palette entry at defaultIndex.
# ----------------------------------------------------------------------

sub logPaletteColorVariable
{
	die "Not enough arguments" if scalar(@_) < 4;

	my $assetPathName	 = shift;
	$assetPathName =~ s!\\!/!g;

	my $variablePathName = shift;

	my $palettePathName	 = shift;
	$palettePathName =~ s!\\!/!g;

	my $defaultIndex	 = shift;

	print "P $assetPathName:$variablePathName:$palettePathName:$defaultIndex\n";
}

# ----------------------------------------------------------------------
# @syntax  logBasicRangedIntVariable(assetPathName, variablePathName, minValueInclusive, maxValueExclusive, defaultValue)
#
# Used to indicate that the specified assetPathName makes use of a
# variable named variablePathName.	The variable controls a basic
# ranged int that somehow affects the visual appearance.  A reasonable
# default value for the asset is specified with defaultValue.
# ----------------------------------------------------------------------

sub logBasicRangedIntVariable
{
	die "Not enough arguments" if scalar(@_) < 5;

	my $assetPathName	  = shift;
	$assetPathName =~ s!\\!/!g;

	my $variablePathName  = shift;
	my $minValueInclusive = shift;
	my $maxValueExclusive = shift;
	my $defaultValue	  = shift;

	print "I $assetPathName:$variablePathName:$minValueInclusive:$maxValueExclusive:$defaultValue\n";
}

# ----------------------------------------------------------------------
# @syntax  registerHandler(formTagHandled, handlerFunctionRef)
#
# Associates the specified handlerFunctionRef function with the
# specified top-level IFF form tag formTagHandled.	During execution
# of collectCustomizationData, any IFF file with a first form that
# matches formTagHandled will have an IFF opened and passed to
# handlerFunctionRef like this:
#
#	&$handlerFunctionRef(iffRef, treeFilePathName)
#
# The iff pointed to by iffRef will be at the very beginning of the file,
# in a completely unread state.	 The handlerFunction should return non-zero
# on success and zero on failure.  Failure will cancel the collection
# process with an error.
# ----------------------------------------------------------------------

sub registerHandler
{
	# Handle args.
	die "Too few arguments" if @_ < 2;
	my $formTag	   = shift;
	my $handlerRef = shift;

	# Ensure we don't clobber another handler.
	die "form tag [$formTag] is already handled, multiple handlers per tag not supported" if exists $handlerByTag{$formTag};

	# Assign the handler.
	$handlerByTag{$formTag} = $handlerRef;
}

# ----------------------------------------------------------------------
# @syntax  unregisterHandler(formTagHandled)
#
# Remove support for the specified top-level iff form.
# ----------------------------------------------------------------------

sub unregisterHandler
{
	# Handle args.
	die "Too few arguments" if @_ < 1;
	my $formTag	   = shift;

	# Ensure we have this handler.
	die "form tag [$formTag] is not currently handled" if !exists $handlerByTag{$formTag};

	# Remove the handler from the hash.
	delete $handlerByTag{$formTag};
}

# ----------------------------------------------------------------------
# Callback for TreeFile::findRelativeRegexMatch.
# ----------------------------------------------------------------------

sub processTreeFile
{
	# Open the file.
	my $fileHandle;
	die "failed to open [$TreeFile::fullPathName]: $!" if !open($fileHandle, "< " . $TreeFile::fullPathName);

	# Get an Iff for the specified pathname.
	my $iff = Iff->createFromFileHandle($fileHandle);

	# Close the file.
	die "failed to close [$TreeFile::fullPathName]: $!" if !close($fileHandle);

	# Skip the file if it wasn't a valid iff.
	if (!defined($iff))
	{
		print STDERR "iff error: [$TreeFile::fullPathName] does not appear to be a valid IFF, skipping.\n";
		return;
	}

	# Get the first name.
	my $name = $iff->getCurrentName();
	die "iff: getCurrentName() failed" if !defined($name);

	# Lookup handler function for name.
	my $handlerRef = $handlerByTag{$name};
	if (!defined($handlerRef))
	{
		return;
	}

	# Call handler function.
	my $handleResult = &$handlerRef($iff, $TreeFile::relativePathName, $TreeFile::fullPathName);
	die "iff error: handler failed to process file [$TreeFile::fullPathName]\n" if !$handleResult;

	print "debug: successfully processed [$TreeFile::relativePathName].\n" if $debug;
}

# ----------------------------------------------------------------------
# @syntax  collectData(treeFileRegexArray)
#
# Processes all treefiles with TreeFile-relative pathnames matching
# any one of the regex entries listed in treeFileRegexArray.  For
# files matching top-level-form file IDs registered for handling with 
# this module, the version handler will be called upon to process the
# data.	 These handlers will output asset linkage and customization
# variable data (basic ranged int type = default, min and max values;
# palette color type = default index and palette name).
# ----------------------------------------------------------------------

sub collectData
{
	TreeFile::findRelativeRegexMatch(\&processTreeFile, @_);
}

# ======================================================================

1;
