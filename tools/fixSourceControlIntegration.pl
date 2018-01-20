#!/usr/bin/perl

open(IN, "swg.dsw") || die "could not open swg.dsw\n";
open(OUT, ">swg.new");

$project = "";

while (<IN>)
{
	print OUT;

	chomp;
	if (s/^Project: "//)
	{
		s/".*//;
		$project = $_;
	}
	
	if (/^Package=<5>/ && $project ne "")
	{
		while ($_ ne "}}}\n")
		{
			$_ = <IN>;
		}

		print OUT "{{{\n";
		print OUT "    begin source code control\n";
		print OUT "    $project\n";
		print OUT "    .\n";
		print OUT "    end source code control\n";
		print OUT "}}}\n";
		
		$project = "";
	}
}


close(IN);
close(OUT);

unlink("swg.dsw");
rename("swg.new", "swg.dsw");
