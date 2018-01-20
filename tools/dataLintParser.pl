$what = shift;
while ($a = <>)
{
	if ($a =~ /^\s*\d+\s+Error:/)
	{
		print if (eval $what);
		$_ = "";
	}
	$_ .= $a;
}
print if (eval $what);
