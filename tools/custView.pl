# ======================================================================
#
# custView.pl 
# Copyright 2003 Sony Online Entertainment, Inc.
# All Rights Reserved.
#
# ======================================================================

# Used to output customization data assignments for objects in a
# SWG database.	 Can view customization values for a list of object
# ids or for all object ids in the database.

# Perl modules DBI and DBD::Oracle must be installed to run this tool.	See www.perl.com for info on getting these modules.
# You must have PERL5LIB (or PERLLIB) set to your mapping for //depot/swg/current/tools/perllib.

use strict;

use Customization;
use DBI;

# ======================================================================
# Globals
# ======================================================================

my $modeIsView       = 0;
my $modeIsChange     = 0;

my $userName	     = "";
my $password	     = "changeme";
my $databaseName     = "swodb";

my $debug		     = 0;

my $showAll			 = 0;
my $useOldFormat	 = 0;
my $useFormatVersion = 1; 

my $defaultFilename  = '../dsrc/sku.0/sys.shared/compiled/game/customization/customization_id_manager.mif'; 
my $customizationIdManagerFilename = $defaultFilename;

my $dbHandle;

my $dumpFileName;
my $dumpFileEntryNumber = 1;

# ======================================================================

sub printHelp
{
	print "Calling syntax:\n";
	print "\n";
	print "show help:\n";
	print "\t$0 -h\n";
	print "\n";
	print "view human-readable customization from database:\n";
	print "\t$0 -V -u <database username> [-p <database password>] [-D <database>] [-d]\n";
	print "\t   [-m <pathToCustomizationIdManagerMifFile>] [-f format]\n";
	print "\t   [-a | [objectId [objectId...]]]\n";
	print "\n";
	print "change customization data in the database:\n";
	print "\t$0 -C -u <database username> [-p <database password>] [-D <database>] [-d]\n";
	print "\t   -1 <path to 1-line format dump file> [-e <entry number within dump file>] objectId\n";
	print "\n";
	print "Option description:\n";
	print "\t-V: major operating mode: view database info.\n";
	print "\t-C: major operating mode: change database entry.\n";
	print "\t-u: specifies the name of the user for the Oracle database.\n";
	print "\t-p: [optional] specifies the password for the user of the Oracle database.	 Default: changeme.\n";
	print "\t-D: [optional] specifies the database to attach to.  Default: swodb.\n";
	print "\t-d: [optional] turn on extensive debug-level output.\n";
	print "\t-m: [optional] specify path to CustomizationIdManager's mif version of initialization file.\n";
	print "\t    Default: $defaultFilename\n";
	print "\t-a: [optional] list customization variables for all objects in the database that have any customization info.\n";
	print "\t-f: [optional] customization string format: format = 1 (for new packed format version 1), old2 (for old unpacked format version 2).\n";
	print "\t    Default: 1.\n";
	print "\t-h: [optional] print this help info.\n";
	print "\t-1: filename containing 1-line dump format (one entry per line) of Oracle select dump(appearance_data) data.\n";
	print "\t-e: [optional] specifies the 1-based entry count to use if the dump file has multiple lines. Default: 1.\n";
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
		elsif ($1 eq 'C')
		{
			$modeIsChange = 1;
			print "major mode is change\n" if $debug;
		}
		elsif ($1 eq 'd')
		{
			$debug = 1;
			$Customization::Debug = 1;
		}
		elsif ($1 eq 'a')
		{
			$showAll = 1;
		}
		elsif ($1 eq 'h')
		{
			$showHelp = 1;
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
		elsif ($1 eq 'f')
		{
			# Grab commit count.
			if (@ARGV < 2)
			{
				print "-f option missing <format> specification.\n";
				$exitCode = 1;
				next;
			}

			if ($ARGV[1] =~ s/^old//i)
			{
				$useOldFormat = 1;
			}
			print "<useOldFormat: $useOldFormat>\n" if $debug;

			$useFormatVersion = $ARGV[1];
			print "<useFormatVersion: $useFormatVersion>\n" if $debug;

			# Skip past arg.
			shift @ARGV;
		}
		elsif ($1 eq 'V')
		{
			$modeIsView = 1;
			print "major mode is viewing\n" if $debug;
		}
		elsif ($1 eq '1')
		{
			$dumpFileName = $ARGV[1];
			shift @ARGV;

			print "dumpFileName=[$dumpFileName]\n" if $debug;
		}
		elsif ($1 eq 'e')
		{
			$dumpFileEntryNumber = $ARGV[1];
			shift @ARGV;
			print "dumpFileEntryNumber=$dumpFileEntryNumber\n" if $debug;
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
	if (!$showHelp && (length $userName < 1))
	{
		print "missing -u username option.\n";
		$exitCode = 1;
	}

	# Make sure show all or command line args exist.
	if (!$showHelp && (!$showAll && (@ARGV < 1)))
	{
		print "must specify one or more object IDs or -a option for all objects.\n";
		$exitCode = 1;
	}
	
	# Show help as needed.
	if ($showHelp || ($exitCode != 0))
	{
		printHelp();
		exit($exitCode);
	}
}

sub getVariableInfo(\%$)
{
	my $variableInfoRef		= shift;
	my $customizationString = shift;

	if ($useOldFormat)
	{
		if ($useFormatVersion == 2)
		{
			getVariableInfoFromOldString(%$variableInfoRef, $customizationString);
		}
		else
		{
			die "The only old version format supported is version 2, user specified [$useFormatVersion].";
		}
	}
	else
	{
		if ($useFormatVersion == 1)
		{
			getVariableInfoFromNewString(%$variableInfoRef, $customizationString);
		}
		else
		{
			die "New version format [$useFormatVersion] unsupported.";
		}
	}
}

# ======================================================================

sub printView($\%)
{
	my $objectId		= shift;
	my $variableInfoRef = shift;

	print "object id: $objectId\n";
	dumpVariableInfo(%$variableInfoRef);

	print "\n";
}

# ======================================================================

sub handleRow(\@)
{
	my $rowRef = shift;

	# Validate row entry count.
	die "Returned row has " . @$rowRef . "entries, expecting 2." if (@$rowRef != 2);

	# Retrieve object id and old customization data.
	my $objectId			= $$rowRef[0];
	my $customizationString = $$rowRef[1];
	print "<row: id=[$objectId]: string length [" . (length $customizationString) . "]>\n" if $debug;
	
	my %variableInfo = ();
	
	my $success = getVariableInfo(%variableInfo, $customizationString);
	die "getVariableInfo() failed for object id [$objectId]." if !$success;
	
	printView($objectId, %variableInfo);
}

# ======================================================================

sub doView
{
	if ($showAll)
	{
		print "<viewing: all>\n" if $debug; 

		# Prepare the SELECT statement: grab all non-empty appearance_data and associated object ids.
		my $statementHandle = $dbHandle->prepare("SELECT object_id, appearance_data FROM tangible_objects WHERE LENGTH(appearance_data) > 0") or die $dbHandle->errstr;
		$statementHandle->execute() or die $statementHandle->errstr;
		
		while (my @row = $statementHandle->fetchrow_array)
		{
			handleRow(@row);
		}
	}
	else
	{
		print "<viewing: [@ARGV]>\n" if $debug;

		# Prepare the SELECT statement: grab all non-empty appearance_data and associated object ids.
		my $statementHandle = $dbHandle->prepare("SELECT object_id, appearance_data FROM tangible_objects WHERE (LENGTH(appearance_data) > 0) AND object_id = ?") or die $dbHandle->errstr;

		for (; defined($ARGV[0]); shift @ARGV)
		{
			$statementHandle->execute($ARGV[0]) or die $statementHandle->errstr;
			my @row = $statementHandle->fetchrow_array;

			if (!@row)
			{
				print "object id [$ARGV[0]] has no customization data.\n";
				next;
			}

			handleRow(@row);
		}
	}
}

# ----------------------------------------------------------------------

sub convertOracleDumpToString
{
	my $oracleDumpString = shift;
	my $newString = "";

	# remove header info.
	$oracleDumpString =~ s/^\s*(\d+)?.*:\s*//;
	my $objectId = $1;

	while (length($oracleDumpString) > 0)
	{
		if ($oracleDumpString =~ s/^(\d+)(\s*,\s*)?//)
		{
			$newString .= chr($1);
		}
		else
		{
			print STDERR "convertOracleDumpToString: ", length($oracleDumpString), " characters remain: [val=", ord(substr($oracleDumpString,0,1)), "].\n";
			return $newString;
		}
	}

	return $newString;
}

# ----------------------------------------------------------------------

sub extractAppearanceDataFromFile
{
	my $dumpFile;
	open($dumpFile, '< ' . $dumpFileName) or die "failed to open dump file [$dumpFileName]: $!";

	my $entry = 1;
	while (<$dumpFile>)
	{
		# Check if we're dealing with the proper entry.
		if ($entry == $dumpFileEntryNumber)
		{
			chomp;
			my $appearanceData = convertOracleDumpToString($_);

			close($dumpFile) or die "Failed to close dump file: $!";
			return $appearanceData;
		}

		# Increment loop.
		++$entry;
	}

	close($dumpFile) or die "Failed to close dump file: $!";
	die "Entry [$dumpFileEntryNumber] does not exist in file [$dumpFileName] with [$entry] entries.";
}

# ----------------------------------------------------------------------

sub updateAppearanceData
{
	# Retrieve args.
	my $objectId       = shift;
	my $appearanceData = shift;

	# Execute query.
	my $rowCount = $dbHandle->do("UPDATE tangible_objects SET appearance_data=? WHERE object_id=$objectId", undef, $appearanceData) or die $dbHandle->errstr;
	$dbHandle->commit() or die $dbHandle->errstr;
	print "[$rowCount] rows updated.\n";
}

# ----------------------------------------------------------------------

sub doChange
{
	# Get the line.
	my $appearanceData = extractAppearanceDataFromFile();
	die "Could not extract appearance data from 1-line dump file.\n" if !defined($appearanceData);

	# Update the database.
	die "Expecting objectId at end of line.\n" if (@ARGV != 1);

	my $objectId = $ARGV[0];
	updateAppearanceData($objectId, $appearanceData);
}

# ----------------------------------------------------------------------

sub connectDatabase
{
	# Open the database connection.
	$dbHandle = DBI->connect("dbi:Oracle:$databaseName", $userName, $password, { RaiseError => 1, AutoCommit => 0 });
	error("failed to open database: [$DBI::errstr]") if !defined($dbHandle);
	print "<connection: opened connection to database [$databaseName] as user [$userName] successfully.>\n" if $debug;
}

# ----------------------------------------------------------------------

sub disconnectDatabase
{
	# Close the database connection.
	my $returnCode = $dbHandle->disconnect or warn $dbHandle->errstr;
	print "<disconnect: return code $returnCode>\n" if $debug;
}

# ======================================================================
# Program Starts Here
# ======================================================================
{
	collectOptions();

	connectDatabase();

	if ($modeIsView)
	{
		Customization::initializeCustomization($customizationIdManagerFilename);
		doView();
	}
	elsif ($modeIsChange)
	{
		doChange();
	}
	else
	{
		die "Major mode is neither viewing or changing.\n";
	}

	disconnectDatabase();
}

# ======================================================================
