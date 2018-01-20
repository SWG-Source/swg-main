my @vcprojs;

print "Getting list\n";
open (FIND, "c:/cygwin/bin/find ../src -name \"settings.rsp\" |");
while (<FIND>)
{
	chomp;
	s/\/(\w*)\/build\/win32\/settings\.rsp/\/$1\/build\/win32\/$1\.vcproj/g;
	push @vcprojs, $_;
}
close (FIND);

print "Editing\n";
open (P4, "| p4 -x - edit");
print P4 join("\n", @vcprojs);
close (P4);

my @errorList;
foreach (@vcprojs)
{
	print "Building $_\n";
	
	if (system ("buildVcproj.pl $_"))
	{
		push @errorList, $_;
	}
}

print "Reverting\n";
open (P4, "| p4 -x - revert -a");
print P4 join("\n", @vcprojs);
close (P4);

if (@errorList)
{
	die "ERROR!: Failed to build to following projects:\n", (join "\n", @errorList), "\n";
}