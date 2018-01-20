while (<>)
{
	chomp;
	s/\d+\s+\d+\.\d+\s+\[\d+\]\s+//;
	s/\s+$//;
	
	$file = $_ if ($opening);
	$opening = /^opening/;

	if (defined($file) && /WARNING/)
	{
		print $file, "\n" if ($printed ne $file);
		$printed = $file;
		print "\t", $_, "\n" 
	}
}
