#!/usr/bin/perl

use strict;
use warnings;

# ----------------------------------------------------------------------
# This script is used to contain all custom build steps. 
# Having this logic in here allows us to make global changes 
# to the custom builds with ease as well as add error checking 
# in one location.
# ----------------------------------------------------------------------

my $thisScript = $0;
$thisScript =~ s%^(.*[\\\/])%%;

usage() if (!@ARGV);

# ----------------------------------------------------------------------

sub usage
{
	my $message = q@
	Usage: 
		$thisScript <command> <command arguments>
		
	Valid commands: 
		moc <InputPath> <TargetDir> <InputName>
		ui <InputPath> <TargetDir> <InputName> <BuildType>
	@;
	
	die "$message\n";
}

sub processMoc
{
	# ..\..\..\..\..\..\external\3rd\library\qt\3.3.4\bin\moc -i $(InputPath) -o $(TargetDir)\$(InputName).moc
	die "moc takes 3 arguments: <InputPath> <TargetDir> <InputName>\n" if (@_ != 3);
	
	my $inputPath = shift;	
	my $targetDir = shift;
	my $inputName = shift;
	
	print "Executing moc for $inputPath, $targetDir, $inputName\n";
	
	print "\tInput path ($inputPath) does not exist\n" if (!-f $inputPath);
	print "\tTarget dir ($targetDir) does not exist\n" if (!-d $targetDir);
	print "\tOutput file ($targetDir\\${inputName}.moc) does not exist\n" if (!-f "$targetDir\\${inputName}.moc");
	
	print "Executing ..\\..\\..\\..\\..\\..\\external\\3rd\\library\\qt\\3.3.4\\bin\\moc -i $inputPath -o $targetDir\\${inputName}.moc\n";
	die "Failed while executing command for moc!\n" if (system ("..\\..\\..\\..\\..\\..\\external\\3rd\\library\\qt\\3.3.4\\bin\\moc -i $inputPath -o $targetDir\\${inputName}.moc"));
}

sub processUi
{
	# ..\..\..\..\..\..\external\3rd\library\qt\3.3.4\bin\uic -o $(TargetDir)\$(InputName).h $(InputPath) && 
	# ..\..\..\..\..\..\external\3rd\library\qt\3.3.4\bin\uic -o $(TargetDir)\$(InputName)_o.cpp -impl $(TargetDir)\$(InputName).h $(InputPath) && 
	# ..\..\..\..\..\..\external\3rd\library\qt\3.3.4\bin\moc  $(TargetDir)\$(InputName).h >> $(TargetDir)\$(InputName)_o.cpp
	die "ui takes 4 arguments: <InputPath> <TargetDir> <InputName> <BuildType>\n" if (@_ != 4);

	my $inputPath = shift;
	my $targetDir = shift;
	my $inputName = shift;
	my $buildType = shift;

	print "Executing ui for $inputPath, $targetDir, $inputName, $buildType\n";

	$buildType = substr(lcfirst $buildType, 0, 1);
	
	print "\tInput path ($inputPath) does not exist\n" if (!-f $inputPath);
	print "\tTarget dir ($targetDir) does not exist\n" if (!-d $targetDir);
	print "\tOutput header file ($targetDir\\${inputName}.h) does not exist\n" if (!-f "$targetDir\\${inputName}.h");
	print "\tOutput cpp file ($targetDir\\${inputName}_${buildType}.cpp) does not exist\n" if (!-f "$targetDir\\${inputName}_${buildType}.cpp");

	print "Executing ..\\..\\..\\..\\..\\..\\external\\3rd\\library\\qt\\3.3.4\\bin\\uic -o $targetDir\\$inputName.h $inputPath\n";
	die "Failed while executing command 1 for ui!\n" if (system ("..\\..\\..\\..\\..\\..\\external\\3rd\\library\\qt\\3.3.4\\bin\\uic -o $targetDir\\$inputName.h $inputPath"));

	print "\tOutput header file ($targetDir\\${inputName}.h) does not exist\n" if (!-f "$targetDir\\${inputName}.h");
	print "\tOutput cpp file ($targetDir\\${inputName}_${buildType}.cpp) does not exist\n" if (!-f "$targetDir\\${inputName}_${buildType}.cpp");

	print "Executing ..\\..\\..\\..\\..\\..\\external\\3rd\\library\\qt\\3.3.4\\bin\\uic -o $targetDir\\${inputName}_${buildType}.cpp -impl $targetDir\\${inputName}.h $inputPath\n";
	die "Failed while executing command 2 for ui!\n" if (system ("..\\..\\..\\..\\..\\..\\external\\3rd\\library\\qt\\3.3.4\\bin\\uic -o $targetDir\\${inputName}_${buildType}.cpp -impl $targetDir\\${inputName}.h $inputPath"));

	print "\tOutput header file ($targetDir\\${inputName}.h) does not exist\n" if (!-f "$targetDir\\${inputName}.h");
	print "\tOutput cpp file ($targetDir\\${inputName}_${buildType}.cpp) does not exist\n" if (!-f "$targetDir\\${inputName}_${buildType}.cpp");

	print "Executing ..\\..\\..\\..\\..\\..\\external\\3rd\\library\\qt\\3.3.4\\bin\\moc  $targetDir\\${inputName}.h >> $targetDir\\${inputName}_${buildType}.cpp\n";
	die "Failed while executing command 3 for ui!\n" if (system ("..\\..\\..\\..\\..\\..\\external\\3rd\\library\\qt\\3.3.4\\bin\\moc  $targetDir\\${inputName}.h >> $targetDir\\${inputName}_${buildType}.cpp"));
}

# ----------------------------------------------------------------------

my $command = shift;

if ($command eq "moc")
{
	processMoc(@ARGV);
}
elsif ($command eq "ui")
{
	processUi(@ARGV);
}
else 
{
	print STDERR "Unknown command: $command\n";
	usage();
}