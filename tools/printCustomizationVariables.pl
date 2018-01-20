# ======================================================================
# printCustomizationVariables.pl
#
# Tool to print customization variables from a variety of different sources.
# ======================================================================

use Customization;

# ======================================================================

my $dumpFileName;

# ======================================================================

sub printUsage
{
	print "usage:\n";
	print "\t$0 -h\n";
	print "\t$0 -1 <sql dump 1-liner format>\n";
	print "\n";
	print "Arguments:\n";
	print "\t-h: print this help.\n";
	print "\t-1: Oracle SELECT DUMP output for tangible_object.appearance_data\n";
	print "\t    where all data for a single appearance is concatenated to be\n";
	print "\t    on the same line.\n";
}

# ----------------------------------------------------------------------

sub processArgs
{
	# Process each arg.
	my $printUsage;
	my $quit = 0;

	while ((@_ > 0) && ($_[0] =~ s/^-//))
	{
		my $arg = $_[0];

		if ($arg eq '1')
		{
			shift;
			$dumpFileName = $_[0] if (defined($_[0]) && (length($_[0]) > 0));
		}
		elsif ($arg eq 'h')
		{
			$printUsage = 1;
			$quit		= 1;
		}
		else
		{
			print "unrecognized option [$_[0]].\n";
			$printUsage = 1;
			$quit		= 1;
		}

		shift;
	}

	# Ensure we're doing something.
	if (!defined($dumpFileName))
	{
		$printUsage = 1;
		$quit       = 1;
	}

	# Print help if requested.
	printUsage if $printUsage;

	# Quit if required.
	exit(-1) if $quit;
}

# ----------------------------------------------------------------------

sub convertOracleDumpToString
{
	my $oracleDumpString = shift;
	my $newString = "";

	# remove header info.
	$oracleDumpString =~ s/^\s*(\d+)?.*:\s*//;
	my $objectId = $1;

	# print header info.
	print "=====\n";
	print "Object ID: ";
	if (defined($objectId))
	{
		print $objectId . "\n";
	}
	else
	{
		print "<unknown>\n";
	}
	print "=====\n";
		

	while (length($oracleDumpString) > 0)
	{
		if ($oracleDumpString =~ s/^(\d+)(\s*,\s*)?//)
		{
			$newString .= chr($1);
		}
		else
		{
			print STDERR "convertOracleDumpToString: ", length($oracleDumpString), " characters remain: [$oracleDumpString].\n";
			return $newString;
		}
	}

	return $newString;
}

# ----------------------------------------------------------------------

sub printCustomizationVariables
{
	# Find where p4 maps the customization_id_manager.mif file.
	# Assume current branch for now.

	my $branch = $ENV{BRANCH} || 'current';
	my $depotFile = '//depot/swg/current/dsrc/sku.0/sys.shared/compiled/game/customization/customization_id_manager.mif';
	my $output = `p4 where //depot/swg/$branch/dsrc/sku.0/sys.shared/compiled/game/customization/customization_id_manager.mif`;
	my $mifFileName;

	if (defined($output))
	{
		my @whereParts = split(/\s+/, $output);
		if (@whereParts == 3)
		{
			$mifFileName = $whereParts[2];
		}
	}

	if (!defined(mifFileName))
	{
		print STDERR "Warning: p4 where did not return a 3-part response, defaulting mif file location.\n";
		$mifFileName = 'd:/work/swg/current/sku.0/sys.shared/compiled/game/customization/customization_id_manager.mif';
	}
	
	Customization::initializeCustomization($mifFileName);

	# For each line in 1-line dump file, print out variable data.
	my $dumpFile;
	open($dumpFile, '< ' . $dumpFileName) or die "failed to open dump file [$dumpFileName]: $!";

	my $entry = 1;

	while (<$dumpFile>)
	{
		chomp;
		my $encodedString = convertOracleDumpToString($_);

		# Convert encoded string into 
		my %variableInfoHash;
		my $result = Customization::getVariableInfoFromNewString(%variableInfoHash, $encodedString);
		if (!$result)
		{
			print "entry $entry: failed to convert, format invalid, skipping.\n";
		}
		else
		{
			Customization::dumpVariableInfo(%variableInfoHash);
		  }
		
		# Increment loop.
		++$entry;
	}
}

# ----------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------

# Collect info from args.
processArgs(@ARGV);

# Print the customization data.
printCustomizationVariables() if defined($dumpFileName);
