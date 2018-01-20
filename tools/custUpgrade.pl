# ======================================================================
#
# custUpgrade.pl 
# Copyright 2003 Sony Online Entertainment, Inc.
# All Rights Reserved.
#
# ======================================================================

# Used to upgrade SWG customization data from an older database format
# to a newer database format.  Note the exact upgrade logic needed will
# be different in any upgrade situation, but this should be a good template
# for most of the code in the event of another customization data upgrade
# some time in the future.

# Perl modules DBI and DBD::Oracle must be installed to run this tool.  See www.perl.com for info on getting these modules.
# You must have PERL5LIB (or PERLLIB) set to your mapping for //depot/swg/current/tools/perllib.

use Customization;
use DBI;
use strict;

# ======================================================================
# Module Globals
# ======================================================================

#options

my $userName       = "";
my $password       = "changeme";
my $databaseName   = "swodb";

my $debug          = 0;
my $noChanges      = 0;
my $doUpgrade      = 0;

my $commitCount    = 0;
my $limitRowCount  = 0;
my $progressStep   = 0;

my $defaultFilename = '../dsrc/sku.0/sys.shared/compiled/game/customization/customization_id_manager.mif'; 
my $customizationIdManagerFilename = $defaultFilename;

# ======================================================================

sub printHelp
{
    print "Calling syntax:\n";
    print "\tperl -w custUpgrade.pl -u <database username> [-p <database password>] [-D <database>] [-d] [-n] [-U] [-c <commit count>] [-l <limit row count>] [-m <pathToCustomizationIdManagerMifFile>] [-s <progressOutputStep>]\n";
    print "Option description:\n";
    print "\t-u: specifies the name of the user for the Oracle database.\n";
    print "\t-p: [optional] specifies the password for the user of the Oracle database.  Default: changeme.\n";
    print "\t-D: [optional] specifies the database to attach to.  Default: swodb.\n";
    print "\t-d: [optional] turn on extensive debug-level output.\n";
    print "\t-n: [optional] do not make changes to the database, just print what would have happened.\n";
    print "\t-U: [optional] Upgrade customization data in the database.\n";
    print "\t-c: [optional] commit every 'commit count' number of rows processed, or 0 for single commit at the end.  Default: 0.\n";
    print "\t-l: [optional] limit database processing to first <limit row count> rows or 0 for no limit.  Default: 0.\n";
    print "\t-m: [optional] specify path to CustomizationIdManager's mif version of initialization file. Default: $defaultFilename\n";
    print "\t-s: [optional] print a progress line every progressStep percent or 0 if no output.  Default: 0.\n";
    print "\t-h: [optional] print this help info.\n";
}

# ======================================================================

sub collectOptions
{
    my $showHelp = 0;
    my $exitCode = 0;

    while (defined($ARGV[0]) && ($ARGV[0] =~ m/^-(.*)$/))
    {
	if ($1 eq 'u')
	{
	    # Grab username.
	    if (@ARGV < 2)
	    {
		print "-u option missing <database username> specification.\n";
		$exitCode = 1;
		last;
	    }

	    $userName = $ARGV[1];
	    print "<username: $userName>\n" if $debug;

	    # Skip past arg.
	    shift @ARGV;
	}
	elsif ($1 eq 'p')
	{
	    # Grab password.
	    if (@ARGV < 2)
	    {
		print "-p option missing <password> specification.\n";
		$exitCode = 1;
		next;
	    }

	    $password = $ARGV[1];
	    print "<password: $password>\n" if $debug;

	    # Skip past arg.
	    shift @ARGV;
	}
	elsif ($1 eq 'D')
	{
	    # Grab database name.
	    if (@ARGV < 2)
	    {
		print "-D option missing <database> specification.\n";
		$exitCode = 1;
		next;
	    }

	    $databaseName = $ARGV[1];
	    print "<database: $databaseName>\n" if $debug;

	    # Skip past arg.
	    shift @ARGV;
	}
	elsif ($1 eq 'd')
	{
	    $debug = 1;
	    $Customization::Debug = 1;
	}
	elsif ($1 eq 'n')
	{
	    $noChanges = 1;
	}
	elsif ($1 eq 'U')
	{
	    $doUpgrade = 1;
	}
	elsif ($1 eq 'h')
	{
	    $showHelp = 1;
	}
	elsif ($1 eq 'c')
	{
	    # Grab commit count.
	    if (@ARGV < 2)
	    {
		print "-c option missing <commit count> specification.\n";
		$exitCode = 1;
		next;
	    }

	    $commitCount = $ARGV[1];
	    print "<commit count: $commitCount>\n" if $debug;

	    # Skip past arg.
	    shift @ARGV;
	}
	elsif ($1 eq 'l')
	{
	    # Grab commit count.
	    if (@ARGV < 2)
	    {
		print "-l option missing <limit row count> specification.\n";
		$exitCode = 1;
		next;
	    }

	    $limitRowCount = $ARGV[1];
	    print "<limitRowCount: $limitRowCount>\n" if $debug;

	    # Skip past arg.
	    shift @ARGV;
	}
	elsif ($1 eq 'm')
	{
	    # Grab commit count.
	    if (@ARGV < 2)
	    {
		print "-m option missing <CustomizationIdManager MIF file> specification.\n";
		$exitCode = 1;
		next;
	    }

	    $customizationIdManagerFilename = $ARGV[1];
	    print "<customizationIdManagerFilename: $customizationIdManagerFilename\n" if $debug;

	    # Skip past arg.
	    shift @ARGV;
	}
	elsif ($1 eq 's')
	{
	    # Grab commit count.
	    if (@ARGV < 2)
	    {
		print "-s option missing <progressStepPercent> specification.\n";
		$exitCode = 1;
		next;
	    }

	    $progressStep = $ARGV[1];
	    print "<progressStep: $progressStep>\n" if $debug;

	    # Skip past arg.
	    shift @ARGV;
	}
	else
	{
	    warn "unknown option [$1].";
	    $exitCode = 1;
	}

	# Process next argument.
	shift @ARGV;
    }

    # Check for missing options.
    if (length $userName < 1)
    {
	print "missing -u username option.\n";
	$exitCode = 1;
    }
    
    # Show help as needed.
    if ($showHelp || ($exitCode != 0))
    {
	printHelp();
	exit($exitCode);
    }
}

# ======================================================================
# input:  old-style customization ascii string.
# output: new-style customization binary data (as string) (unescaped --- can contain embedded NULLs).
# ======================================================================

sub convertOldToNew
{
    # Get the string.
    my $oldString = shift;

    # fill directory contents from old string.
    my %variableInfo;

    my $rc = getVariableInfoFromOldString(%variableInfo, $oldString);
    if (!$rc)
    {
	warn "convertOldToNew:failed to get variable info from old-style customization data string [$oldString]\n";
	return "";
    }

    return createNewDataFromVariableInfo(%variableInfo);
}

# ======================================================================

sub doUpgrade
{
    my $returnCode;

    # Open the database connection.
    my $dbHandle = DBI->connect("dbi:Oracle:$databaseName", $userName, $password, { RaiseError => 1, AutoCommit => 0 });
    error("failed to open database: [$DBI::errstr]") if !defined($dbHandle);
    print "<connection: opened connection to database [$databaseName] as user [$userName] successfully.>\n" if $debug;
    
    # Find # rows that match our criteria of non-zero-length customization data.
    my $totalRowCount = 0;
    {
	my $statementHandle = $dbHandle->prepare("SELECT COUNT(*) FROM tangible_objects WHERE LENGTH(appearance_data) > 0") or die $dbHandle->errstr;
	$statementHandle->execute() or die $statementHandle->errstr;

	my @row = $statementHandle->fetchrow_array;
	die($statementHandle->errString) if !@row;
	
	$totalRowCount = $row[0];
	print "<totalRowCount: $totalRowCount>\n" if $debug;
    }

    # Progress bar uses limitRowCount or totalRowCount depending on whether row limiting is in effect.
    my $progressTotalRowCount = $totalRowCount;
    if (($limitRowCount > 0) && ($limitRowCount < $totalRowCount))
    {
	$progressTotalRowCount = $limitRowCount;
    }

    # Process rows.
    my $uncommittedRowCount    = 0;
    my $totalCommittedRowCount = 0;
    my $processedRowCount      = 0;
    my $failedRowCount         = 0;
    my $sumOldStringSize       = 0;
    my $sumNewDataSize         = 0;
    my $sumNewStringSize       = 0;
    my $lastPrintedPercent     = 0;

    {
	# Prepare the SELECT statement.
	my $statementHandle = $dbHandle->prepare("SELECT object_id, appearance_data FROM tangible_objects WHERE LENGTH(appearance_data) > 0") or die $dbHandle->errstr;
	$statementHandle->execute() or die $statementHandle->errstr;
	
	# Prepare the UPDATE statement.
	my $updateStatementHandle = $dbHandle->prepare("UPDATE tangible_objects SET appearance_data = ? WHERE object_id = ?") or die $dbHandle->errstr;

	while (my @row = $statementHandle->fetchrow_array)
	{
	    # Validate row entry count.
	    die "Returned row has " . @row . "entries, expecting 2." if (@row != 2);

	    ++$processedRowCount;

	    # Retrieve object id and old customization data.
	    my $objectId               = $row[0];
	    my $oldCustomizationString = $row[1];
	    print "<row: num=[$processedRowCount] id=[$objectId]: string=[$oldCustomizationString]>\n" if $debug;

	    # Keep track of old customization string size. 
	    $sumOldStringSize += length $oldCustomizationString;

	    # Convert the row.
	    my $newCustomizationData = convertOldToNew($oldCustomizationString);
	    my $newDataLength = length $newCustomizationData;

	    if (!defined($newCustomizationData) || ($newDataLength < 1))
	    {
		++$failedRowCount;
		print STDERR "failed to convert old customization data [$oldCustomizationString] (total failed rows=$failedRowCount).\n";
	    }
	    else
	    {
		# Track new unescaped binary data length.
		$sumNewDataSize += $newDataLength;

		# Convert binary data to escaped string form.
		my $newCustomizationString = escapeBinaryData($newCustomizationData);

		# Track new escaped string data length.
		my $newStringLength = length $newCustomizationString;
		if (!defined($newCustomizationString) || ($newStringLength < 1))
		{
		    ++$failedRowCount;
		    print STDERR "failed to convert new binary customization data [$newCustomizationData] to string (total failed rows=$failedRowCount).\n";
		}
		else
		{
		    $sumNewStringSize += length $newCustomizationString;

		    # Update the database with new entry.
		    if (!$noChanges)
		    {
			# Execute the update.
			$updateStatementHandle->execute($newCustomizationString, $objectId) or die $statementHandle->errstr;

			# Check if we should commit.
			++$uncommittedRowCount;

			if (($commitCount != 0) && ($uncommittedRowCount >= $commitCount))
			{
			    # Commit now.
			    my $returnCode = $dbHandle->commit or die $dbHandle->errstr;

			    $totalCommittedRowCount += $uncommittedRowCount;
			    print "<commit: $uncommittedRowCount rows committed now, $processedRowCount total, returnCode=$returnCode.>\n" if $debug;

			    $uncommittedRowCount = 0;
			}
		    }
		    else
		    {
			print "<update: would do UPDATE tangible_objects SET appearance_data = (" . $newStringLength . " byte string) WHERE object_id = [$objectId]>\n" if $debug;
		    }
		}
	    }

	    # Handle progress monitoring.
	    if ($progressStep > 0)
	    {
		my $progressPercent = 100.0 * $processedRowCount / $progressTotalRowCount;
		if ($progressPercent >= ($lastPrintedPercent + $progressStep))
		{
		    $lastPrintedPercent = $progressPercent;
		    printf("progress: %d%% complete.\n", $lastPrintedPercent);
		}
	    }

	    # Handle row limiting.
	    if (($limitRowCount > 0) && ($processedRowCount >= $limitRowCount))
	    {
		print "<limitRowCount: specified row count limit [$limitRowCount] hit, finishing now.>\n" if $debug;
		last;
	    }
	}
    }

    # Do final commit.
    if (!$noChanges)
    {
	my $returnCode = $dbHandle->commit or die $dbHandle->errstr;

	$totalCommittedRowCount += $uncommittedRowCount;
	print "<commit: $uncommittedRowCount rows committed now, $processedRowCount total, returnCode=$returnCode.>\n" if $debug;

	$uncommittedRowCount = 0;
    }

    # Close the database connection.
    $returnCode = $dbHandle->disconnect or warn $dbHandle->errstr;
    print "<disconnect: return code $returnCode>" if $debug;

    # Print statistics
    print "Completed upgrade process, printing statistics.\n";
    print "\tTotal rows processed: $processedRowCount\n";
    print "\tTotal rows changed:   $totalCommittedRowCount\n\n";

    my $oldAverage = 1;
    $oldAverage = ($sumOldStringSize / $processedRowCount) if $processedRowCount > 0;
    printf("\tTotal old customization string data: $sumOldStringSize bytes (average: %.2f bytes each)\n", $oldAverage) if $processedRowCount > 0;

    my $newStringCount = $processedRowCount - $failedRowCount;
    my $newAverage = 1;
    $newAverage = ($sumNewStringSize / $newStringCount) if $newStringCount > 0;
    printf("\tTotal new customization string data: $sumNewStringSize bytes (average: %.2f bytes each)\n", $newAverage) if $newStringCount > 0;
    
    my $compressionFraction = $newAverage / $oldAverage;
    printf "\tCompressed to %.2f%% of original size.\n", $compressionFraction * 100;

    my $difference = $sumNewStringSize - $sumNewDataSize;
    printf("\tTotal overhead for binary data escaping: $difference bytes (%.2f%% increase).\n", 100.0 * (($sumNewStringSize / $sumNewDataSize) - 1.0)) if $sumNewDataSize > 0;
}

# ======================================================================
# Program Starts Here
# ======================================================================
{
    collectOptions();
    
    if ($doUpgrade)
    {
	initializeCustomization($customizationIdManagerFilename);
	doUpgrade();
    }
}

# ======================================================================
