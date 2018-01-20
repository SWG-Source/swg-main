package Customization;

use strict;
use warnings;

# Module boiler plating.

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	# set the version for version checking
	$VERSION	 = 1.00;
	@ISA		 = qw(Exporter);
	# @EXPORT	   = qw(&func1 &func2 &func4);
	@EXPORT		 = qw(&createNewDataFromVariableInfo &dumpStringInHex &dumpVariableInfo &escapeBinaryData &getVariableInfoFromNewString &getVariableInfoFromOldString &initializeCustomization &removeEscapesFromString);
	%EXPORT_TAGS = ( );		# eg: TAG => [ qw!name1 name2! ],

	# your exported package globals go here,
	# as well as any optionally exported functions
	# @EXPORT_OK   = qw($Var1 %Hashit &func3);
	@EXPORT_OK	   = qw(%IdsByVariableName %VariableNamesById);
}
our @EXPORT_OK;

# exported package globals go here
# e.g.
# our $Var1;
# our %Hashit;

our %IdsByVariableName;
our %VariableNamesById;

# non-exported package globals go here
# e.g. 
# our @more;
# our $stuff;
our $Debug;

# initialize package globals, first exported ones
# e.g.
# $Var1	  = '';
# %Hashit = ();
%IdsByVariableName = ();
%VariableNamesById = ();

# then the others (which are still accessible as $Some::Module::stuff)
# $stuff  = '';
# @more	  = ();
$Debug = 0;

# all file-scoped lexicals must be created before
# the functions below that use them.

# file-private lexicals go here
# e.g. 
# my $priv_var	  = '';
# my %secret_hash = ();

# here's a file-private function as a closure,
# callable as &$priv_func;	it cannot be prototyped.
# e.g.
# my $priv_func = sub {
#	  # stuff goes here.
# };

# make all your functions, whether exported or not;
# remember to put something interesting in the {} stubs
# e.g.
# sub func1		 {}	   # no prototype
# sub func2()	 {}	   # proto'd void
# sub func3($$)	 {}	   # proto'd to 2 scalars

# this one isn't exported, but could be called!
# e.g.
# sub func4(\%)	 {}	   # proto'd to 1 hash ref

# ======================================================================

sub dumpStringInHex($)
{
	my $data	   = shift;
	my $dataLength = length $data;

	print STDERR "dumping string (length=$dataLength characters):\n";
	for (my $i = 0; $i < $dataLength; ++$i)
	{
		my $character = substr($data, $i, 1);
		if ($character =~ m/\w/)
		{
			printf STDERR "$i: 0x%x ($character)\n", ord($character);
		}
		else
		{
			printf STDERR "$i: 0x%x (<?>)\n", ord($character);
		}
	}
}

# ======================================================================
# input: reference to variable info hash, 
#		 directory string from old-style customization data, 
#		 string representing variable path up to this point.
#
# output: results returned in variable info hash.
#
# return: return code, 1 if successful, 0 if failed.
#
# private
# ======================================================================

# Extra prototype needed for recursive calling within function.
sub getVariableInfoFromOldStringDirectory(\%$$);

sub getVariableInfoFromOldStringDirectory(\%$$)
{
	my $variableInfoRef = shift;
	my $dirData			= shift;
	my $fullDirectory	= shift;

	# Grab # variables.
	if (($dirData =~ s/^([0-9a-fA-F]+)\#//) == 0)
	{
		warn "getVariableInfoFromOldStringDirectory(): failed to parse variable count from dir data [$dirData].\n";
		return 0;
	}

	# Process variables local to this directory.
	my $varCount = hex($1);
	print "<dir: [$fullDirectory] has $varCount variables.>\n" if $Debug;

	for (my $varIndex = 0; $varIndex < $varCount; ++$varIndex)
	{
		#-- Variable format: <variable name>#<contentByteCount>#<contents>
		if (($dirData =~ s/^(\w+)\#([0-9a-fA-F]+)\#//) == 0)
		{
			warn "getVariableInfoFromOldStringDirectory(): failed to parse variable name, content size and contents from dir data [$dirData].\n";
			return;
		}

		my $varShortName = $1;
		my $varDataLength = hex($2);

		#-- Take the first $varDataLength bytes off the front of $dirData.
		my $varData = hex(substr($dirData, 0, $varDataLength));
		$dirData	= substr($dirData, $varDataLength);

		#-- Try to fix negative numbers (assume anything over 32637 is really a negative number.
		if (($varData =~ m/^\d+$/) && ($varData > 32637))
		{
			# Assume this is a 32-bit hex encoded negative number.	Fix it up.	I think this code can only
			# work if perl is using 32-bit integers.

			# Do 2's complement formula in reverse to get the absolute value of the negative number.
			my $negativeValue = ($varData - 1);
			$negativeValue = ~$negativeValue;

			$varData = -$negativeValue;
		}

		#-- Add variable to variable info hash.
		my $varFullName = $fullDirectory . $varShortName;
		$$variableInfoRef{$varFullName} = $varData;
		print "<oldVar: [$varFullName] = [$varData]>\n" if $Debug;
	}

	# Process subdirs local to this directory.

	# Grab # subdirs.
	if (($dirData =~ s/^([0-9a-fA-F]+)\#//) == 0)
	{
		warn "getVariableInfoFromOldStringDirectory(): failed to parse subdirectory count from dir data [$dirData].\n";
		return 0;
	}

	my $subdirCount = hex($1);
	print "<dir: [$fullDirectory] has $subdirCount subdirectories.>\n" if $Debug;

	for (my $subdirIndex = 0; $subdirIndex < $subdirCount; ++$subdirIndex)
	{
		#-- Variable format: <variable name>#<contentByteCount>#<contents>
		if (($dirData =~ s/^(\w+)\#([0-9a-fA-F]+)\#//) == 0)
		{
			warn "getVariableInfoFromOldStringDirectory(): failed to parse dir name, content size and contents from dir data [$dirData].\n";
			return;
		}

		my $dirShortName = $1;
		my $dirDataLength = hex($2);

		#-- Take the first $varDataLength bytes off the front of $dirData.
		my $subdirData = substr($dirData, 0, $dirDataLength);
		$dirData	   = substr($dirData, $dirDataLength);

		#-- Recursively call this function to process the local directory's data.
		my $dirFullName = $fullDirectory . $dirShortName . '/';
		print "<oldDir: [$dirFullName]>\n" if $Debug;

		getVariableInfoFromOldStringDirectory(%$variableInfoRef, $subdirData, $dirFullName);
	}
	
	# Indicate success.
	return 1;
}

# ======================================================================
# input: reference to variable info hash, 
#		 directory string from old-style customization data, 
#
# output: results returned in variable info hash.
#
# return: return code, 1 if successful, 0 if failed.
# ======================================================================

sub getVariableInfoFromOldString(\%$)
{
	# Get parameters.
	my $variableInfoRef = shift;
	my $oldString		= shift;

	# Get the version number.
	if (($oldString =~ s/^([0-9a-fA-F]+)\#//) == 0)
	{
		warn "getVariableInfoFromOldString:could not parse out version number:string [$oldString]\n";
		return "";
	}
	
	if (hex($1) != 2)
	{
		warn "getVariableInfoFromOldString:version number [$1] unsupported:string [$oldString]\n";
		return "";
	}

	# Fill up variable info from the root directory '/'.
	return getVariableInfoFromOldStringDirectory(%$variableInfoRef, $oldString, '/');
}

# ======================================================================
# input:  reference to variable info hash
# output: variables encoded with binary encoding scheme version 1.
#
# A variable info hash is a simple hash mapping a full customization 
# variable path (e.g. /shared_owner/index_color_skin) to its value
# (e.g. 3).
# ======================================================================

sub createNewDataFromVariableInfo(\%)
{
	# Build output string.
	my $newData = "";

	# Write version number.
	$newData .= chr(1);

	# Process each variable in the hash mapping variable name to value.
	my $varInfoRef	  = shift;
	my @variableNames = keys %$varInfoRef;

	# Pass 1: count how many of these vars exist in the id table.  Any vars not
	#		  in the id table will be lost.
	my $existingVariableCount = 0;

	foreach my $variableName (@variableNames)
	{
		# Get value for variable.
		if (defined($IdsByVariableName{$variableName}))
		{
			++$existingVariableCount;
		}
		else
		{
			print "<varNotMapped: variable [$variableName] length [" . (length $variableName) . "] referenced but is not mapped, dropping value.>\n" if $Debug;
		}
	}
	
	# Write variable count.
	$newData .= chr($existingVariableCount);

	# Setup minimum expected data size.
	my $minExpectedDataLength = 2 + 2 * $existingVariableCount; 

	foreach my $variableName (keys %$varInfoRef)
	{
		# Process only if variable exists.
		next if !defined($IdsByVariableName{$variableName});

		# Get id for variable name.
		my $variableId = $IdsByVariableName{$variableName};
		die "variableId $variableId out of valid range 1..127" if ($variableId < 1) || ($variableId > 127);

		my $byteCount;

		# Build combined id: most significant bit is turned on if value is signed short; otherwise value is unsigned char.
		# NOTE: this code assumes only the variable named <something>/blend_flat_chest can contain signed short values since
		#		I have no range info at this stage of the game.	 True at time of upgrade.
		if ($variableName =~ m!/blend_flat_chest$!i)
		{
			$variableId |= 0x80;
			$byteCount = 2;
		}
		else
		{
			$byteCount = 1;
		}

		# Get value for variable.
		my $value = $$varInfoRef{$variableName};

		# Write variable id and data.
		$newData .= chr($variableId);
		if ($byteCount == 1)
		{
			$newData .= chr($value & 0xff);
		}
		else
		{
			# Store 16-bit 2's complement number, within range -32768 .. 32767.	 As long as this machine uses
			# 2's complement for signed integers, and assuming Perl guarantees at least 32 bits of precision on integer math,
			# then it doesn't matter how many bits the value is stored in so long as the value is within the specified range.
			if ($value > 32767)
			{
				$value = 32767;
			}
			elsif ($value < -32768)
			{
				$value = -32768;
			}

			$newData .= chr($value & 0xff);
			$newData .= chr(($value & 0xff00) >> 8);
		}
	}

	# Check min size.
	my $newDataLength = length $newData;
	if ($newDataLength < $minExpectedDataLength)
	{
		warn "wrote fewer bytes than expected; min expected=$newDataLength, written=$newDataLength.";
		dumpVariableInfo(%$varInfoRef);
	}

	return $newData;
}

# ======================================================================
# input:  variable info hash, mapping full-path variable info name to value.
# output: dumps variable names and values, sorted by variable name.
# ======================================================================

sub dumpVariableInfo(\%)
{
	my $variableInfoRef = shift;

	foreach my $variableName (sort keys %$variableInfoRef)
	{
		my $value = $$variableInfoRef{$variableName};
		print "[$variableName]=[$value]\n";
	}
}

# ======================================================================
# input:  string, possibly with embedded nulls, to be escaped so it doesn't contain embedded nulls.
# output: string, possibly with added escape characters, does not contain any NULLs.
# ======================================================================

sub escapeBinaryData($)
{
	my $rawString	  = shift;
	my $escapedString = "";

	my $rawLength = length $rawString;
	for (my $i = 0; $i < $rawLength; ++$i)
	{
		my $rawChar = substr($rawString, $i, 1);
		if (ord($rawChar) == 0)
		{
			# replace 0x00 with 0xff 0x01
			$escapedString .= chr(0xff) . chr(0x01);
		}
		elsif (ord($rawChar) == 0xff)
		{
			# replace 0xff with 0xff 0x02
			$escapedString .= chr(0xff) . chr(0x02);
		}
		else
		{
			$escapedString .= $rawChar;
		}
	}

	# Add end-of-data marker.
	$escapedString .= chr(0xff);
	$escapedString .= chr(0x03);

	return $escapedString;
}

# ======================================================================
# input: escaped string.
# output: de-escaped binary data with possible embedded nulls.
# ======================================================================

sub removeEscapesFromString($)
{
	my $escapedString = shift;
	my $rawString	  = "";

	my $escapedLength = length $escapedString;
	for (my $i = 0; $i < $escapedLength; ++$i)
	{
		my $escapedChar = substr($escapedString, $i, 1);
		if (ord($escapedChar) == 0xff)
		{
			# Look at next escaped character to find out what the
			# real binary value looks like, consume it.
			my $nextChar = substr($escapedString, $i+1, 1);
			++$i;

			if (ord($nextChar) == 0x01)
			{
				# this is the escape sequence 0xff 0x01 => 0x00
				$rawString .= chr(0x00);
			}
			elsif (ord($nextChar) == 0x02)
			{
				# this is the escape sequence 0xff 0x02 => 0xff
				$rawString .= chr(0xff);
			}
			elsif (ord($nextChar) == 0x03)
			{
				# ignore, end of data marker.
				if (($i + 1) != $escapedLength)
				{
					warn "found escape for end of data, but at index " . ($i+1) . " of total length $escapedLength.";
				}
			}
			else
			{
				my $warningString;
				$warningString = sprintf("removeEscapesFromString: found invalid escape sequence 0xff 0x%x in escaped string [$escapedString], escape failure.\n", ord($nextChar));
				warn $warningString;
				return "";
			}
		}
		else
		{
			$rawString .= $escapedChar;
		}
	}

	return $rawString;
}

# ======================================================================
# input: pass-by-reference variable info hash.	Will be filled upon return.
# return: 1 if successful, 0 if false.
# ======================================================================

sub getVariableInfoFromNewString(\%$)
{
	# Get parameters.
	my $variableInfoRef	  = shift;
	my $encodedDataString = shift;

	if ($Debug)
	{
		print "<getVariableInfoFromNewString: dumping escaped string>\n";
		dumpStringInHex($encodedDataString);
	}

	my $data = removeEscapesFromString($encodedDataString);

	if ($Debug)
	{
		print "<getVariableInfoFromNewString: dumping unescaped string>\n";
		dumpStringInHex($data);
	}

	# Get version.
	my $dataLength = length $data;
	my $dataIndex  = 0;

	if (ord(substr($data, $dataIndex, 1)) != 1)
	{
		warn "getVariableInfoFromNewString: unsupported version " . ord(substr($data, $dataIndex, 1));
		return 0;
	}
	++$dataIndex;

	# Get variable count.
	my $variableCount = ord(substr($data, $dataIndex, 1));
	++$dataIndex;

	# Do a quick string size sanity check.
	my $minExpectedLength = 2 + $variableCount * 2;
	if ($dataLength < $minExpectedLength)
	{
		warn "getVariableInfoFromNewString: encoded data string is too small for encoded variable count [$variableCount], expecting at least [$minExpectedLength], has [$dataLength] bytes, padding with 0x20.";
		dumpStringInHex($encodedDataString);
		dumpStringInHex($data);

		# Try padding with spaces.
		$data .= chr(0x20) x ($minExpectedLength + 1 - $dataLength);
		$dataLength = $minExpectedLength + 1;
	}

	# Handle each variable.
	for (my $variableIndex = 0; $variableIndex < $variableCount; ++$variableIndex)
	{
		if ($dataIndex + 1 >= $dataLength)
		{
			warn "Truncating variable unpacking due to unexpected termination of packed data.\n";
			last;
		}

		# Get combined variable id.
		my $combinedId = ord(substr($data, $dataIndex, 1));
		++$dataIndex;

		# Break combined Id into data length and variable id.
		my $variableId		   = $combinedId & 0x7f;
		my $variableDataLength = (($combinedId & 0x80) != 0) ? 2 : 1;

		# Get variable's value.
		my $variableValue;

		if ($variableDataLength == 2)
		{
			# Read & interpret as signed 16-bit value.
			my $lowByte = ord(substr($data, $dataIndex, 1));
			++$dataIndex;

			my $hiByte = ord(substr($data, $dataIndex, 1));
			++$dataIndex;
			$hiByte = 0x20 if !defined($hiByte);

			if (($hiByte & 0x80) != 0)
			{
				# represents a negative number.

				# get binary representation right: assumes 32-bit perl representation, not guaranteed on all platforms.
				my $negativeValue = 0xffff0000 | ($hiByte << 8) | $lowByte;

				# interpret as signed integer.
				$variableValue = sprintf("%d", $negativeValue);
			}
			else
			{
				$variableValue = ($hiByte << 8) | $lowByte;
			}
		}
		else
		{
			# Read & interpret as single unisgned byte.
			$variableValue = ord(substr($data, $dataIndex, 1));
			++$dataIndex;
		}

		# Lookup variable name by value.
		my $variableName = $VariableNamesById{$variableId};
		if (!defined($variableName))
		{
			print "newData: found variable id [$variableId] with no name mapping.\n";
			return 0;
		}

		# Map variable name to value in returned parameter
		print "<getVariableInfoFromNewString: variable [$variableName] appears multiple times in customization data>\n" if ($Debug && defined($$variableInfoRef{$variableName}));
		$$variableInfoRef{$variableName} = $variableValue;
	}

	# Indicate success.
	return 1;
}

# ======================================================================
# Read variable id assignment info from customization id manager's MIF file.
#
# input:
#	 string: CustomizationIdManager's initialization MIF filename.
# ======================================================================

sub initializeCustomization($)
{
	my $filename = shift;
	open(MIF_FILE, $filename) or die "failed to open specified CustomizationIdManager mif file [$filename]: $!";

	my $nextAssignmentId = 0;
	my $expectingId		 = 1;

	while (<MIF_FILE>)
	{
		chomp();
		if (m/int16\s+(\d+)\s*$/)
		{
			# Ensure we're expecting a new id.
			die "error: file [$filename] appears malformed, out of order int16/cstring declarations.\n" if !$expectingId;
			$expectingId = 0;

			$nextAssignmentId = $1;
		}
		elsif (m/cstring\s+\"([^\"]+)\"\s*$/)
		{
			# Ensure we're expecting a variable name.
			die "error: file [$filename] appears malformed, out of order int16/cstring declarations.\n" if $expectingId;
			$expectingId = 1;

			# Add new variable name.  It is associated with $nextAssignmentId collected previously.
			$IdsByVariableName{$1}				  = $nextAssignmentId;
			$VariableNamesById{$nextAssignmentId} = $1;
			print "<existing: mapping variable name [$1] to [$nextAssignmentId]>\n" if $Debug;
		}
	}

	close(MIF_FILE);

	return 1;
}

# ======================================================================

END { }		  # module clean-up code here (global destructor)

# Return true from the file.
1;
