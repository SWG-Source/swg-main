# Script to take output from the Transform::multiply tracking REPORT_LOG output
# and generate a report of callstacks sorted in descending frequency order.

use strict;

my $inCallstack        = 0;
my $callstackFrequency = 0;
my $callstackLinesRef;
my $debug              = 0;

my %callstacksByFrequency;

sub submitCallstack
{
    die "bad callstackFrequency [$callstackFrequency]" if (!($callstackFrequency =~ m/^\d+$/));
    return if (@$callstackLinesRef < 1);

    # Make sure there's an array reference to hold all callstacks mapping to this frequency.
    if (!exists $callstacksByFrequency{$callstackFrequency})
    {
	$callstacksByFrequency{$callstackFrequency} = [];
    }

    # Get array ref.
    my $callstackArrayRef = $callstacksByFrequency{$callstackFrequency};

    # Add callstack lines array to it.
    push @$callstackArrayRef, $callstackLinesRef;
}

sub resetCallstack
{
    $callstackLinesRef = [];
}

while (<>)
{
    #-- Clean up line: remove line number and time info from log.
    chomp();
    s/\d+\s+\d+\.\d+\s+//;

    #-- Process line.

    # Check if this matches a start of callstack line.
    if (m/Transform::multiply/)
    {
	if ($inCallstack)
	{
	    # Add existing (now complete) callstack, restart a new one immediately following, starting on this line.
	    submitCallstack();
	}
	else
	{
	    # Mark that we're now in a callstack so we know to scan following lines.
	    $inCallstack = 1;
	}
	resetCallstack();
	
	# Parse out frequency.
	if (m/called (\d+) times/)
	{
	    $callstackFrequency = $1;
	}
	else
	{
	    die "Failed to get call frequency on input line [$_]";
	}
	
	# Remove unique callstack numeric info at end since we sort differently (by frequency) than raw output.
	s/\s\(\d+ of \d+ unique callstacks\)//;

	# Add header line to callstack lines.
	push @$callstackLinesRef, $_;

	print "Found callstack frequency [$callstackFrequency]\n" if $debug;
    }
    elsif ($inCallstack)
    {
	# Fixiup lines I bumbled output on.
	s/(\d+) caller \d+/caller $1/;

	if (m/caller \d+/)
	{
	    if (!m/unknown/)
	    {
		# Looks like a good callstack line, keep it.
		push @$callstackLinesRef, $_;
	    }
	}
	else
	{
	    # Looks like this callstack is done.
	    submitCallstack();
	    $inCallstack = 0;
	}
    }
}

# Print out callstacks sorted by descending numeric frequency.
my @frequencies = sort { return $b <=> $a; } (keys %callstacksByFrequency);

print "There are ", @frequencies + 0, " unique callstack frequencies.\n";
foreach my $frequency (@frequencies)
{
    my $callstackArrayRef = $callstacksByFrequency{$frequency};
    my $callstackCount    = @$callstackArrayRef;

    print "========================================\n";
    print "FREQUENCY: $frequency ($callstackCount callstacks)\n";
    print "========================================\n";
    print "\n";
    for (my $i = 0; $i < $callstackCount; ++$i)
    {
	my $callstackLinesRef = $$callstackArrayRef[$i];
	my $lineCount         = @$callstackLinesRef;

	print "$$callstackLinesRef[0]\n";
	for (my $lineIndex = 1; $lineIndex < $lineCount; ++$lineIndex)
	{
	    print "\t$$callstackLinesRef[$lineIndex]\n";
	}
	print "\n";
    }
}

print "DONE.\n";

