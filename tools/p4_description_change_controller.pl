#! /usr/bin/perl

use warnings;
use strict;
use Socket;

# ======================================================================
# Globals
# ======================================================================

my $perforceBox 	= "aus-perforce1.soe.sony.com";
my $port 		= "42845";
my $tmpfile		= "tmpchangelist.txt";

my $name = $0;
$name =~ s/^(.*)\\//;

my $user;
my $changelist;

# ======================================================================
# Subroutines
# ======================================================================

sub usage 
{
	print STDERR "\nUsage:\n";
	print STDERR "\t$name <changelist>\n\n";
	die "\n";
}

# ======================================================================
# Main
# ======================================================================

usage() if (@ARGV != 1);

$changelist = shift; 

# verify perforce user (p4 user -o)
# get user name
# verify password is set
my $passwd = 0;

open(P4, "p4 user -o |") || die "p4 user failed\n";
while(<P4>)
{
	$user = $1 if(/^User:\s+(\S+)/);
	$passwd = 1 if(/^Password:\s+\*+/);
}
close(P4);

die "Password is not set\n" if(!$passwd);

# get changelist
# verify changelist's user was the same
my @oldchange;
open(CHANGE, ">$tmpfile");
open(P4, "p4 change -o $changelist |") || die "error executing p4 change -o";
while(<P4>)
{
	push @oldchange, $_;
	print CHANGE $_;	
	
	if(/^User:\s+(\S+)/ && $user ne $1)
	{
		close(P4);
		close(CHANGE);
		unlink($tmpfile);
		die "Error: Cannot edit another user's changelist\n";
	}
}
close(P4);	
close(CHANGE);

# pop up editor and let user make changes to the text (P4EDITOR, EDITOR, VISUAL)
my $editor = "emacs";
$editor = "notepad.exe" if(exists $ENV{WINDIR});
$editor = $ENV{VISUAL} if(exists $ENV{VISUAL});
$editor = $ENV{EDITOR} if(exists $ENV{EDITOR});
$editor = $ENV{P4EDITOR} if(exists $ENV{P4EDITOR});

system("$editor $tmpfile");

# verify only the description text has changed
my $current = "";
my $buffer = "";
open(CHANGE, "<$tmpfile");
while(<CHANGE>)
{
	my $elem = shift @oldchange;

	$current = $1 if(/^(\w+):/);
	
	if(!defined $elem || $elem ne $_)
	{
		close(CHANGE);
		unlink($tmpfile);
		die "Error: Can only change description of changelist\n";
	}
	
	if($current eq "Description")
	{
		$buffer = "Description:\n";
		
		while(<CHANGE>)
		{
			$buffer .= $_;

			if(/^(\w+):/)
			{
				$current = $1;
				last;
			}
		}
		while(@oldchange)
		{
			my $tmp = shift @oldchange;
			if($tmp =~ /^(\w+):/)
			{
				$current = $1;
				last;
			}
		}
	}
}
close(CHANGE);
die "Error: Can only change description of changelist\n" if(@oldchange);

# send the data to the daemon
socket(PERFORCE, PF_INET, SOCK_STREAM, getprotobyname('tcp')) || die "socket failed\n";
{
	my $destination = inet_aton($perforceBox) || die "inet_aton failed\n";
	my $paddr = sockaddr_in($port, $destination);
	connect(PERFORCE, $paddr) || die "connect failed\n";

	# unbuffer the socket
	my $oldSelect = select(PERFORCE);
	$| = 1;
	select($oldSelect);

	# put the socket into binary mode
	binmode PERFORCE;
}

print PERFORCE pack("N", length "$user $changelist");
print PERFORCE "$user $changelist";

print PERFORCE pack("N", length $buffer);
print PERFORCE $buffer;

die "Error getting response from Perforce server\n" if(read(PERFORCE, $buffer, 1) != 1);

if($buffer eq "P")
{
	print "Successfully updated changelist\n";
}
else
{
	print "Error updating changelist\n";
}

close(PERFORCE);
unlink($tmpfile);
