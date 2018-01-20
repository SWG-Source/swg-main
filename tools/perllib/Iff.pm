# ======================================================================
# Iff.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package Iff;
use strict;

use Fcntl;

# ======================================================================
# Iff public variables.
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
@EXPORT_OK = qw();

# ======================================================================
# Iff private variables.
# ======================================================================

my $debug = 0;
my %handlerByTag;

# ======================================================================
# Iff public functions.
# ======================================================================

# ----------------------------------------------------------------------
# Called to prepare a newly-blessed Iff object's hash members for use.
#
# @syntax  $object->initialize()
# @type	   instance method
# ----------------------------------------------------------------------

sub initialize
{
	# Get self reference.
	my $self = shift;

	# Initialize all instance members.
	$self->{data}  = "";
	$self->{index} = 0;
	$self->{stack} = [];
}

# ----------------------------------------------------------------------
# Called to read and return IFF block information at a specified position
# in the data stream.
#
# @syntax  $object->readBlockHeaderAtIndex(indexRef)
# @type	   instance method
#
# @param   indexRef specifies the position to start reading block information
#		   on input, and will contain the updated position of the start of
#		   contents, properly adjusted for forms and chunks.
#
# @return  undef if there was a read error or if block contents cannot possibly
#		   fit in data buffer.
#		   if block is a form:	(1, formName, formContentsStartPosition, formContentsEndPosition+1)
#		   if block is a chunk: (2, chunkName, chunkContentsStartPosition, chunkContentsEndPosition+1)
# ----------------------------------------------------------------------

sub readBlockHeaderAtIndex
{
	# Process args.
	my $self		   = shift;
	my $streamIndexRef = shift;

	my $dataLength	   = length($self->{data});

	return undef if !defined($dataLength) || ($dataLength < 8);

	# Read block name.
	my $firstTag = substr($self->{data}, $$streamIndexRef, 4);
	$$streamIndexRef += 4;

	# Read block size.
	my $contentLength = 0;
	my $sizeByte;

	$contentLength += (ord(substr($self->{data}, $$streamIndexRef, 1)) << 24);
	++$$streamIndexRef;

	$contentLength += (ord(substr($self->{data}, $$streamIndexRef, 1)) << 16);
	++$$streamIndexRef;

	$contentLength += (ord(substr($self->{data}, $$streamIndexRef, 1)) << 8);
	++$$streamIndexRef;

	$contentLength += ord(substr($self->{data}, $$streamIndexRef, 1));
	++$$streamIndexRef;

	# If a form, read the form name.
	if ($firstTag ne "FORM")
	{
		# Return a chunk.
		return (2, $firstTag, $$streamIndexRef, $$streamIndexRef + $contentLength);
	}
	else
	{
		# Read form name.
		return undef if ($dataLength < 12);

		my $secondTag = substr($self->{data}, $$streamIndexRef, 4);
		$$streamIndexRef += 4;

		# Return a form.
		$contentLength -= 4;
		return (1, $secondTag, $$streamIndexRef, $$streamIndexRef + $contentLength);
	}
}

# ----------------------------------------------------------------------
# @syntax  object->checkBlock(contentIndexRef)
# @type	   instance method
#
# @param   contentIndexRef on input contains the index of the start of the
#		   block to check.	On output it contains the next position for
#		   reading in the stream.
#
# @return  1 if block and all child blocks are valid; 0 if no valid
#		   block exists at specified index.
# ----------------------------------------------------------------------

sub checkBlock
{
	# Process args.
	my $self			= shift;
	my $contentIndexRef = shift;

	# Get length of IFF data.
	my $dataLength = length($self->{data});
	return 0 if !defined($dataLength);
	return 0 if ($$contentIndexRef + 8) >= $dataLength;

	# Read the header at the specified position.
	my @result = $self->readBlockHeaderAtIndex($contentIndexRef);
	return 0 if !@result;

	# Verify that the end of block content is not beyond our data limit.
	return 0 if $result[3] > $dataLength;

	# Success if this is a chunk.
	if ($result[0] == 2)
	{
		# Move data index to end of contents + 1.
		$$contentIndexRef = $result[3];
		return 1;
	}
	elsif ($result[0] == 1)
	{
		# Process form contents recursively until we hit the end of the form contents.
		while ($$contentIndexRef < $result[3])
		{
			my $initialIndex = $$contentIndexRef;
			return 0 if !$self->checkBlock($contentIndexRef) || ($$contentIndexRef < $initialIndex + 8);
		}

		# Successfully verified 
		return ($$contentIndexRef == $result[3]);
	}
}

# ----------------------------------------------------------------------
# @syntax  object->isValidData()
# @type	   instance method
# @return  1 if data is valid iff data; 0 if data exists and is
#		   invalid.
# ----------------------------------------------------------------------

sub isValidData
{
	# Get self reference.
	my $self = shift;

	# Ensure we have data.
	return 0 if !defined($self->{data});

	# Get number of data bytes.
	my $dataLength = length $self->{data};
	return 1 if ($dataLength == 0);

	# Verify that first block consumes all data.
	my $contentIndex = 0;
	my @result = $self->readBlockHeaderAtIndex(\$contentIndex);
	return 0 if !@result;
	return 0 if $result[3] != $dataLength;

	# Test all blocks.
	$contentIndex = 0;
	return $self->checkBlock(\$contentIndex);
}

# ----------------------------------------------------------------------
# @type	   instance method
# ----------------------------------------------------------------------

sub pushStack
{
	my $self	= shift;
	my $infoRef = shift;

	my $stackRef = $self->{stack};
	push @$stackRef, $infoRef;
}

# ----------------------------------------------------------------------
# @type	   instance method
# ----------------------------------------------------------------------

sub popStack
{
	my $self	 = shift;
	my $stackRef = $self->{stack};
	return pop @$stackRef;
}

# ----------------------------------------------------------------------
# @type	   instance method
# ----------------------------------------------------------------------

sub getTopOfStack
{
	my $self	 = shift;
	my $stackRef = $self->{stack};
	return $$stackRef[(scalar @$stackRef) - 1];
}

# ----------------------------------------------------------------------
# @type	   instance method
# ----------------------------------------------------------------------

sub fatal
{
	my $self	= shift;
	my $message = shift;

	print "Iff:fatal@[";

	my $stackRef = $self->{stack};
	foreach my $infoRef (@$stackRef)
	{
		print "$$infoRef[1]/";
	}

	printf "]: %s\n", defined($message) ? $message : "<undefined>";
	exit -1;
}

# ----------------------------------------------------------------------
# @syntax  $object->isCurrentForm()
# @type	   instance method
#
# Indicates if the block (chunk or form) that starts at the
# current read location within the Iff is a form.
#
# @return  something that evalues to true if the block is a form; otherwise returns 0.
# ----------------------------------------------------------------------

sub isCurrentForm
{
	# Setup args.
	my $self = shift;

	# Get block header info for block starting at current read location.
	my $blockIndex = $self->{index};
	die "Iff: bad member variable" if !defined($blockIndex);

	my @blockInfo = $self->readBlockHeaderAtIndex(\$blockIndex);
	return 0 if !@blockInfo;

	return ($blockInfo[0] == 1);
}

# ----------------------------------------------------------------------
# @syntax  $object->getCurrentName()
# @type	   instance method
#
# Returns the name of the block (chunk or form) that starts at the
# current read location within the Iff.
#
# @return  undef if there was an error processing the data; otherwise
#		   it returns the block name as a string.
# ----------------------------------------------------------------------

sub getCurrentName
{
	# Setup args.
	my $self = shift;

	# Get block header info for block starting at current read location.
	my $blockIndex = $self->{index};
	die "Iff: bad member variable" if !defined($blockIndex);

	my @blockInfo = $self->readBlockHeaderAtIndex(\$blockIndex);
	return undef if !@blockInfo;
	return $blockInfo[1];
}

# ----------------------------------------------------------------------

sub enterForm
{
	# Process args.
	my $self	 = shift;
	my $formName = shift;

	# Ensure we're not already in a chunk.
	my $topOfStackRef = $self->getTopOfStack();
	$self->fatal("enterForm(): currently in a chunk.") if (defined($topOfStackRef) && @$topOfStackRef && ($$topOfStackRef[0] == 2));

	# Read the block header at current data position, adjusting index as needed.
	my @formInfo = $self->readBlockHeaderAtIndex(\$self->{index});
	$self->fatal("current is not a form.") if !scalar(@formInfo) || ($formInfo[0] != 1);
	$self->fatal("expecting form [$formName], found [$formInfo[1]].") if (defined($formName) && ($formName ne $formInfo[1]));

	# Push the form info onto the traversal stack.
	$self->pushStack([@formInfo]);
}

# ----------------------------------------------------------------------

sub exitForm
{
	# Process args.
	my $self	 = shift;
	my $formName = shift;

	# Get the top of the stack.
	my $infoRef = $self->popStack();
	$self->fatal("called exitForm when not in a form.") if (!defined($infoRef) || ($$infoRef[0] != 1));
	$self->fatal("called exitForm expecting form [$formName], found [$$infoRef[1]].") if (defined($formName) && ($formName ne $$infoRef[1]));

	# Move index one past end of the form.
	$self->{index} = $$infoRef[3];
}

# ----------------------------------------------------------------------

sub enterChunk
{
	# Process args.
	my $self	  = shift;
	my $chunkName = shift;

	# Ensure we're not already in a chunk.
	my $topOfStackRef = $self->getTopOfStack();
	$self->fatal("enterChunk(): already in chunk.") if (defined($topOfStackRef) && @$topOfStackRef && ($$topOfStackRef[0] == 2));

	# Read the block header at current data position, adjusting index as needed.
	my @chunkInfo = $self->readBlockHeaderAtIndex(\$self->{index});
	$self->fatal("current is not a chunk.") if !scalar(@chunkInfo) || ($chunkInfo[0] != 2);
	$self->fatal("expecting chunk [$chunkName], found [$chunkInfo[1]].") if (defined($chunkName) && ($chunkName ne $chunkInfo[1]));

	# Push the chunk info onto the traversal stack.
	$self->pushStack([@chunkInfo]);
}

# ----------------------------------------------------------------------

sub exitChunk
{
	# Process args.
	my $self	  = shift;
	my $chunkName = shift;

	# Get the top of the stack.
	my $infoRef = $self->popStack();
	$self->fatal("called exitChunk() when not in a chunk.") if (!defined($infoRef) || ($$infoRef[0] != 2));
	$self->fatal("called exitChunk() expecting chunk [$chunkName], found [$$infoRef[1]].") if (defined($chunkName) && ($chunkName ne $$infoRef[1]));

	# Move index one past end of the chunk.
	$self->{index} = $$infoRef[3];
}

# ----------------------------------------------------------------------
# @syntax  $object->getChunkLengthLeft()
# @type	   instance method
#
# @return  string read as C-style string from current chunk.
# ----------------------------------------------------------------------

sub getChunkLengthLeft
{
	my $self = shift;

	# Verify that we're currently in a chunk.
	my $topOfStackRef = $self->getTopOfStack();
	$self->fatal("getChunkLengthLeft(): not in chunk.") if (!defined($topOfStackRef) || !@$topOfStackRef || ($$topOfStackRef[0] != 2));
	$self->fatal("getChunkLengthLeft(): read position is not with the chunk!") if ($self->{index} > $$topOfStackRef[3]) || ($self->{index} < $$topOfStackRef[2]);
	
	# Return the number of bytes still available for reading in the chunk.
	return ($$topOfStackRef[3] - $self->{index});
}

# ----------------------------------------------------------------------
# @syntax  $object->read_string()
# @type	   instance method
#
# @return  string read as C-style string from current chunk.
# ----------------------------------------------------------------------

sub read_string
{
	my $self = shift;
	
	my $topOfStackRef = $self->getTopOfStack();
	$self->fatal("read_string() called while not in chunk") if !@$topOfStackRef || ($$topOfStackRef[0] != 2);

	my $returnString = "";
	my $lastReadChar;

	# Read string, don't include trailing null.
	while (($self->{index} < $$topOfStackRef[3]) && (ord($lastReadChar = substr($self->{data}, $self->{index}, 1)) != 0))
	{
		$returnString .= $lastReadChar;
		++$self->{index};
	}

	# Skip trailing null from input stream.
	if (($self->{index} < $$topOfStackRef[3]) && (ord($lastReadChar) == 0))
	{
		++$self->{index};
	}

	return $returnString;
}

# ----------------------------------------------------------------------
# @syntax  $object->write_string(string)
# @type	   instance method
# ----------------------------------------------------------------------

sub write_string
{
	my ($self, $string) = @_;
	
	my $topOfStackRef = $self->getTopOfStack();
	$self->fatal("write_string() called while not in chunk") if !@$topOfStackRef || ($$topOfStackRef[0] != 2);

	# Append null termination to string
	$string .= chr(0);

	# Get size difference from new string compared to old string
	my $sizeDifference = ((length $string) - ($$topOfStackRef[3] - $self->{index}));
	print "\n" if ($debug);
	print "Size difference: $sizeDifference\n" if ($debug);
	
	print "Old string went from $$topOfStackRef[2] to $$topOfStackRef[3]\n" if($debug);
	# Get data before portion we need to change - everything before chunk data
	my $beforeChunk = substr($self->{data}, 0, $self->{index});
	# Get data after portion we need to change - everything after chunk data
	my $afterChunk = substr($self->{data}, $$topOfStackRef[3], ((length $self->{data}) - $$topOfStackRef[3]));
	print "Length of total data: ".(length $self->{data})."\n" if ($debug);
	print "Length of before: ".(length $beforeChunk)."\n" if ($debug);
	print "Length of after: ".(length $afterChunk)."\n" if ($debug);
	
	# Update current data
	$self->{data} = ($beforeChunk.$string.$afterChunk);
	print "Length of total data: ".(length $self->{data})."\n" if ($debug);

	# Add size difference to chunk and forms above it
	my $stackRef = $self->{stack};
	foreach my $stackElemRef (@$stackRef)
	{
		print "\n" if ($debug);
		print (join "\t", @$stackElemRef) if ($debug);
		print "\n" if ($debug);
		# Update end index in stack
		$$stackElemRef[3] += $sizeDifference;
		print "New end: $$stackElemRef[3]\n" if ($debug);

		# Get index for size of element
		my $sizeIndex = $$stackElemRef[2] - (($$stackElemRef[0] == 1) ? 8 : 4); 
		print "Index for size $sizeIndex\n" if ($debug);
		
		# Get data before and after change we will make
		my $beforeChange = substr($self->{data}, 0, $sizeIndex);
		my $afterChange = substr($self->{data}, ($sizeIndex + 4), ((length $self->{data})- ($sizeIndex + 4)));
		print "Length of total data: ".(length $self->{data})."\n" if ($debug);
		print "Length of before: ".(length $beforeChange)."\n" if ($debug);
		print "Length of after: ".(length $afterChange)."\n" if ($debug);
		
		# Get old size as stored in $self->{data}
		my $contentLength = 0;
		$contentLength += (ord(substr($self->{data}, $sizeIndex, 1)) << 24);
		++$sizeIndex;
		$contentLength += (ord(substr($self->{data}, $sizeIndex, 1)) << 16);
		++$sizeIndex;
		$contentLength += (ord(substr($self->{data}, $sizeIndex, 1)) << 8);
		++$sizeIndex;
		$contentLength += ord(substr($self->{data}, $sizeIndex, 1));
		++$sizeIndex;
		print "Old Size: $contentLength\n" if ($debug);
		
		# Update size
		$contentLength += $sizeDifference;
		print "New Size: $contentLength\n" if ($debug);
		
		# Get new size into byte format
		my $sizeOutput = "";
		$sizeOutput .= chr(($contentLength >> 24) % 256);
		$sizeOutput .= chr(($contentLength >> 16) % 256);
		$sizeOutput .= chr(($contentLength >> 8) % 256);
		$sizeOutput .= chr($contentLength % 256);
		
		# Update data
		$self->{data} = ($beforeChange.$sizeOutput.$afterChange);
		print "Length of total data: ".(length $self->{data})."\n" if ($debug);
	
	}	
	
	# Update the index to one past the string
	$self->{index} += length $string;
}

# ----------------------------------------------------------------------
# @syntax  $object->read_uint8()
# @type	   instance method
#
# @return  integer value of current chunk byte.
# ----------------------------------------------------------------------

sub read_uint8
{
	my $self = shift;
	
	my $topOfStackRef = $self->getTopOfStack();
	$self->fatal("read_uint8(): called while not in chunk") if !@$topOfStackRef || ($$topOfStackRef[0] != 2);
	$self->fatal("read_uint8(): read position is outside of chunk") if ($self->{index} >= $$topOfStackRef[3]) || ($self->{index} < $$topOfStackRef[2]);

	my $returnInt = ord(substr($self->{data}, $self->{index}, 1));
	++$self->{index};

	return $returnInt;
}

# ----------------------------------------------------------------------
# @syntax  $object->write_uint8(uint)
# @type	   instance method
# ----------------------------------------------------------------------

sub write_uint8
{
	my $self = shift;
	my $newval = shift;
	
	my $topOfStackRef = $self->getTopOfStack();
	$self->fatal("write_uint8(): called while not in chunk") if !@$topOfStackRef || ($$topOfStackRef[0] != 2);
	$self->fatal("write_uint8(): write position is outside of chunk") if ($self->{index} >= $$topOfStackRef[3]) || ($self->{index} < $$topOfStackRef[2]);

	my $newbyte = chr($newval % 256);

	my $before = substr($self->{data}, 0, $self->{index});
	my $after = substr($self->{data}, ($self->{index} + 1), ((length $self->{data}) - ($self->{index} + 1)));
	
	my $self->{data} = ($before.$newbyte.$after);
	++$self->{index};
}

# ----------------------------------------------------------------------
# @syntax  $object->read_uint16()
# @type	   instance method
#
# @return  integer value of little-endian-style 16-bit value starting at current chunk byte.
# ----------------------------------------------------------------------

sub read_uint16
{
	my $self = shift;
	
	my $topOfStackRef = $self->getTopOfStack();
	$self->fatal("read_uint16(): called while not in chunk") if !@$topOfStackRef || ($$topOfStackRef[0] != 2);
	$self->fatal("read_uint16(): read position is outside of chunk") if ($self->{index} >= $$topOfStackRef[3]) || ($self->{index} < $$topOfStackRef[2]);
	$self->fatal("read_uint16(): not enough bytes left in chunk") if (($self->{index} + 2) > $$topOfStackRef[3]);

	my $returnInt = ord(substr($self->{data}, $self->{index}, 1));
	++$self->{index};

	$returnInt += (ord(substr($self->{data}, $self->{index}, 1)) << 8);
	++$self->{index};

	return $returnInt;
}

# ----------------------------------------------------------------------
# @syntax  $object->write_uint16(uint)
# @type	   instance method
# ----------------------------------------------------------------------

sub write_uint16
{
	my $self = shift;
	my $newval = shift;
	
	my $topOfStackRef = $self->getTopOfStack();
	$self->fatal("write_uint16(): called while not in chunk") if !@$topOfStackRef || ($$topOfStackRef[0] != 2);
	$self->fatal("write_uint16(): write position is outside of chunk") if ($self->{index} >= $$topOfStackRef[3]) || ($self->{index} < $$topOfStackRef[2]);
	$self->fatal("write_uint16(): not enough bytes left in chunk") if (($self->{index} + 2) > $$topOfStackRef[3]);

	my $newbytes = "";
	$newbytes .= chr($newval % 256);
	$newbytes .= chr(($newval >> 8) % 256);

	my $before = substr($self->{data}, 0, $self->{index});
	my $after = substr($self->{data}, ($self->{index} + 2), ((length $self->{data}) - ($self->{index} + 2)));
	
	my $self->{data} = ($before.$newbytes.$after);
	$self->{index} += 2;
}

# ----------------------------------------------------------------------
# @syntax  $object->read_uint32()
# @type	   instance method
#
# @return  integer value of little-endian-style 32-bit value starting at current chunk byte.
# ----------------------------------------------------------------------

sub read_uint32
{
	my $self = shift;
	
	my $topOfStackRef = $self->getTopOfStack();
	$self->fatal("read_uint32(): called while not in chunk") if !@$topOfStackRef || ($$topOfStackRef[0] != 2);
	$self->fatal("read_uint32(): read position is outside of chunk") if ($self->{index} >= $$topOfStackRef[3]) || ($self->{index} < $$topOfStackRef[2]);
	$self->fatal("read_uint32(): not enough bytes left in chunk") if (($self->{index} + 4) > $$topOfStackRef[3]);

	my $returnInt = ord(substr($self->{data}, $self->{index}, 1));
	++$self->{index};

	$returnInt += (ord(substr($self->{data}, $self->{index}, 1)) << 8);
	++$self->{index};

	$returnInt += (ord(substr($self->{data}, $self->{index}, 1)) << 16);
	++$self->{index};

	$returnInt += (ord(substr($self->{data}, $self->{index}, 1)) << 24);
	++$self->{index};

	return $returnInt;
}

# ----------------------------------------------------------------------
# @syntax  $object->write_uint16(uint)
# @type	   instance method
# ----------------------------------------------------------------------

sub write_uint32
{
	my $self = shift;
	my $newval = shift;
	
	my $topOfStackRef = $self->getTopOfStack();
	$self->fatal("write_uint32(): called while not in chunk") if !@$topOfStackRef || ($$topOfStackRef[0] != 2);
	$self->fatal("write_uint32(): write position is outside of chunk") if ($self->{index} >= $$topOfStackRef[3]) || ($self->{index} < $$topOfStackRef[2]);
	$self->fatal("write_uint32(): not enough bytes left in chunk") if (($self->{index} + 4) > $$topOfStackRef[3]);

	my $newbytes = "";
	$newbytes .= chr($newval % 256);
	$newbytes .= chr(($newval >> 8) % 256);
	$newbytes .= chr(($newval >> 16) % 256);
	$newbytes .= chr(($newval >> 24) % 256);

	my $before = substr($self->{data}, 0, $self->{index});
	my $after = substr($self->{data}, ($self->{index} + 4), ((length $self->{data}) - ($self->{index} + 4)));
	
	my $self->{data} = ($before.$newbytes.$after);
	$self->{index} += 4;
}

# ----------------------------------------------------------------------
# @syntax  $object->skipBytes(byteCount)
# @type	   instance method
# ----------------------------------------------------------------------

sub skipBytes
{
	my $self	  = shift;
	my $skipCount = shift;
	$self->fatal("skip_bytes(): bad skip count arg") if !defined($skipCount);

	my $topOfStackRef = $self->getTopOfStack();
	$self->fatal("skip_bytes(): called while not in chunk") if !@$topOfStackRef || ($$topOfStackRef[0] != 2);
	$self->fatal("skip_bytes(): tried to skip past end of chunk") if ($self->{index} + $skipCount) > $$topOfStackRef[3];

	$self->{index} += $skipCount;
}

# ----------------------------------------------------------------------
# @syntax  $object->walkChildBlocks(callbackRef)
# @type	   instance method
# ----------------------------------------------------------------------

sub walkChildBlocks
{
	# Setup args.
	my $self		  = shift;
	my $callbackRef	  = shift;

	# Abort if this block is a chunk.
	my $blockRef		= $self->getTopOfStack();
	$self->fatal("walkChildBlocks() called on a chunk") if ($$blockRef[0] != 1);

	# Determine end of current block.
	my $startBlockIndex = (defined($blockRef) ? $$blockRef[2] : 0);
	my $endBlockIndex	= (defined($blockRef) ? $$blockRef[3] : length($self->{data}));
	my $callbackReturnCode = 1;

	for ($self->{index} = $startBlockIndex; ($self->{index} < $endBlockIndex) && ($callbackReturnCode >= 0); )
	{
		# Get block info for block at index.
		my @childInfo = $self->readBlockHeaderAtIndex(\$self->{index});
		$self->fatal("failed to get block info") unless (@childInfo && (($childInfo[0] == 1) || ($childInfo[0] == 2)));

		# Enter child block.
		$self->pushStack([@childInfo]);

		# Make callback.
		my $childIsChunk = ($childInfo[0] == 2);
		$callbackReturnCode = &$callbackRef($self, $childInfo[1], $childIsChunk);

		# Recursively walk child's children if user callback didn't stop the traversal and
		# the child block is not a chunk.
		if (($callbackReturnCode >= 1) && !$childIsChunk)
		{
			$callbackReturnCode = $self->walkChildBlocks($callbackRef);
		}

		# Exit from child block.
		$self->popStack();

		# Since we don't trust what the callback may have done to index, set it to what we think it should be,
		# the end of the child block we just handled + 1.
		$self->{index} = $childInfo[3];
	}

	return $callbackReturnCode;
}

# ----------------------------------------------------------------------
# @syntax  $object->walkIff(callbackRef)
# @type	   instance method
#
# This function will enter each block in the block hierarchy contained
# by the current traversal level.  Calling this function while in a
# chunk does nothing.  Traversal always starts at the beginning of the
# enclosing chunk.
#
# The caller is given control via the given reference to a callback 
# function.	 It is called like this:
#
#	&$callbackRef(iff, blockName, isChunk)
#
# The callback function returns one of the following:
#  -1: completely stop traversal (no more callbacks will be made).
#	0: prevent further traversal below this node.  Only effective when visiting a form.
#	1: continue traversal as normal.
#
# The callback function should not traverse outside of the given block
# during the callback.
# ----------------------------------------------------------------------

sub walkIff
{
	print "walkIff(): begin\n" if $debug;

	# Process args.
	my $self		= shift;
	my $callbackRef = shift;
	die "Iff::walk(): invalid callbackRef arg specified" if ref($callbackRef) ne "CODE";

	# Check if we're in a chunk.
	my $infoRef = $self->getTopOfStack();
	if (@$infoRef && ($$infoRef[0] == 2))
	{
		# Nothing to do, we're in a chunk.
		return;
	}

	# If we're at root level, bail unless we're at the start of the data.
	if (!defined($infoRef) && (length $self->{data} == 0))
	{
		# Nothing to do.
		return;
	}

	$self->walkChildBlocks($callbackRef);

	print "walkIff(): end\n" if $debug;
}

# ----------------------------------------------------------------------
# @syntax  Iff->createFromFileHandle(fileHandleRef)
# @type	   class method
#
# This class member function assumes that the entire file contents of
# fileHandleRef is one complete IFF.  If there is any leading or trailing
# space in the file or if the file contains only a partial IFF, this
# function will not allow creation of an IFF object.  The caller cannot
# assume anything about the position of fileHandlerRef after this call
# and the caller is still responsible for closing the file handle.
#
# @param fileHandleRef	reference to the file handle that contains the
#						Iff data to read.
# ----------------------------------------------------------------------

sub createFromFileHandle
{
	# Process args.
	my ($class, @args) = @_;
	die "Missing file handle reference arg" if !@args || !ref($args[0]);
	my $fileHandleRef = $args[0];

	# Create the new object.
	my $self = {};
	bless $self;

	# Initialize data members.
	$self->initialize();

	# Set file access mode to binary.
	die "Could not set file handle [$fileHandleRef] to binary mode: $!" if !binmode($fileHandleRef);

	# Rewind the file, read entire contents.
	die "Could not set file handle [$fileHandleRef] to start of file: $!" if !seek($fileHandleRef, 0, 0);

	# Get file size.
	my @fileStat = stat $fileHandleRef;
	die "Something went wrong with the stat on [$fileHandleRef]: $!" if !@fileStat;
	my $fileSize = $fileStat[7];

	# Read the data.
	#die "Failed to read file contents for [$fileHandleRef]: $!" if !read($fileHandleRef, $self->{data}, $fileSize);
	return undef if !read($fileHandleRef, $self->{data}, $fileSize);

	# Check if this is valid iff data.
	return undef if !$self->isValidData();

	# Ready for service.
	return $self;
}

# ======================================================================

# ----------------------------------------------------------------------
# @syntax  Iff->writeToFileHandle(fileHandleRef)
# @type	   class method
#
# This class member will write out the current Iff to the file handle 
# reference specified. It will not change the current state of the Iff
# in case the user still wants to make changes to it. The user can 
# assume that the position of fileHandleRef is at the end of the iff 
# data if and only if this function returns successfully.
#
# @param fileHandleRef	reference to the file handle that the Iff data
#						will be written to.
# ----------------------------------------------------------------------

sub writeToFileHandle
{
	# Process args
	my ($self, @args) = @_;
	die "Missing file handle reference arg" if !@args || !ref($args[0]);
	my $fileHandleRef = $args[0];
	
	# Verify that current data is valid iff data
	die "Can not write invalid iff data to file" if !$self->isValidData();
	
	# Set file access mode to binary.
	die "Could not set file handle [$fileHandleRef] to binary mode: $!" if !binmode($fileHandleRef);
	
	# Rewind the file.
	die "Could not set file handle [$fileHandleRef] to start of file: $!" if !seek($fileHandleRef, 0, 0);
	
	# Write to file
	die "Failed to write file contents for [$fileHandleRef]: $!" if !syswrite($fileHandleRef, $self->{data}, length $self->{data});
}

1;
