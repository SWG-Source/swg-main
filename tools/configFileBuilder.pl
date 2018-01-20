while (<>)
{
	next if (s/^cfg: // == 0);
	chomp;
	($section, $value) = /\[(.*)\] (.*)/;
	$key{$section . "." . $value} = 1;
}

foreach (sort keys %key)
{
	($section, $value) =  split(/\./, $_, 2);
	if ($section ne $oldSection)
	{
		$oldSection = $section;
		print "[", $section, "]\n";
	}
	print "\t", $value, "\n";
}
