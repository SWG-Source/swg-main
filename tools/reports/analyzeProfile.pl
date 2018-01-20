my $profileText;
my %profileNames;
my $profileTag;

while(<STDIN>)
{
    if(! ($_ =~ /rofile/))
    {
	if($_ =~ /\s*(\w*)\s*(\w*)\%\s*(\w*)\s*(-)\s*(.*)/)
	{
	    $profileTag .= "$5\n";
	    $profileText .= $_;
	    $entry = "$1,$2,$3,$5";

	    if(! exists($profileNames{$5}))
	    {
		$profileNames{$5} = $entry;
	    }
	    else
	    {
		@items = split(',', $profileNames{$5});
		$totalTime = $items[0] + $1;
		$callCount = $items[2] + $3;
		$newEntry = "$totalTime, $items[1], $callCount, $5";
	    }
	}
    }
}

print "\"Description\", \"Total Time\", \"Call Count\", \"Call Cost\"\n";
foreach my $key(keys(%profileNames))
{
    @items = split(',', $profileNames{$key});
    $callCost = `echo \"$items[0] / $items[2]\" | bc -l`;
    chomp($callCost);
    
    print "$key, $items[0], $items[2], $callCost\n";
}
