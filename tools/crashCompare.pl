#!/usr/bin/perl -w
use strict;

my (%keys, %rows);
my (@files, $file);
my $row = 0;
my $spaced = 0;

die "$0: Usage: $0 <directory>\n" unless(@ARGV);

if($ARGV[0] eq "-s")
{
	$spaced=1;
	shift;
}

opendir(DIR, "$ARGV[0]") || die "$0: Can't open directory $ARGV[0]\n";
while($_ = readdir(DIR))
{
	next unless($_ =~ m%\.txt$% && $_ !~ m%^_%);
	push(@files, $_);
}
closedir(DIR);

exit if($#files == -1);

foreach $file(@files)
{
	open(INPUT, "<$ARGV[0]/$file") || die "$0: Can't open $_: $!\n"; 
	$keys{"z-filename"}=1;
	while(<INPUT>)
	{
		$/="\n\n";
		my $trash = <INPUT>;
		$trash = <INPUT>;
		$/="\n";
		while($_ = <INPUT>)
		{
			chomp;
			if(/:/)
			{	
				my($key, $value) = split(/:/, $_, 2);
				$value =~ s%\s+% %g;
				$value =~ s%^\s+%%;
				$value =~ s%\s+$%%;
				my @elements = split(/\s/, $value);
				if($spaced && $#elements > 0)
				{
					my $origkey = $key;
					for(0 .. $#elements)
					{
						$key = $origkey . ($_+1);
						$rows{$row}{$key} = $elements[$_];
						$keys{$key} = 1;
					}
				}
				else
				{
					$rows{$row}{$key} = $value;
					$keys{$key} = 1;
				}
			}
			$rows{$row}{"z-filename"} = $file;
		}
	}
	close(INPUT);
	$row++;
}

print join("\t", sort(keys(%keys)));
print "\n";

$row--;

my $colcount;
for(0..$row)
{
	$colcount = 1;
	if (defined $rows{$_})
	{
		my %current = %{$rows{$_}};
		foreach my $column (sort(keys(%keys)))
		{
			if(defined($current{$column}))
			{
				print $current{$column};
			}
			else
			{
				print "-";
			}
			print "\t" unless(scalar(keys(%keys)) == $colcount);
			$colcount++;
		}
		print "\n";
	}
}
