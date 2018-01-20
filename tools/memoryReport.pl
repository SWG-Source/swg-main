die "usage: perl memoryReport.pl  [-c (sort by count) | -a (sort by allocated amount)] [-l] logFile.txt" if (@ARGV < 1 || $ARGV[0] eq "-h");

$sortMethod = 0;  # 0 = using sort by allocated amount, 1 = sort by allocation count

if ($ARGV[0] eq "-c")
{
	shift @ARGV;
	$sortMethod = 1;
}

if ($ARGV[0] eq "-a")
{
	shift @ARGV;
	$sortMethod = 0;
}


if ($ARGV[0] eq "-l")
{
	shift @ARGV;
	$lines = 1;
}

sub sortAllocated
{
	return -($allocated{$a} <=> $allocated{$b});
}

sub sortCount
{
	return -($count{$a} <=> $count{$b});
}

while (<>)
{
	chomp;

	if (/memory allocation/ || /memory leak/)
	{
		s/.*[\/\\]//;
		s/^.*unknown/unknown/;
		s/:.*,//;
		s/bytes$//;
		s/\(.*\)// if (! $lines);
		($file, $size) = split;
		$allocated{$file} += $size;
		$count{$file} += 1;
	}
	elsif (s/: alloc / /)
	{
		s/=.*//;
		s/\(.*\)// if (! $lines);
		($file, $size) = split;
		$allocated{$file} += $size;
		$count{$file} += 1;
	}
}

if ($sortMethod == 0)
{
	# print sorted by allocated amount
	foreach (sort sortAllocated keys %allocated)
	{
		print $count{$_}, "\t", $allocated{$_}, "\t", $_, "\n";
	}
}
else
{
	# print sorted by # allocations
	foreach (sort sortCount keys %count)
	{
		print $count{$_}, "\t", $allocated{$_}, "\t", $_, "\n";
	}
}
