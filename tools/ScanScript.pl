#! /usr/bin/perl
# ======================================================================
# ======================================================================

use strict;
use warnings;

# ======================================================================
# Globals
# ======================================================================

my %str_to_tags;
my %str_to_files;
my $tmprsp = "a.rsp";

my $name = $0;
$name =~ s/^(.*)\\//;

# ======================================================================
# Subroutines
# ======================================================================

sub usage
{
	die "\nTool used to scan through conversation scripts and verify that all .stf files have the appropriate tags\n\n".
		"\tUsage\n".
		"\t\t$name <script file>\n\n";
}

sub testfile
{
	#p4 fstat //depot/swg/current/data/.../string/en/bartender.stf
	#echo c:\work\swg\current\data\sku.0\sys.server\built\game\string\en\bartender.stf > a.rsp
	#WordCountTool.exe -d a.rsp

	my $file = shift @_;
	my $path = $file;
	$path =~ s/\./\//g;
	
	my @files;

	open(P4, "p4 fstat //depot/swg/current/data/.../string/en/${path}.stf | ") or die "Cannot open file: $path\n";
	while(<P4>)
	{
		push @files, $1 if(/^\.\.\. clientFile (.+)$/);
	}
	close(P4);
	
	foreach my $elem (@files)
	{
		print "\t$elem:\n";
		
		my %filetags;
		system("echo $elem > $tmprsp");
		open(WORDCOUNT, "WordCountTool.exe -d $tmprsp | ");
		while(<WORDCOUNT>)
		{
			$filetags{"\"$1\""} = 0 if(/^\t(\S+)\t/);
		}
		close(WORDCOUNT);
		
		my $ref = $str_to_tags{$file};
		my $missing = 0;

		foreach my $tag (sort keys %$ref)
		{
			if(!exists $filetags{$tag})
			{
				print "\t\tis missing $tag\n";
				$missing = 1;
			}
		}

		$missing ? print "\n" : print "\t\tNone missing\n\n";
		
	}
	unlink($tmprsp);
}

# ======================================================================
# Main
# ======================================================================

&usage() if(@ARGV != 1); 

my $scriptfile = shift;

print "Scanning script file...\n";

open(SCRIPT, "<$scriptfile");

while(<SCRIPT>)
{
	$str_to_files{$2} = $3 if(/(const)?\s+string\s+([A-Za-z_]+)\s+=\s+"([A-Za-z_\.]+)"/);
	#if(/(new)?\s+string_id\s*\(\s*([A-Za-z_]+)\s*,\s*"([A-Za-z_]+)"\s*\)/)
	if(/(new)?\s+string_id\s*\(\s*([A-Za-z_]+)\s*,\s*(.+)\s*\)/)
	{
		my $string = $2;
		my $tagline = $3;
	
		$str_to_tags{$str_to_files{$string}} = {} if(!exists $str_to_tags{$str_to_files{$string}});
		
		if($tagline =~ s/"(.+)"\s*\+\s*rand\s*\(\s*(\d)+\s*,\s*(\d)+\s*\)//)
		{
			my $tagline = $1;
			my $num = $2;
			my $end = $3;
			
			while($num <= $end)
			{
				$str_to_tags{$str_to_files{$string}}->{"\"${tagline}$num\""} = 0;	
			
				++$num;
			}
		}
		else
		{
			$tagline =~ s/\)//g;
			$str_to_tags{$str_to_files{$string}}->{$tagline} = 0;	
		}
	}
}

close(SCRIPT);

foreach my $str (sort keys %str_to_tags)
{
	my $hash_ref = $str_to_tags{$str};
	print "\nFile: '$str' needs to contain\n";
	foreach my $tag (sort keys %$hash_ref)
	{
		print "\t$tag\n";
	}
}

print "\nScanning for missing elements of script files...\n";

foreach my $filename (sort keys %str_to_tags)
{
	testfile($filename);	
}



