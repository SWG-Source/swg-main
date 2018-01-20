# ================================================================================
#
# checkCreatureStrings.pl
# Copyright 2006, Sony Online Entertainment LLC
#
# ================================================================================

use Cwd;

# --------------------------------------------------------------------------------

die "usage: $0\n\t Checks that all creatures.tab creature names are localized. Outputs missing creature names." if (@ARGV);
die "Must be run within a swg directory!" if (getcwd() !~ m!(.*/swg/\w+/)!);
my $rootPath = $1;

my $creaturesStringFile = "data/sku.0/sys.shared/built/game/string/en/mob/creature_names.stf";
my $creaturesTabFile = "dsrc/sku.0/sys.server/compiled/game/datatables/mob/creatures.tab";
my $localizationToolCon = "../all/tools/all/win32/LocalizationToolCon_r.exe";

# --------------------------------------------------------------------------------

open(CS, "$rootPath$localizationToolCon $rootPath$creaturesStringFile -list |") || die "$!";
while (<CS>)
{
	split;
	$creaturesString{$_[0]} = 1;
}
close(CS);

open(CT, "$rootPath$creaturesTabFile") || die "$!";
<CT>; <CT>; # skip column header name & type
while (<CT>)
{
	split;
	if (!$creaturesString{$_[0]})
	{
		print "$_[0]\n";
		++$missingStringCount;
	}
}
close(CT);

if ($missingStringCount)
{
	print STDERR "\nFAILURE! Missing $missingStringCount creature name strings!\n";
}
else
{
	print STERR "\nSUCCESS! No missing creature strings!\n";
}

exit $missingStringCount;

# ================================================================================
