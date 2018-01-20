# process all the files on the command line
while ($_ = shift(ARGV))
{
	# handle RSP files by reading their content and putting that back on the command line
	if (/.rsp/ || /.RSP/)
	{
		open(RSP, $_);
		
		while (<RSP>)
		{
			chop;
			push(add, $_)
		}
		
		unshift(ARGV, @add);
		undef @add;
		close(RSP);

		next;
	}

	# provide status
	print $_ . ":\n";
	
	if (/.CPP/ || /.cpp/)
	{
		print "    skipping source file\n";
		next;
	}

	# open the files for i/o
	$file = $_;
	$new = $file . ".new";
	open(IN, $file);

	# process all the lines in the input file
	undef %symbol;
	undef %required;
	undef %inline;
	
	while (<IN>)
	{
		chop;
		
		# strip comments
		s#//.*##;
	
		if (/#include\s+"/)
		{
			
			($junk1, $header, $junk2) = split(/[" ]+/);
			$class = $header;
			$class =~ s#.*/##;
			$class =~ s#\.h##;
			
			if (!($class =~ /^First/))
			{
				$symbol{$class} = $header;
				$required{$class} = "_";
				$inline{$class} = "_";
			}
		}
		elsif (/#include\s+</)
		{
			print "    " . $_ . "\n";
		}
		else
		{
			if (/^\s*inline/)
			{
				$section = "inline";
			}
			elsif  (/^\s*class/)
			{
				$section = "class";
			}

			foreach $class (keys %symbol)
			{
				if ($section eq "class")
				{
					# handle derived from
					$required{$class} = "R" if (/:\s*public\s+$class/);

					# handle use of nested class
					$required{$class} = "R" if (/$class\s*::/);

					# handle member variable
					$required{$class} = "R" if (/^\s*$class\s+[a-zA-Z_]\w*\s*;\s*$/);

					# handle member variable
					$required{$class} = "R" if (/^\s*$class\s+[a-zA-Z_]\w*\s*;\s*$/);

					# handle mutable member variable
					$required{$class} = "R" if (/^\s*mutable\s+$class\s+[a-zA-Z_]\w*\s*;\s*$/);

					# handle const member variable
					$required{$class} = "R" if (/^\s*const\s+$class\s+[a-zA-Z_]\w*\s*;\s*$/);
				}
				elsif ($section eq "inline")
				{
					# handle use of nested class
					$inline{$class} = "I" if (/$class\s*::/);

					# handle inline function argument
					$inline{$class} = "I" if (/^\binline\b.*\b$class\b/);

					# handle local variable
					$inline{$class} = "I" if (/^\s*$class\s+[a-zA-Z_]\w*\s*;\s*$/);

					# handle const local variable
					$inline{$class} = "I" if (/^\s*const\s+$class\s+[a-zA-Z_]\w*\s*;\s*$/);
				}
			}
		}
			
	}

	# done accessing the contents of the files
	close(IN);

	foreach $b (sort keys %symbol)
	{
		print "    " . $required{$b} . $inline{$b} ." " . $b . " = " . $symbol{$b} . "\n";
	}

}
