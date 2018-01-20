# Syntax: perl getFileSizeInDirectoryTree.pl [-d] [directory [pathname_regex]]

use strict;
use File::Find;

my $debug = 0;
my $pathnameMustMatchRegex;

# Subroutine called by File::Find.
sub processFile
{
    print STDERR "testing [$File::Find::name]..." if $debug;

    if (!defined($pathnameMustMatchRegex) || $File::Find::name =~ m/$pathnameMustMatchRegex/)
    {
	print STDERR "matched, printing.\n" if $debug;

	my @fileStat      = stat;
	my $formattedName = $File::Find::name;
	$formattedName    =~ s!\\!/!g;
	print "$fileStat[7] $formattedName\n";
    }
    else
    {
	print STDERR "no match, skipping.\n" if $debug;
    }
}

# Check for help.
if (defined($ARGV[0]) && $ARGV[0] =~ m/-h/)
{
    print "Syntax: getFileSizeInDirectoryTree.pl [directory [pathname_regex]]\n";
    print "\tpathname_regex is a Perl-compatible regular expression, matches all if not specified.\n";
    exit 0;
}

# Check for debug.
if (defined($ARGV[0]) && $ARGV[0] =~ m/-d/)
{
    $debug = 1;
    print STDERR "\$debug = 1\n";
    shift @ARGV;
}

# Setup directory.
my @directories = ($ARGV[0]);
$directories[0] = '.' if !defined($directories[0]);
print STDERR "directories = [@directories]\n" if $debug;

# Setup regex.
$pathnameMustMatchRegex = $ARGV[1] if defined($ARGV[1]);
$pathnameMustMatchRegex =~ s/[\'\"]//g if defined($pathnameMustMatchRegex);
print STDERR "pathnameMustMatchRegex = [$pathnameMustMatchRegex]\n" if ($debug && defined($pathnameMustMatchRegex));

# Do the find.
File::Find::find(\&processFile, @directories);

# Done.
