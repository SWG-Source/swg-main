$dir = shift @ARGV;
die "usage: directory\n" if (!defined($dir));

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

		$mirror = $path;
		$mirror =~ s#/#.new/#;

		if (-d $path)
		{
			mkdir $mirror;
			&dodir($path);
		}
		else
		{
			open(FILE, ">" . $mirror);
			print FILE $path, "\n";
			close(FILE);
		}
	}
}
mkdir $dir . ".new";
&dodir($dir);
