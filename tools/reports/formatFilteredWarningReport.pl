my @warnings;
my $currentWarning = 0;

while(<STDIN>)
{
    if(! ($_ =~ /3721c4f3/) ) # disable network overflow warnings
    {
	if($_ =~ /^* : WARNING |^WARNING: /o)
	{
	    $currentWarning++;
	    $warnings[$currentWarning] = $_;
	}
	elsif($_ =~ /\s+ : caller /)
	{
	    $warnings[$currentWarning] .= $_;
	}
    }
}

sub compareWarnings
{
    my ($a, $b) = @_;
    if($a =~ / : WARNING (\w*):*/o)
    {
	$sigA = $1;
	if($b =~ / : WARNING (\w*):*/o)
	{
	    $sigB = $1;

	    if($sigB eq $sigA)
	    {
		return 1;
	    }
	}
    }
    return 0;
}

my $reportIndex = 0;
my %dupeReport;


$warningCount = @warnings;
my %warningHash;
my @reportOutput;
for ($i = 0; $i < @warnings; $i++)
{
    
    $duped = 0;
    if($warnings[$i] =~ / : WARNING (\w*):*/o)
    {
	if(! exists($warningHash{$1}))
	{
	    $warningHash{$1} = 1;
	    $dupeReport{$1} = $warnings[$i];
	    $reportIndex++;
	}
	else
	{
	    $warningHash{$1}++;
	}
    }
}

print "Warning Report: $reportIndex unique warnings logged. Total warnings: $warningCount\n";
print "** NOTE: duplicates are removed by WARNING signature, not by the dynamic contents of the warning formatted via snprintf(...)\n";
print "Detailed report follows.\n\n\n\n";

foreach my $key (sort{$warningHash{$b} <=> $warningHash{$a}} keys %warningHash)
{
    print "\n=============================================\n\n";
    print "$warningHash{$key} reports:\n";
    print $dupeReport{$key};
}
print "\n=============================================\n\n";
