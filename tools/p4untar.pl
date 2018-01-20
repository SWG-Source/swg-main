#!/usr/bin/perl

# ----------------------------------------------------------------------

sub ToDos
{
	local($filename) = shift(@_);
	local(*FILE);

	open(FILE, $filename);
	binmode(FILE);
	local($/);
	local($_);
	$_ = <FILE>;
	close(FILE);
	
	s/\cM\cJ/\cJ/g;
	s/\cM/\cJ/g;
	s/\cJ/\cM\cJ/g;

	open(FILE, ">" . $filename);
	binmode(FILE);
	print FILE;
	close(FILE);
}

# ----------------------------------------------------------------------

sub ToUnix
{
	local($filename) = shift(@_);
	local(*FILE);

	open(FILE, $filename);
	binmode(FILE);
	local($/);
	local($_) = <FILE>;
	close(FILE);
	
	s/\cM\cJ/\cJ/g;
	s/\cM/\cJ/g;

	open(FILE, ">" . $filename);
	binmode(FILE);
	print FILE;
	close(FILE);
}

# ----------------------------------------------------------------------

sub CopyFile
{
	local($from) = shift(@_);
	local($to) = shift(@_);
	local(*FROM);
	local(*TO);
	local($buf);

	# open the files in binary mode
	open(FROM, $from);
	binmode(FROM);
	open(TO, ">" . $to);
	binmode(TO);

	# copy the data
	while (read(FROM, $buf, 16384))
	{
		print TO $buf;
	}

	# close the files
	close(FROM);
	close(TO);
}

# ----------------------------------------------------------------------

sub CompareFiles
{
	local($first) = shift(@_);
	local($second) = shift(@_);
	local(*FIRST);
	local(*SECOND);
	local($a);
	local($b);

	# open the files in binary mode
	open(FIRST, $first);
	binmode(FIRST);
	open(SECOND, $second);
	binmode(SECOND);

	# copy the data
	while (read(FIRST, $a, 16384))
	{
		read(SECOND, $b, 16384);
		if ($a ne $b)
		{
			close(FIRST);
			close(SECOND);
			return 0;
		}
	}

	# make sure the second file isn't just longer than the first
	read(SECOND, $b, 16384);

	# close the files
	close(FIRST);
	close(SECOND);

	return 0 if ($b ne "");
	1;
}

# ----------------------------------------------------------------------

sub PipeIn
{
	local($command) = shift(@_);
	local(*PIPE);
	
	open(PIPE, "|" . $command);
	print PIPE join("\n", @_), "\n";
	close(PIPE);
}

# ----------------------------------------------------------------------

$extract = 1;
$skipped = 0;
$quiet   = 0;
@p4add = ();
@p4edit = ();
@p4delete = ();

# process command line arguments
while ($ARGV[0] =~ /^-/)
{
	$_ = shift;
	if ($_ eq "-h")
	{
		print "p4untar [-debug] [-revert] [-z] archive_name\n";
		print "-revert = completely revert all changes in this archive\n";
		print "          this will DELETE added files.\n";
		print "-c #    = changelist\n";
		print "-ld     = convert to dos style line-ends\n";
		print "-lu     = convert to unix style line-ends\n";
		print "-ln     = do not do any line-end conversions\n";
		print "-e      = do not extract files, just do edits and adds\n";
		print "-z      = uncompress\n";
		print "-d      = do not extract files with identical contents\n";
		print "-diff   = diff files in archive against client, extract nothing\n";
		print "-unpack = just extract all files into p4tar_unpack/\n";
		print "-q      = quiet - emit no output\n";
		exit 0;
	}
	elsif ($_ eq "-z")
	{
		$compress = "-z ";
	}
	elsif ($_ eq "-d")
	{
		$diff = 1;
	}
	elsif ($_ eq "-e")
	{
		$extract = 0;
	}
	elsif ($_ eq "-c")
	{
		$changelist = shift;
		die "no changelist specified.  specify -h for help.	" if (!defined $changelist);
		$changelist = " -c " . $changelist;
	}
	elsif ($_ eq "-lu")
	{
		$unix = 1;
	}
	elsif ($_ eq "-ld")
	{
		$dos = 1;
	}
	elsif ($_ eq "-ln")
	{
		$none = 1;
	}
	elsif ($_ eq "-revert")
	{
		$revert = 1;
	}
	elsif ($_ eq "-diff")
	{
		$diffOnly = 1;
	}
	elsif ($_ eq "-unpack")
	{
		$unpackOnly = 1;
	}
	elsif ($_ eq "-q")
	{
		$quiet = 1;
	}
	else
	{
		die "Unrecognized switch: $_\n";
	}
}

$tarname = shift;
die "no file name specified.  specify -h for help.	" if (!defined $tarname);
die "incorrect usage, nothing allowed after filename" if (@ARGV);

chdir "p4tar.tmp" && die "p4tar.tmp directory already exsits";

# extract the files
system("tar --force-local " . $compress . " -mxf " . $tarname) == 0 || die "could not spawn tar";

# attempt to figure out if we have unix or dos style newlines
if (!$unix && !$dos && !$none)
{
	open(UNAME, "uname|");
	$uname = <UNAME>;
	close(UNAME);
	if ($uname =~ /^linux/i)
	{
		$unix = 1;
	}
	else
	{
		$dos = 1;
	}
}

open(P4OPENED, "p4tar.tmp/000");
$filecount = 1;
while (<P4OPENED>)
{
	s/\cJ$//;
	s/\cM$//;

	die "invalid contents data detected.  perhaps this is an old-style p4tar?\n$_\n" if ($_ ne "" && !/^\.\.\./);

	if (s/^... depotFile //)
	{
		$filename = $_;
	}
	elsif (s/^... action //)
	{
		$action = $_;
	}
	elsif (s/^... rev //)
	{
		$version = $_;
	}
	elsif (s/^... type //)
	{
		$type = $_;
	}
	elsif ($_ eq "")
	{
		if ($action eq "delete")
		{
			push(@p4sync, $filename . "#" . $version);
			push(@p4delete, $filename);
		}
		elsif ($action eq "edit")
		{
			push(@p4sync, $filename . "#" . $version);
			push(@p4edit, $filename);
			$copy{$filename} = $filecount;
			ToUnix(sprintf("p4tar.tmp/%03d", $filecount)) if ($unix && $type eq "text");
			ToDos(sprintf("p4tar.tmp/%03d", $filecount)) if ($dos && $type eq "text");
			++$filecount;
		}
		elsif ($action eq "add")
		{
			$p4add{$filename} = $type;
			$types{$type} = 1;
			push(@p4add, $filename);
			$copy{$filename} = $filecount;
			ToUnix(sprintf("p4tar.tmp/%03d", $filecount)) if ($unix && $type eq "text");
			ToDos(sprintf("p4tar.tmp/%03d", $filecount)) if ($dos && $type eq "text");
			++$filecount;
		}
		else
		{
			print STDERR "skipping: " .$_ . "\n";
			++$skipped;
		}
	}
}
close(P4OPENED);

if ($revert)
{
	if (@p4add)
	{
		# delete all the added files
		open(FSTAT, ">p4tar.tmp/fstat");
		print FSTAT join("\n", @p4add), "\n";
		close(FSTAT);

		open(DEL, "p4 -x p4tar.tmp/fstat fstat |");
		while (<DEL>)
		{
			chomp;
			unlink($_) if (s/... clientFile //);
		}

		close(DEL);
		unlink("p4tar.tmp/fstat");
	}

	# revert deleted, edited, and added files files
	PipeIn("p4 -x - revert", @p4delete, @p4edit, @p4add); 
}
elsif ($unpackOnly)
{
	mkdir("p4tar_unpack");
	foreach (keys %copy)
	{
		$filename = $_;
		$filename =~ s/^.*[\/\\]//;
		CopyFile(sprintf("p4tar.tmp/%03d", $copy{$_}), "p4tar_unpack/$filename");
	}
}
else
{
	# sync the files to the appropriate version to avoid losing changes
	PipeIn("p4 -x - sync", @p4sync) if (!$diffOnly && @p4sync);

	# delete files as necessary 
	if (!$diffOnly && @p4delete)
	{
		PipeIn("p4 -x - revert" . $changelist, @p4delete);
		PipeIn("p4 -x - delete" . $changelist, @p4delete);
	}

	# edit files as necessary 
	PipeIn("p4 -x - edit" . $changelist, @p4edit) if (!$diffOnly && @p4edit);

	# add files as necessary
	if (!$diffOnly && @p4add)
	{
		foreach $type (sort keys %types)
		{
			PipeIn("p4 -x - add -t $type" . $changelist, grep($p4add{$_} eq $type, @p4add));
		}
	}
	
	# copy all the files here
	if ($extract && keys %copy)
	{
		open(FSTAT, ">p4tar.tmp/fstat");
		print FSTAT join("\n", keys %copy), "\n";
		close(FSTAT);
				
		# lookup the destination file locations
		open(COPY, "p4 -x p4tar.tmp/fstat fstat |");
		$diskFile = "";
		while (<COPY>)
		{
			chomp;

			if (s/... depotFile //)
			{
				$depotFile = $_;
			}
			elsif (s/... clientFile //)
			{
				$diskFile = $_;
			}
			elsif ($_ eq "")
			{
				next if ($diskFile eq "");

				# convert any backslashes to forward slashes
				$diskFile =~ s!\\!/!g;

				# get the directories to make
				@dirs = split('/', $diskFile);
				pop @dirs;
				undef @made;
				while (@dirs)
				{
					push(@made, shift @dirs);
					$mkdir = join('/', @made);
					mkdir($mkdir, 0777);
				}

				$tempFile = sprintf("p4tar.tmp/%03d", $copy{$depotFile});

				if ($diffOnly)
				{
					print "diff \"$diskFile\" vs. \"$tempFile\"\n";
					system("diff \"$diskFile\" \"$tempFile\"");
				}
				else
				{
					if (!$diff || !CompareFiles($tempFile, $diskFile))
					{
						print "replacing: " . $diskFile . "\n" if ($diff);
						CopyFile($tempFile, $diskFile);
					}
					else
					{
						print "unchanged: " . $diskFile . "\n" if ($diff);
					}
				}
				$diskFile = "";
			}
		}

		unlink("p4tar.tmp/fstat");
		close(COPY);
	}

	# print summary
	print "edited:	" . @p4edit . "	  added: " . @p4add . "	  deleted: " . @p4delete . "   skipped: " . $skipped . "\n" if (!$diffOnly && !$quiet);
}

# clean up
$erase = 0;
while ($erase < $filecount)
{
	unlink(sprintf("p4tar.tmp/%03d", $erase));
	++$erase;
}
rmdir("p4tar.tmp");
