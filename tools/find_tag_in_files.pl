$dir = shift @ARGV;
$lookIn = shift @ARGV;
$lookFor = shift @ARGV;
die "usage: directory extension_to_look_within tag_to_look_for_backwards\n" if (!defined($lookFor));

sub dodir
{
	local($dir) = @_;

	opendir(DIR, $dir) || die "opendir failed";
	local(@dir) = readdir(DIR);
	closedir(DIR);

	foreach (@dir)
	{
		next if ($_ eq '.');
		next if ($_ eq '..');
		local($path) = $dir . '/' . $_;

		if (-d $path)
		{
			&dodir($path);
		}
		else
		{
			push(@files, $path) if (/\.$lookIn$/)
		}
	}
}
&dodir($dir);

foreach $file (sort @files)
{
	open(STRINGS, 'strings ' . $file . ' |');
	while (<STRINGS>)
	{
		chomp;
		print $file . "\t" . $_ . "\n" if (/$lookFor$/);
	}
}
