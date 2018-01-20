die "usage: mapFileLookUpWin32.pl file.map [[address | \@responseFile]...]\n" if (@ARGV < 2);

$mapFile = shift(@ARGV);
open(MAP, $mapFile);

	while (@ARGV)
	{
		$find = shift(@ARGV);
		
		# handle response files that are call stacks
		if ($find =~ /^\@/)
		{
			$find =~ s/^.//;

			# search the file for IP addresses to look up
			undef @find;
			open(FIND, $find);
				while (<FIND>)
				{
					chomp;
					s/^.*unknown\(// && s/\).*//;
					push(@find, $_) if ($_ ne "");
				}
			close(FIND);
			
			# insert all the found entries at the beginning of @ARGV
			splice(@ARGV, 0, 0, @find);
			$find = shift(@ARGV);
		}

		$find = hex($find);

		# go to the beginning and skip past some cruft
		seek(MAP, 0, 0);
		while (<MAP>)
		{
			last if (/^\s+Address/)
		}

		# search for the symbol containg this address
		$found = 0;
		$lastAddress = 0;
		$lastSymbol = "";
		while (<MAP>)
		{
			chomp;
			($seg, $symbol, $address, $junk) = split;
			$address = hex($address);

			if ($lastAddress <= $find && $address > $find)
			{
				printf "%08x: %08x %08x %s\n", $find, $lastAddress, $address, $lastSymbol;
				$found = 1;
				last;
			}

			$lastAddress = $address;
			$lastSymbol = $symbol;
		}
		printf "%08x: not found\n", $find if ($found == 0);

	}

close(MAP);
