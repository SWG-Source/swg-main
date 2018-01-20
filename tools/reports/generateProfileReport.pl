my @profiles;
my $currentEntry;
my $callStack;
my @callStacks;
my $totalCount = 0;
my $uniqueCount = 0;
my %accumulator;
my %lookup;
my $totalTime = 0;


while(<STDIN>)
{
    if(! ($_ =~ /rofile/))
    {
        if($_ =~ /\s*(\w*)\s*(\w*)\%\s*(\w*)\s*(-)\s*(.*)/)
        {
	    $currentEntry .= "|$5,$3,$1";
	    $callStack .= $_;
	}
    }
    else
    {
	if(! ($currentEntry eq ""))
	{
	    $totalCount++;

	    @entries = split('\|', $currentEntry);
	    $signature = "";

	    my $callTime = 0;
	    for $e(@entries)
	    {
		@items = split(',', $e);
		$signature .= @items[0];
		if($callTime < @items[2])
		{
		    $callTime = @items[2];
		}
	    }
	    
	    if(exists($accumulator{$signature}))
	    {
		$accumulator{$signature} += $callTime;
	    }
	    else
	    {
		$accumulator{$signature} = $callTime;
		$lookup{$signature} = $callStack;
		$uniqueCount++;
	    }
	    $totalTime += $callTime;

	    $currentEntry = "";
	    $callStack = "";
	}
    }
}


$timeMs = $totalTime / 1000;
print "Profile Report: $uniqueCount unique reports of $totalCount reports logged. $timeMs milliseconds logged\n";

foreach my $key (sort{$accumulator{$b} <=> $accumulator{$a}} keys %accumulator)
{
    $precentage = 0;
    if($accumulator{$key} != 0)
    {
	$percentage = $accumulator{$key} / $totalTime * 100;
    }
   
    print "\n=============================================\n\n";
    print "$accumulator{$key} totalTime, $percentage\% of all time logged\n";
    print "$lookup{$key}\n";
}
print "\n=============================================\n\n";
