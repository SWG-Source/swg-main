my @exceptions;
my $currentException = 0;
my $nearestWarning = "";
while(<STDIN>)
{
    if($_ =~ /^* : WARNING |^WARNING: /)
    {
	$nearestWarning = $_;
    }
    if ($_ =~ /^java/)
    {
	$currentException++;
	$exceptions[$currentException] = $nearestWarning.$_;
    }
    elsif($_ =~ /\s+at /)
    {
	$exceptions[$currentException] .= $_;
    }
}

my @reportOutput;
my $reportIndex = 0;
my %dupeReport;
for ($i = 0; $i < @exceptions; $i++)
{
    $duped = 0;
    for($j = 0; $j < @reportOutput; $j++)
    {
	if($exceptions[$i] eq $reportOutput[$j])
	{
	    $duped = 1;
	    break;
	}
    }

    $reports = 1;
    for($j = 0; $j < @exceptions; $j++)
    {
	if($i != $j)
	{
	    if($exceptions[$i] eq $exceptions[$j])
	    {
		$reports++;
	    }
	}
    }

    if($duped == 0)
    {
	$callStack = $exceptions[$i];
	$reportOutput[$reportIndex] = $exceptions[$i];
	$reportIndex++;
	$dupeReport{$callStack} = $reports;
    }
}


print "Java Exception Report: $reportIndex unique call stacks logged. Total call stacks: $currentException\n";
print "Detailed report follows.\n\n\n\n";

foreach my $key (sort{$dupeReport{$b} <=> $dupeReport{$a}} keys %dupeReport)
{
    print "\n=============================================\n\n";
    print "$dupeReport{$key} reports:\n";
    print $key;

}

