# Perl script to sum up the size of files.

$sum = 0;
$entries = 0;

while (<>)
{
	if (/^TF.+size=([0-9]+)\]$/)
	{
		$sum += $1;
		$entries++;
	}
}

print "Sum of size lines: $sum (from $entries contributing entries)\n";
