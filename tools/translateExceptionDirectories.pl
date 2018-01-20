die "usage: $0 ProgramName.exe PathToExceptionDirectories\n" if (@ARGV != 2);

my $debug = 1;

$program = shift;
$dir = shift;

opendir(DIR, $dir) || die "could not open directory $dir\n";
	my @filenames = readdir(DIR);
closedir(DIR);

# ignore . and ..
shift @filenames;
shift @filenames;

# sort them just to be nice
@filenames = sort @filenames;

# create the temp file of all the addresses
open(TMP, ">excepts.tmp");
	foreach(@filenames)
	{
		print "look up $_\n" if ($debug);
		print TMP "0x", $_, "\n";
	}
close(TMP);

# create descriptions files for all the addresses
open(ADDR2LINE, "AddressToLine $program < excepts.tmp |");
	while (<ADDR2LINE>)
	{
		chomp;
		
		$address = shift(@filenames);

		# ignore symbols we couldn't look up
		if (/^unknown/i)
		{
			print "$address unknown\n" if ($debug);
			next;
		}

		# strip off the path
		s/^.*[\\\/]//;

		# don't overwrite existing descriptions
		$desc = "$dir/$address/_description.txt";
		if (! -e $desc)
		{
			open(DESC, ">$desc") || die "could not open $desc for writing\n";
				print DESC $_, "\n";
			close(DESC);

			print "$address $desc\n" if ($debug);

		}
	}
close(ADDR2LINE);
