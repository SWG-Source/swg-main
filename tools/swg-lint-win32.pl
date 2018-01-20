#!/bin/perl

use strict;

use Cwd;
use Cwd 'chdir';
use File::Spec;

my $debug = 0;

# Find project.lnt file.
my @directories = File::Spec->splitdir(cwd());
my $projectFileName = "project.lnt";
my $projectFilePath = "";
my $foundProjectFile = 0;

while (!$foundProjectFile && (scalar(@directories) > 0))
{
	$projectFilePath = File::Spec->catfile(@directories, $projectFileName);
	$foundProjectFile = -f $projectFilePath;
	pop(@directories) if !$foundProjectFile;
}

die "failed to find file [$projectFileName] starting in directory [", cwd(), "], stopping" if !$foundProjectFile;
print "found project file: [$projectFilePath]\n" if $debug;

# Change directory to directory of project file.  Our lint setup expects the
# exe to run in the project file directory.
my $newWorkingDirectory = File::Spec->catdir(@directories);
print "new working directory: [$newWorkingDirectory]\n" if $debug;
chdir($newWorkingDirectory);

# Find the tools directory.
@directories = File::Spec->splitdir(cwd());
my $toolsDirName = "tools";
my $lintDirName = "lint";
my $toolsDirPath = "";
my $foundToolsDir = 0;

while (!$foundToolsDir && (scalar(@directories) > 0))
{
	$toolsDirPath = File::Spec->catdir((@directories, $toolsDirName, $lintDirName));
	$foundToolsDir = -d $toolsDirPath;
	pop(@directories);
}

die "failed to find tools directory [$toolsDirPath] starting in directory [", cwd(), "], stopping" if !$foundToolsDir;
print "found tools directory: [$toolsDirPath]\n" if $debug;

my $lintCommand = "lint-nt -u -i$ENV{LINT_HOME} -i$toolsDirPath $projectFilePath @ARGV";
print "lint command: [$lintCommand]\n" if $debug;
my $lintCommandResult = system($lintCommand);
my $exitCode = $lintCommandResult >> 8;

print "--- Lint DONE.\n";

exit($exitCode);
