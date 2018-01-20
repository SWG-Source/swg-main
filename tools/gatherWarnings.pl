#!/usr/perl/bin

sub usage
{
	die "usage: perl gatherWarnings.pl [-c] [-s ##] [-dv] [-nl] sourceFile ...\n" .
		"\t-c  = count repeated warnings\n" .
		"\t-s  = combine similar warnings that differ by no more than ## words (implies -c)\n" .
		"\t-dv = strip debug view timestamps\n" .
		"\t-nl = strip warning locations\n";
}

while ($ARGV[0] =~ /^-/ && $ARGV[0] ne "-")
{
	if ($ARGV[0] eq "-dv")
	{
		$debugView = 1;
	}
	elsif ($ARGV[0] eq "-nl")
	{
		$noLocation = 1;
	}
	elsif ($ARGV[0] eq "-s")
	{
		$similar = $ARGV[1];
		$count = 1;
		shift;
	}
	elsif ($ARGV[0] eq "-c")
	{
		$count = 1;
	}
	else
	{
		usage();
	}

	shift @ARGV;
}

usage if (@ARGV == 0);	

sub numerically
{
	return -($a <=> $b);
}

while (<>)
{
	s/^\s*\d+\s+\d+\.\d+\s+\[\d+\]\s+// if ($debugView);
	s/\S+ : WARNING:/WARNING:/ if ($noLocation);
	s/\s+/ /;
	
	if (/WARNING:/)
	{
		if ($similar)
		{
			chomp;

			foreach $compare (keys %warnings)
			{
				@current = split(/\s+/, $_);
				@compare = split(/\s+/, $compare);

				if (scalar(@current) == scalar(@compare))
				{
					$count = 0;
					$out = "";
					while (@current)
					{
						$a = shift @current;
						$b = shift @compare;
						
						if ($a eq $b)
						{
							$out .= " $a";
						}
						else
						{
							$out .= " XXXX";
							$count += 1;
						}
					}
					
					if ($count <= $similar)
					{
						$out =~ s/^ //;
						if ($warnings{$out} ne $warnings{$compare})
						{
							$warnings{$out} = $warnings{$compare};
							delete $warnings{$compare};
						}

						$_ = $out;
					}
					else
					{
					}
				}
			}

			$warnings{$_} += 1 if ($repeat == 0)
		}
		elsif ($count)
		{
			chomp;
			$warnings{$_} += 1;
		}
		else
		{
			print;
		}
	}
}

if ($count)
{
	foreach (keys %warnings)
	{
		push(@warnings, sprintf("%5d %s", $warnings{$_}, $_));
	}

	foreach (sort numerically @warnings)
	{
		print $_, "\n";
	}
}
