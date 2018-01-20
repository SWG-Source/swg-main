# ======================================================================
#
# Customization Variable Tool
# Copyright 2003, Sony Online Entertainment, Inc.
#
# ======================================================================

use strict;

use File::Find;
use POSIX qw(strftime);

# ======================================================================

# Constants
my $maxAllowableVariableId  = 127;
my $dataFormatVersionNumber = 1;
my $firstAssignableId       = 1;

# Names of customization variables.
my %countsByVariableName;

# Name to id assignment.
my %idsByVariableName;
my $newVariableCount = 0;

# Action options.
my $doPrintReport = 0;
my $doGenerateMifMapFile = 0;

# Report printing options.
my $printTpfFileNames = 0;
my $printSortByCount  = 0;
my $printSortByName   = 0;
my $reverseSort       = 0;

# Id map file generation options.
my $mifFileName      = "";
my $mifFileMustExist = 1;

my $debug = 0;

# ======================================================================
# SUBROUTINES
# ======================================================================

# ======================================================================

sub processArgs
{
    # Process args.  Args must come first.
    while (defined($ARGV[0]) && ($ARGV[0] =~ m/^-([a-zA-Z]*)$/))
    {
	if ($1 eq "i")
	{
	    $doPrintReport = 1;
	}
	elsif ($1 eq "g")
	{
	    $doGenerateMifMapFile = 1;
	}
	elsif ($1 eq "F")
	{
	    # Support first-time mif file generation, but force it to be a flag
	    # so the default is to die if not explicity specified and the mif
	    # file doesn't exist.
	    $mifFileMustExist = 0;
	}
	elsif ($1 eq "o")
	{
	    die "-o option requires a filename to be specified after it (e.g. -o customization_id_manager.mif)\n" if !defined($ARGV[1]);
	    $mifFileName = $ARGV[1];
	    shift @ARGV;

	    die "filename [$mifFileName] should end in extension \".mif\"\n" if !($mifFileName =~ m/\.mif$/);
	}
	elsif ($1 eq "t")
	{
	    $printTpfFileNames = 1;
	}
	elsif ($1 eq "c")
	{
	    $printSortByCount = 1;
	}
	elsif ($1 eq "n")
	{
	    $printSortByName = 1;
	}
	elsif ($1 eq "r")
	{
	    $reverseSort = 1;
	}
	elsif ($1 eq "d")
	{
	    $debug = 1;
	}

	shift @ARGV;
    }
    
    #-- Ensure we do at least some activity.  Assume report generation is default.
    if (($doPrintReport == 0) && ($doGenerateMifMapFile == 0))
    {
	$doPrintReport = 1;
    }

    #-- Ensure we'll print at least some output.  Default is print-by-count if no printing option is specified.
    if (($printSortByCount == 0) && ($printSortByName == 0))
    {
	$printSortByCount = 1;
    }
}

# ======================================================================

sub findFileHandler
{
    #-- Check if this is a TPF file.
    if (m/^.*\.tpf$/)
    {
	#-- Indicate file we're testing.
	print "Processing [$File::Find::name].\n" if $printTpfFileNames;
	
	#-- Open the TPF file.
        open(FILE, $_);

	#-- Scan all variable names within the TPF file.
	while (<FILE>)
	{
	    chomp();
	    if (m/variableName="([^"]*)\"/)  # last double-quote escaped for Emacs font-lock mode.
	    {
		$countsByVariableName{$1}++;
	    }
	}

	#-- Close the file.
	close(FILE);
    }
}

# ======================================================================

sub collectCustomizationVariableData
{
    # Setup directories to check.
    @ARGV = ('.') if !defined($ARGV[0]);

    # Do the find to scan in all TPF filenames.
    find (\&findFileHandler, @ARGV);
}

# ======================================================================

sub printReport
{
    # Handle printing sorted by name.
    if ($printSortByName)
    {
	my @sortedKeys = sort keys(%countsByVariableName);
	@sortedKeys = reverse @sortedKeys if $reverseSort;
	
	print "Variable names sorted by name (" . @sortedKeys . " unique variable names):\n";
	print "variable name\tcount\n";
	foreach my $variableName (@sortedKeys)
	{
	    my $count = $countsByVariableName{$variableName};
	    print "$variableName\t$count\n";
	}
	print "\n";
    }

    if ($printSortByCount)
    {
	my @sortedKeys = sort {$countsByVariableName{$b} <=> $countsByVariableName{$a}} keys(%countsByVariableName);
	@sortedKeys = reverse @sortedKeys if $reverseSort;

	print "Variable names sorted by name (" . @sortedKeys . " unique variable names):\n";
	print "count\tvariable name\n";
	foreach my $variableName (@sortedKeys)
	{
	    my $count = $countsByVariableName{$variableName};
	    print "$count\t$variableName\n";
	}
	print "\n";
    }
}

# ======================================================================

sub collectExistingVariableNameAssignments
{
    open(MIF_FILE, $mifFileName) or die "failed to open specified mif file [$mifFileName]: $!";

    my $nextAssignmentId = $firstAssignableId;
    my $expectingId      = 1;

    while (<MIF_FILE>)
    {
	chomp();
	if (m/int16\s+(\d+)\s*$/)
	{
	    # Ensure we're expecting a new id.
	    die "error: file [$mifFileName] appears malformed, out of order int16/cstring declarations.\n" if !$expectingId;
	    $expectingId = 0;

	    $nextAssignmentId = $1;
	}
	elsif (m/cstring\s+\"([^\"]+)\"\s*$/)
    	{
	    # Ensure we're expecting a variable name.
	    die "error: file [$mifFileName] appears malformed, out of order int16/cstring declarations.\n" if $expectingId;
	    $expectingId = 1;

	    # Add new variable name.  It is associated with $nextAssignmentId collected previously.
	    $idsByVariableName{$1} = $nextAssignmentId;
	    print "<existing: mapping variable name [$1] to [$nextAssignmentId]>\n" if $debug;
	}
    }

    close(MIF_FILE);
}

# ======================================================================

sub writeMifFile
{
    open(MIF_FILE, ">$mifFileName") or die "failed to open mif file [$mifFileName] for writing: $!";

    my $timeString = strftime "%a %b %e %H:%M:%S %Y", localtime(time());

    print MIF_FILE "// ======================================================================\n";
    print MIF_FILE "// Output generated by Perl script \"$0\"\n";
    print MIF_FILE "// Generation time: $timeString\n";
    print MIF_FILE "//\n";
    print MIF_FILE "// Do not hand-edit this file!  It is generated by the build process.\n";
    print MIF_FILE "// Changing values from a previous run without a database update will\n";
    print MIF_FILE "// invalidate database-stored customization data.\n";
    print MIF_FILE "// ======================================================================\n\n";
    
    print MIF_FILE "form \"CIDM\"\n";
    print MIF_FILE "{\n";
    print MIF_FILE "\tform \"0001\"\n";
    print MIF_FILE "\t{\n";
    print MIF_FILE "\t\tchunk \"DATA\"\n";
    print MIF_FILE "\t\t{\n";

    foreach my $variableName (sort { $idsByVariableName{$a} <=> $idsByVariableName{$b} } keys %idsByVariableName)
    {
	print MIF_FILE "\t\t\tint16\t$idsByVariableName{$variableName}\n";
	print MIF_FILE "\t\t\tcstring\t\"$variableName\"\n\n";
    }

    print MIF_FILE "\t\t}\n";
    print MIF_FILE "\t}\n";
    print MIF_FILE "}\n";

    close(MIF_FILE);

    print "<success: wrote new customization id manager data file [$mifFileName]>\n" if $debug;
}

# ======================================================================

sub assignNewVariableIds
{
    # Setup starting id: should be the same as # entries in assignment map.
    my @sortedValues = sort {$b <=> $a} values %idsByVariableName;
    my $nextAssignmentId = $firstAssignableId;

    $nextAssignmentId = ($sortedValues[0] + 1) if defined($sortedValues[0]);
    print "<firstNewId: $nextAssignmentId>\n" if $debug;


    # Process new IDs sorted by frequency from most to least, causing
    # lower ID values to be assigned to higher-frequency items.  This
    # could be useful if some of the lower frequency items are really
    # typos and need to be shuffled around.
    foreach my $variableName (sort {$countsByVariableName{$b} <=> $countsByVariableName{$a}} keys %countsByVariableName)
    {
	# Check if variable is assigned yet.
	if (!defined($idsByVariableName{$variableName}))
	{
	    $idsByVariableName{$variableName} = $nextAssignmentId;
	    print "<new: mapping variable name [$variableName] to [$nextAssignmentId]>\n" if $debug;

	    ++$nextAssignmentId;
	    ++$newVariableCount;
	}
    }
}

# ======================================================================

sub generateMifMapFile
{
    # Collect existing mif map assignments.
    if (-f $mifFileName)
    {
	collectExistingVariableNameAssignments();
    }
    elsif ($mifFileMustExist)
    {
	if (length($mifFileName) < 1)
	{
	    die "error: must specify filename for existing and output mif file with the -o flag.\n";
	}
	else
	{
	    die "error: Customization id manager file must exist to preserve existing mappings.\nerror: Failed to find [$mifFileName].\nerror: Use -F for first-time file generation, don't do this unless you know what you're doing!\n";
	}
    }

    # Generate assignments for non-populated but existing customization variables.
    assignNewVariableIds();

    # Check if we've exceeded the max assignable id value.
    my @sortedAssignedIds = sort {$a <=> $b} values %idsByVariableName;
    my $idCount = @sortedAssignedIds;
    if ($idCount > 0)
    {
	my $maxAssignedId = $sortedAssignedIds[$idCount - 1];
	print "<maxAssignedId: $maxAssignedId>\n" if $debug;

	if ($maxAssignedId > $maxAllowableVariableId)
	{
	    die "error: new unassigned customization variable ids needed but no more room.\nerror: Either unused names must be removed with database remapping or a new data format must be implemented.\nNeed id of $maxAssignedId but max allowable is $maxAllowableVariableId for format version $dataFormatVersionNumber.\n";
	}
    }

    # Write new mif file if any changes.
    if ($newVariableCount > 0)
    {
	writeMifFile();
    }
    else
    {
	print "skipping file generation: no new customization variable names found.\n";
    }
}

# ======================================================================
# PROGRAM STARTING POINT.
# ======================================================================

# Program starts here.
{
    # Handle arguments.
    processArgs();

    # Collect customization variable data.
    collectCustomizationVariableData();

    # Handle report generation.
    if ($doPrintReport)
    {
	printReport();
    }

    # Handle mif file generation.
    if ($doGenerateMifMapFile)
    {
	generateMifMapFile();
    }
}    

# ======================================================================
