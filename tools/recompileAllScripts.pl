#! /usr/bin/perl

use strict;
use warnings;

# =====================================================================

sub fatal
{
	my $message = $_[0];
	die $message;
}

sub perforceGetOpenFiles
{
	my @files;
	open(P4, "p4 -ztag opened -c default |");

		while (<P4>)
		{
			chomp;
			push (@files, $_) if (s/^\.\.\. depotFile //);
		}

	close(P4);

	return @files;
}

sub perforceSubmit
{
	# find out what files are open
	my @files = perforceGetOpenFiles();

	my $tmpfile = "submit.tmp";
	
	# submit all the open files
	open(TMP, ">" . $tmpfile);

		print TMP "Change:\tnew\n";
		print TMP "\nDescription:\n";

		foreach (@_)
		{
			print TMP "\t", $_, "\n";
		}
		
		print TMP "\nFiles:\n";
		foreach (@files)
		{
			print TMP "\t", $_, "\n";
		}

	close(TMP);

	my $result = system("p4 submit -i < $tmpfile");
	fatal "p4 submit failed" if ($result != 0);
	unlink($tmpfile);
}

sub perforceWhere
{
	# find out where a perforce file resides on the local machine
	my $result;
	{
		open(P4, "p4 where $_[0] |");
			$_ = <P4>;
			chomp;
			my @where = split;
			$result = $where[2];
		close(P4);
	}

	return $result;
}

sub findFiles
{
	local $_;

	my @paths = @_;
	my @files = ();
	
	while (@paths)
	{
		my $path = shift(@paths);
		opendir(DIR, $path) || die "could not open dir $path";
			while ($_ = readdir(DIR))
			{
				next if ($_ eq "." || $_ eq "..");

				my $new = $path . "/" . $_;
				if (-d $new)
				{
					push(@paths, $new);
				}
				else
				{
					push (@files, $new);
				}
			}
		closedir(DIR);
	}

	return @files;
}

# =====================================================================

die "uasge: perl recompileAllScripts.pl branch\n" if (@ARGV != 1);
my $branch = shift;

my $depotScriptBaseDir       = "//depot/swg/$branch/dsrc/sku.0/sys.server/compiled/game/script";
my $localScriptBaseDir       = perforceWhere($depotScriptBaseDir);
my $depotClassBaseDir        = "//depot/swg/$branch/data/sku.0/sys.server/compiled/game/script";
my $localClassBaseDir        = perforceWhere($depotClassBaseDir);
my $depotJavaSourceDir       = "//depot/swg/$branch/dsrc/sku.0/sys.server/compiled/game";
my $localJavaSourceDir       = perforceWhere($depotJavaSourceDir);
my $depotJavaDestinationDir  = "//depot/swg/$branch/data/sku.0/sys.server/compiled/game";
my $localJavaDestinationDir  = perforceWhere($depotJavaDestinationDir);
my $pythonPreprocessor       = perforceWhere("//depot/swg/$branch/exe/shared/script_prep.py");

my $perforceEditClassFiles = 1;
my $removeClassFiles = 1;
my $removeJavaFilesBefore = 1;
my $removeJavaFilesAfter = 1;
my $preprocess = 1;
my $preprocessExisting = 0;
my $batchPreprocess = 1;
my $verifyJavaFilesFromScriptFiles = 1;
my $compile = 1;
my $batchCompile = 1;
my $verifyClassFilesFromJavaFiles = 1;
my $updatePerforce = 1;
my $submitToPerforce = 0;

# =====================================================================

print STDERR "Running on branch $branch\n";

if ($perforceEditClassFiles)
{
	print STDERR "Opening all .class files for edit...\n";
	system("p4 edit $depotClassBaseDir/... > /dev/null") == 0 || die "could not edit class files\n";
	system("p4 lock $depotClassBaseDir/... > /dev/null") == 0 || die "could not lock class files\n";
}

if ($removeClassFiles)
{
	print STDERR "Deleting all .class files...\n";
	foreach (findFiles($localClassBaseDir))
	{
		die "file does not end in .class" if (!/\.class$/);
		unlink($_) || die "could not remove file $_\n";
	}
}

if ($removeJavaFilesBefore)
{
	print STDERR "Removing temporary java files...\n";
	my @paths = ();
	opendir(DIR, $localScriptBaseDir) || die "could not open dir $localScriptBaseDir";
	while ($_ = readdir(DIR))
	{
		next if ($_ eq "." || $_ eq "..");
		my $new = $localScriptBaseDir . "/" . $_;
		push(@paths, $new) if (-d $new);
	}
	close(DIR);
	foreach my $java (grep(/\.java$/, findFiles(@paths)))
	{
		unlink($java) || die "could not remove temporary java file $java\n";
	}
}

if ($preprocess || $verifyJavaFilesFromScriptFiles)
{
	my @files = grep(/\.script(lib)?$/, findFiles($localScriptBaseDir));

	if ($preprocess)
	{
		my $start = time;

		unlink("pythonPreprocessorStdout.log");
		unlink("pythonPreprocessorStderr.log");

		if ($batchPreprocess)
		{
			print STDERR "Batch preprocessing all scripts...\n";
			open(PYTHON, "| xargs --max-procs=2 python2 $pythonPreprocessor -nocompile >> pythonPreprocessorStdout.log 2>> pythonPreprocessorStderr.log");
				print PYTHON join("\n", @files), "\n";
			close(PYTHON);
		}
		else
		{
			print STDERR "Single preprocessing all scripts...\n";

			my $files = scalar(@files);
			my $count = 1;

			foreach my $script (@files)
			{
				print STDERR sprintf("%3d", (($count * 100) / $files)), "% $count/$files  $script\n";

				my $java = $script;
				$java =~ s/\.script(lib)?/\.java/;
				if ($preprocessExisting || !-e $java)
				{
					system("python2 $pythonPreprocessor -nocompile $script >> pythonPreprocessorStdout.log 2>> pythonPreprocessorStderr.log");
				}
				$count += 1;
			}
		}

		print STDERR "preprocessing: ", time - $start, "s\n";
	}

	die "script files failed preprocessing\n" if (-s "pythonPreprocessorStderr.log");

	if ($verifyJavaFilesFromScriptFiles)
	{
		my $die = 0;
		foreach my $script (@files)
		{
			my $java = $script;
			$java =~ s/\.script(lib)?/\.java/;
			if (!-e $java)
			{
				print STDERR "could not find java file $java from script file $script\n";
				$die = 1;
			}
		}
		die "missing java files\n" if ($die);
	}
}

if ($compile || $verifyClassFilesFromJavaFiles)
{
	my @files = grep(/\.java$/, findFiles($localScriptBaseDir));
	my $files = scalar(@files);

	if ($compile)
	{
		my $start = time;
		unlink("javac.log");

		if ($batchCompile)
		{
			print STDERR "Batch java compiling all the scripts...\n";

			open(JAVAC, "| xargs javac -classpath $localJavaDestinationDir -d $localJavaDestinationDir -sourcepath $localJavaSourceDir -g -deprecation >> javac.log 2>&1");
				print JAVAC join("\n", @files), "\n";
			close(JAVAC);
		}
		else
		{
			print STDERR "Single java compiling all the scripts...\n";
			my $count = 1;	
			my $errors = 0;

			foreach my $java (@files)
			{
				print STDERR sprintf("%3d", (($count * 100) / $files)), "% $count/$files $errors $java\n";
				$errors += 1 if (system("javac -classpath $localJavaDestinationDir -d $localJavaDestinationDir -sourcepath $localJavaSourceDir -g -deprecation $java >> javac.log 2>&1") != 0);
				$count += 1;
			}
		}

		print STDERR "compile: ", time - $start, "s\n";
	}

	die "java files failed compilation\n" if (-s "javac.log");

	if ($verifyClassFilesFromJavaFiles)
	{
		my $die = 0;
		foreach my $java (@files)
		{
			my $class = $java;
			$class =~ s/\.java/\.class/;
			$class =~ s/$localScriptBaseDir/$localClassBaseDir/;
			if (!-e $class)
			{
				print STDERR  "could not find class file $class for java file $java\n";
				$die = 1;
			}
		}
		die "missing class files\n" if ($die);
	}
}

if ($removeJavaFilesAfter)
{
	print STDERR "Removing temporary java files...\n";
	my @paths = ();
	opendir(DIR, $localScriptBaseDir) || die "could not open dir $localScriptBaseDir";
		while ($_ = readdir(DIR))
		{
			next if ($_ eq "." || $_ eq "..");
			my $new = $localScriptBaseDir . "/" . $_;
			push(@paths, $new) if (-d $new);
		}
	close(DIR);
	foreach my $java (grep(/\.java$/, findFiles(@paths)))
	{
		unlink($java) || die "could not remove temporary java file $java\n";
	}
}

if ($updatePerforce)
{
	print STDERR "Searching for class files to delete...\n";
	my @openedFiles = perforceGetOpenFiles();
	my @deleted;
	foreach (grep(/\.class$/, @openedFiles))
	{
		s/$depotClassBaseDir/$localClassBaseDir/;
		push (@deleted, $_) if (! -e $_);
	}

	if (@deleted)
	{
		print join("\n", @deleted), "\n";

		print STDERR "Deleting old .class files...\n";
		open(P4, "| p4 -x - revert > /dev/null");
		print P4 join("\n", @deleted), "\n";
		close(P4);

		open(P4, "| p4 -x - delete > /dev/null");
		print P4 join("\n", @deleted), "\n";
		close(P4);
	}

	print STDERR "Searching for class files to add...\n";
	open(P4, "| p4 -x - add 2> /dev/null > /dev/null");
		foreach (findFiles($localClassBaseDir))
		{
			die "file does not end in .class" if (!/\.class$/);
			print $_, "\n";
			print P4 $_, "\n";
		}
	close(P4);

	print STDERR "Reverting unchanged files...\n";
	system("p4 revert -a > /dev/null");

	if ($submitToPerforce)
	{
		print STDERR "Submitting to perforce...\n";
		perforceSubmit("[automated]", "- Recompile all scripts");
	}
}

exit 0;
