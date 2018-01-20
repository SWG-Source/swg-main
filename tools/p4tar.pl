#!/usr/bin/perl

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

# ======================================================================

$editIntegrates = 0;

# process command line arguments
while ($ARGV[0] =~ /^-/)
{
	$_ = shift;
	if (/^-h/)
	{
		print "p4tar [-c #] [-q] [-z] archive_name\n";
		print "-c = changelist #\n";
		print "-q = quiet, don't print summary\n";
		print "-z = compress\n";
		print "-i = convert integrates and branches to edits (UNSAFE)\n";
		exit 0;
	}
	elsif (/^-c/)
	{
		$changelist = "-c " . ($1 ? $1 : shift);
	}
	elsif (/^-z/)
	{
		$compress = "-z ";
	}
	elsif (/^-i/)
	{
		$editIntegrates = 1;
	}
	elsif (/^-q/)
	{
		$quiet = 1;
	}
	else
	{
		die "Unrecognized switch: $_\n";
	}
}

$tarname = shift;
die "no file name specified.  specify -h for help." if (!defined $tarname);
die "incorrect usage, nothing allowed after filename" if (@ARGV);

mkdir("p4tar.tmp", 0777) || die "Could not make temporary directory";

$countAdded   = 0;
$countEdited  = 0;
$countDeleted = 0;
$countSkipped = 0;

# get the list of opened files
open(P4OPENED, "p4 -ztag opened " . ($changelist or "") . " |");
open(ZERO, ">p4tar.tmp/000");
while (<P4OPENED>)
{
 	s/\w+$/edit/ if ($editIntegrates && (/^\.\.\. action integrate/));
 	s/\w+$/add/ if ($editIntegrates && (/^\.\.\. action branch/));
 
	print ZERO;

	s/\cJ$//;
	s/\cM$//;

	if (s/^... depotFile //)
	{
		push(@opened, $_);
	}
	elsif (s/^... clientFile //)
	{
		push(@client, $_);
	}
	elsif (s/^... action //)
	{
		if ($_ eq "add")
		{
			$countAdded += 1;
		}
		elsif ($_ eq "edit")
		{
			$countEdited += 1;
		}
		elsif ($_ eq "delete")
		{
			$countDeleted += 1 
		}
		else
		{
			$countSkipped += 1;
			pop(@opened);
			pop(@client);
		}
	}
}
close(ZERO);
close(P4OPENED);

# skip the TOC file
$filecount = 1;

# find out where those files are on the user's harddrive
open(FSTAT_RSP, ">p4tar.tmp/fstat");
print FSTAT_RSP join("\n", @opened), "\n";
close(FSTAT_RSP);

open(P4FSTAT, "p4 -x p4tar.tmp/fstat fstat |") || die "p4 FSTAT failed";
while (<P4FSTAT>)
{
 	s/\w+$/edit/ if ($editIntegrates && (/^\.\.\. action integrate/ || /^\.\.\. action branch/));

	s/\cJ$//;
	s/\cM$//;

	if (s/^... clientFile //)
	{
		$clientFile = $_;
	}
	elsif (s/^... action //)
	{
		$action = $_;
	}
	elsif ($_ eq "")
	{
		if ($action eq "add" || $action eq "edit")
		{
			CopyFile($clientFile, sprintf("p4tar.tmp/%03d", $filecount++)) ;
		}
	}
}
close(P4FSTAT);
unlink "p4tar.tmp/fstat";

# tar the files up
system("tar --force-local " . $compress . " -cf " . $tarname . " p4tar.tmp");

END
{
	# clean up
	$erase = 0;
	while ($erase < $filecount)
	{
		unlink(sprintf("p4tar.tmp/%03d", $erase));
		++$erase;
	}
	rmdir("p4tar.tmp");

	print "edited:  ", $countEdited, "   added: ", $countAdded, "   deleted: ", $countDeleted, "   skipped: ", $countSkipped, "\n" if (!$quiet);
}
