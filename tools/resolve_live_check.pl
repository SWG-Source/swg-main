while (<>)
{
	chomp;
	s/Accept\(a\) Edit\(e\) Diff\(d\) Merge \(m\) Skip\(s\) Help\(\?\) at: //;
	if (/[1-9][0-9]* yours/ || /[1-9][0-9]* conflicting/)
	{
		print $last, "\n", $_, "\n", "\n";
	}
	$last = $_;
}
