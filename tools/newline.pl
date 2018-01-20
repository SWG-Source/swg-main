#!/usr/bin/perl

use strict;
use warnings;

sub usage()
{
	die "$0: usage <-d | -u> filename [filename ...]\n\t-d = to dos\n\t-u = to unix\n";
}

sub ToDos
{
	my $filename = shift(@_);
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

sub ToUnix
{
	my $filename = shift(@_);
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

usage() if (@ARGV < 2);

my $target = shift;
if ($target eq "-d")
{
	foreach (@ARGV)
	{
		ToDos($_);
	}
}
elsif ($target eq "-u")
{
	foreach (@ARGV)
	{
		ToUnix($_);
	}
}
else
{
	usage();
}
