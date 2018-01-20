# ======================================================================
# Perl SOE TreeFile (loose file only) support
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package TreeFile;
use strict;

use ConfigFile;
use Cwd qw(:DEFAULT abs_path);
use File::Find;
use File::Spec::Unix;

# ======================================================================
# TreeFile potentially-public variables.
# ======================================================================

# File::Find-like variables.
our $relativePathName;
our $fullPathName;

# ======================================================================
# Setup variables that can be imported by Exporter into user modules.
# ======================================================================

use vars qw(@ISA @EXPORT_OK $VERSION);
use Exporter;
$VERSION = 1.00;
@ISA	 = qw(Exporter);

# These symbols are okay to export if specifically requested.
# @EXPORT_OK = qw(&buildFileLookupTable &saveFileLookupTable &loadFileLookupTable &getFullPathName $relativePathName $fullPathName);
@EXPORT_OK = qw(&buildFileLookupTable &saveFileLookupTable &loadFileLookupTable &getFullPathName &findRelative &findRelativeRegexMatch);

# ======================================================================
# TreeFile private variables.
# ======================================================================

my $debug = 0;

my @directoryRootedPath			 = ();
my @directoryPriority			 = ();
my %directoryIndexByRelativeName = ();

my $findBasePathName;
my $findBasePathIndex;
my $printDuplicateFiles;

# ======================================================================
# TreeFile public functions.
# ======================================================================

# ----------------------------------------------------------------------
# TreeFile lookup table file format
#
# [1 or more of the following. These will always be listed from highest
# priority to least priority.  These will always end with a /, see e
# entry description.]
#
# p <rootedSearchPath>:<priority>
#
# [0 or more of the following. All p lines exist prior to the first e line
# within the file.]
#
# e <treefileRelativePath>:<rootedPathIndex>
#
# The rootedPathIndex is the 0-based index of the p entry that contains
# the treefile specified.  The full path should be the p path concatenated
# with the e pathname.
# ----------------------------------------------------------------------

sub sortTreefileHighestFirst
{
	my $testForA = $a; 
	$testForA =~ s/searchPath//; 

	my $testForB = $b; 
	$testForB =~ s/searchPath//; 

	$testForB <=> $testForA;
}

# ----------------------------------------------------------------------
# syntax: buildRootedDirectories(baseDirectory)
#
# Setup rooted directories from the ConfigFile treefile declarations.
# ----------------------------------------------------------------------

sub buildRootedDirectories
{
	# Clear out any existing entries.
	@directoryRootedPath = ();
	@directoryPriority	 = ();

	# Setup parameters.
	my $baseDirectory = shift;

	# Grab the searchPath* entries from ConfigFile.
	my %values = ConfigFile::getVariablesMatchingRegex("SharedFile", "^searchPath");

	foreach my $variableName (sort sortTreefileHighestFirst keys %values)
	{
		print STDERR "processing TreeFile config file declarations with tag $variableName.\n" if $debug;

		if ($variableName =~ m/(\d+)/)
		{
			my $priority = $1;
			print STDERR "directory priority = $priority.\n" if $debug;

			my $pathArrayRef = $values{$variableName};
			foreach my $path (@$pathArrayRef)
			{
				print STDERR "\tpath=[$path]\n" if $debug;

				# Convert path from relative to absolute via $baseDirectory arg.
				my $isRelative = ! File::Spec::Unix->file_name_is_absolute($path);
				if ($isRelative)
				{
					$path = $baseDirectory . '/' . $path;
				}

				# Check if the directory exists.
				if (-d $path)
				{
					# Canonicalize the path (remove directory self references, back references and symbolic paths).
					$path = abs_path($path);
					$path .= '/' if !($path =~ m!/$!);
					print STDERR "\tcanonicalized path=[$path]\n" if $debug;

					push @directoryRootedPath, $path;
					push @directoryPriority, $priority;
				}
			}
		}
	}

	# Ensure directory root path and directory priority arrays don't end up out of sync.
	die "arrays out of sync" if (scalar @directoryRootedPath) != (scalar @directoryPriority);
}

# ----------------------------------------------------------------------

sub findFileProcessor
{
	# Ensure we're talking about a regular file that is readable by the
	# caller.
	if ( -f && -r )
	{
		# Build treefile-relative name by stripping off base directory.
		my $relativePathName = $File::Find::name;
		$relativePathName =~ s/$findBasePathName//;

		# Check for dupes.
		my $isDupe = exists $directoryIndexByRelativeName{$relativePathName};
		if ($isDupe)
		{
			print "dupe found: relative=[$relativePathName], full=[$File::Find::name]\n" if $printDuplicateFiles;
		}
		else
		{
			$directoryIndexByRelativeName{$relativePathName} = $findBasePathIndex;
		}

		if ($debug)
		{
			print STDERR "Processing File\n";
			print STDERR "\t[$File::Find::name]\n";
			print STDERR "\trelative name: [$relativePathName]\n";
			print STDERR "\tDUPLICATE\n" if $isDupe;
		}
	}
}

# ----------------------------------------------------------------------
# @syntax buildFileLookupTable [reportDuplicates [relativeToPath]]
#
# @param reportDuplicates  if non-zero, report duplicate files (i.e. files
#						   with identical treefile-relative pathnames that
#						   exist in multiple locations on disk.)  Defaults
#						   to false.
#
# @param relativeToPath	   if specified, specifies the base directory to
#						   use for treefile searchpath specifications that
#						   are not rooted (i.e. relative paths).  Defaults
#						   to the current directory.
#
# Prior to calling any of the filename lookup functions like getFullPath(),
# either buildFileLookupTable() or loadFileLookupTable() must be called.
# To generate the lookup table file, call buildFileLookupTable() and save
# it with saveFileLookupTable().  This lookup information then can be
# loaded directly from the file for subsequent runs on the same machine
# with the same data.  If new files are added, the lookup data must be
# regenerated or it will become stale.
#
# ConfigFile must have been setup and must have processed any applicable
# TreeFile-related searchPath declarations prior to calling this function.
# ----------------------------------------------------------------------

sub buildFileLookupTable
{
	# Setup arguments.
	$printDuplicateFiles = shift;
	$printDuplicateFiles = 0 if !defined($printDuplicateFiles);

	my $relativeToPath = shift;
	$relativeToPath = getcwd() if !defined($relativeToPath);

	# Build TreeFile rooted search paths.
	buildRootedDirectories($relativeToPath);

	# Do a find-all-files on each rooted search path, populating %directoryIndexByRelativeName.
	%directoryIndexByRelativeName = ();

	my $pathCount = scalar @directoryRootedPath;
	for ($findBasePathIndex = 0; $findBasePathIndex < $pathCount; ++$findBasePathIndex)
	{
		$findBasePathName = $directoryRootedPath[$findBasePathIndex];
		File::Find::find(\&findFileProcessor, ($findBasePathName));
	}
}

# ----------------------------------------------------------------------
# @syntax  saveFileLookupTable(fileHandleRef)
#
#		   Saves the lookup table to the specified filehandle reference.
#		   If unspecified, writes to STDOUT.
# ----------------------------------------------------------------------

sub saveFileLookupTable
{
	my $outputFileRef = shift;
	$outputFileRef = \*STDOUT if !defined($outputFileRef);

	my $searchPathCount = scalar @directoryRootedPath;
	die "Directory data out of sync" if ($searchPathCount != scalar @directoryPriority);

	for (my $i = 0; $i < $searchPathCount; ++$i)
	{
		my $rootedSearchPath = $directoryRootedPath[$i];
		my $priority		 = $directoryPriority[$i];

		print $outputFileRef "p $rootedSearchPath:$priority\n";
	}

	foreach my $relativePathName (sort keys %directoryIndexByRelativeName)
	{
		my $directoryIndex = $directoryIndexByRelativeName{$relativePathName};
		print $outputFileRef "e $relativePathName:$directoryIndex\n";
	}
}

# ----------------------------------------------------------------------
# @syntax  loadFileLookupTable(fileHandleRef)
#
#		   Loads the lookup table from the specified filehandle reference.
#		   If unspecified, reads from STDIN.
# ----------------------------------------------------------------------

sub loadFileLookupTable
{
	# Clear the treefile data structures.
	@directoryRootedPath		  = ();
	@directoryPriority			  = ();
	%directoryIndexByRelativeName = ();

	# Process args.
	my $inputFileRef = shift;
	$inputFileRef = \*STDIN if !defined($inputFileRef);

	# Process the file contents.
	while (<$inputFileRef>)
	{
		chomp();
		if (m/^p\s+(.+):(\d+)$/)
		{
			# Handle the rooted base path directive.
			my $rootedBasePathName = $1;
			my $priority		   = $2;

			push @directoryRootedPath, $rootedBasePathName;
			push @directoryPriority,   $priority;
		}
		elsif (m/^e\s+(.+):(\d+)$/)
		{
			# Handle the treefile entry directive.
			my $relativePathName = $1;
			my $directoryIndex	 = $2;

			$directoryIndexByRelativeName{$relativePathName} = $directoryIndex;
		}
		else
		{
			die "Unexpected load file input, line=[$_].\n"; 
		}
	}

	# Validate directory structures.
	die "arrays out of sync" if (scalar @directoryRootedPath) != (scalar @directoryPriority);
}

# ----------------------------------------------------------------------
# @syntax  getFullPathName(treefileRelativePathName)
#
# @param   treefileRelativePathName	 this is a pathname as used within
#									 the game, relative to the TreeFile system.
#									 These filenames are never rooted, always relative.
#
# @return  the rooted full loose-file pathname for the given
#		   treefile-relative pathname; returns undef if not found.
# ----------------------------------------------------------------------

sub getFullPathName
{
	# Handle arguments.
	my $relativePathName = shift;
	return undef if !defined($relativePathName);

	# Get rooted directory index where specified relative pathname lives.
	my $directoryIndex = $directoryIndexByRelativeName{$relativePathName};
	return undef if !defined($directoryIndex);

	# Build full pathname, return to caller.
	my $fullPathName = $directoryRootedPath[$directoryIndex] . $relativePathName;
	return $fullPathName;
}

# ----------------------------------------------------------------------
# Operates similar to File::Find::find, operating over the TreeFile-relative
# filename namespace instead of the normal OS filesystem namespace.
#
# @syntax  findRelative(callbackReference, treefileRelativeDirectoryList)
#
# @param  callbackReference	 the function referenced by this arg will be
#							 called for each file in the treefile relative 
#							 filename domain that starts with one of the
#							 specified treefile-relative directory names.
# @param  treefileRelativeDirectoryList
#							 the TreeFile-relative directories (e.g.
#							 appearance/mesh) that should be searched.
# ----------------------------------------------------------------------

sub findRelative
{
	# Process args.
	my $callbackRef = shift;
	die "Caller must specify callback function reference" if !defined($callbackRef);

	# Process each directory.
	@_ = ("") if !scalar(@_);
	foreach my $treefileRelativeDir (@_)
	{
		# Add trailing '/' if not already present.
		$treefileRelativeDir .= '/' if !$treefileRelativeDir =~ m!/$!;
		my $matchRegex = '^' . $treefileRelativeDir;

		# Test all treefile-relative names against this regex.
		# @todo optimize this by building a TreeFile-relative directory structure
		# so that we don't need to test against everything.
		foreach $relativePathName (keys %directoryIndexByRelativeName)
		{
			if ($relativePathName =~ m/$matchRegex/)
			{
				# Allow $TreeFile::name to access the full on-disk pathname.
				$fullPathName = getFullPathName($relativePathName);

				# Setup $_ for callback.
				$_ = $relativePathName;
				$_ =~ s!.*/!!;

				# Call callback.
				&$callbackRef();
			}
		}
	}
}

# ----------------------------------------------------------------------
# Operates similar to findRelative but is more efficient in that it makes
# a single pass over all tree file entries instead of a pass per specified
# directory.
#
# @syntax  findRelativeRegexMatch(callbackReference, regexList)
#
# @param  callbackReference	 the function referenced by this arg will be
#							 called once for each file in the treefile relative 
#							 filename domain that matches at least one of
#							 regex entries in regexList.
# @param  regexList			 a list of regex entries that will be applied to
#							 the TreeFile-relative pathname (the whole thing).
#							 If any one of these matches a specified file, the
#							 callback will be made for the file.
# ----------------------------------------------------------------------

sub findRelativeRegexMatch
{
	# Process args.
	my $callbackRef = shift;
	die "Caller must specify callback function reference" if !defined($callbackRef);

	my $regexCount = @_;
	die "Caller must specify at least one regex to match against treefile-relative pathnames" if !$regexCount;

	# Process each TreeFile-relative pathname.
	foreach $relativePathName (keys %directoryIndexByRelativeName)
	{
		my $matchCount = 0;
		
		# Check if any of the regex entries match the treefile-relative pathname.
		for (my $i = 0; ($i < $regexCount) && ($matchCount < 1); ++$i)
		{
			++$matchCount if $relativePathName =~ m/$_[$i]/;
		}

		if ($matchCount > 0)
		{
			# Allow $TreeFile::name to access the full on-disk pathname.
			$fullPathName = getFullPathName($relativePathName);

			# Setup $_ for callback.
			$_ = $relativePathName;
			$_ =~ s!.*/!!;

			# Call callback.
			&$callbackRef();
		}
	}
}

# ======================================================================

1;
