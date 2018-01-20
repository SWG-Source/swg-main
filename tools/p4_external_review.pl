#!/usr/bin/perl
# ======================================================================
# ======================================================================

use Net::SMTP;

# Perfreview
#
#### What Does perfreview Do?
#
# perfreview - A change review 'daemon' for Perforce changes.
#              Sends email to user when files they've subscribed to
#              change in the depot.
#
#### How Does it Work?
#
# Uses 'p4 review' to dish up changes for review,
# 'p4 reviews' to find out who should review the changes,
# 'p4 describe' to fill out mail to send to users, and
# Net::SMTP to deliver the mail.
#
#### Instructions: Please read before running!
#
# 1)  There is no step 1.
#
# 2)  This script can be installed in any directory, although
#     we recommend installing it in the same directory as
#     the p4d server.
#
# 3)  If necessary, change the top line of this script to point to the
#     location of your local Perl executable.  The Perl version should
#     be 4 or higher.
#
# 4)  Change the values of the following variables as desired:
#
#     $once says process the queue once instead of every minute;
#	  This is good for being called by cron(8).
#
#     $sleepTime is the number of seconds to wait before doing the
#         next change review (the default is 60 seconds);
#
#     $doOutput, a Boolean value, specifies whether or not any output
#         is written to STDOUT (the default is false).
#    
#     $p4server is the name of your server
#
#     $p4 is the executable and global arguments.
#
#     $mailhost is the name of the SMTP email host.
#
#     $lockfile is the name of a lockfile to be used in case this is
#         invoked from a cron job, and the script hasn't finished yet.
#
#     $counter is the name of the counter to be used. (default = 'review')
# 
#     $p4db is the partial URL for an instance of P4DB. Undefine it if you
#         don't have P4DB.
#
# 5)  If $doOutput is set to 0, run perfreview as
#
#          perfreview.perl &
#
#      Otherwise, run it as
#
#          perfreview.perl >> somefile &
#
####

# ======================================================================
# Globals
# ======================================================================

my $once = 1;
my $sleepTime = 60;
my $doOutput = 0;
my $p4server = "aus-perforce1.station.sony.com";
my $p4 = "/usr/local/bin/p4 -p $p4server:1666";
my $mailhost = "127.0.0.1:25";
my $lockfile = "/tmp/perfreview.lock";
my $counter = "review";
my $maillist = "//depot/admin/data/maillist.txt";
my $p4db = "http://perforce/p4db/chv.cgi?CH=";

# Temp variable
my %depot_email = ();

# ======================================================================
# Subroutines
# ======================================================================

sub p4_filespec_to_regexp
{
	local $_ = $_[0];
	my $out = "";

	# process the leading part of the input
	while (length($_))
	{
		if (s/^([^\.\*\(\)\{\}\|\\\[\]\?\+]+)//)
		{
			# copy non-wildcard leading characters
			$out .= $1;
		}
		elsif (s/^\.\.\.//)
		{
			# convert ... to .*
			$out .= ".*";
		}
		elsif (s/^\*//)
		{
			# convert * to [^/]*
			$out .= "[^/]*";
		}
		elsif (s/^([\.\(\)\{\}\|\\\[\]\?\+])//)
		{
			# convert . to \.
			$out .= "\\$1";
		}
		else
		{
			die "should never get here: $_\n";
		}
	}

	return $out;
}

# ======================================================================
# Main
# ======================================================================

if (-e $lockfile)
{
	die "Lockfile $lockfile already exists.";
}
open(LOCKFILE, ">$lockfile") || die "Cannot create lockfile $lockfile\n"; 
print LOCKFILE "locked\n";
close(LOCKFILE) || die "Cannot close lockfile $lockfile\n";

print("START: ". localtime() . "\n") if ($doOutput);

# make unbuffered
select(STDOUT); 
$| = 1;     

# if -1 is given, we'll run once
$flag = shift( @ARGV );
$once = 1 if( $flag eq '-1' );

do
{
	# Remember highest numbered change we see, so that we can
	# reset the 'review' counter once all mail is delivered.
	# If we crash, the worst that happens is we'll send the mail
	# again.
    
	local( $topChange ) = 0;

	open(P4PRINT, "$p4 print -q $maillist|"); 
	while ( <P4PRINT> ) {
		# Format: //depot/<path>  email
		if ( m!(//depot/\S*)\s+(.+)! ) 
		{
			push( @{ $depot_email{p4_filespec_to_regexp($1)} }, split(/\s+/, $2));
		}
    	}
	close(P4PRINT);

	#
	# REVIEW - list of changes to review.
	#
    
	open( REVIEW, "$p4 review -t $counter|" ) || next;
	while( <REVIEW> )
	{
	
		#
		# Format: "Change x user <email> (Full Name)"
		#
		local( $change, $user, $email, $fullName ) = /Change (\d*) (\S*) <(\S*)> (\(.*\))$/;
		print (localtime() . "review '$change', user='$user', email='$email', fullname='$fullName'\n") if ($doOutput);
	
		#
		# Get list of people who will review this change
		#
		print(localtime() . "...mail start: From: $email\n") if ($doOutput);
	
		open( REVIEWERS, "$p4 reviews -c $change|" ) || next;
		local (@reviewers) = ();
		while( <REVIEWERS> )
		{
			# user <email> (Full Name)
			local( $user2, $email2, $fullName2 ) = /(\S*) <(\S*)> (\(.*\))$/;
			print (localtime() . "......reviewer user2='$user2', email2='$email2', fullname2='$fullName2'\n") if ($doOutput);
			push(@reviewers, $email2);
		}
		close( REVIEWERS );

		open( DESCRIBE, "$p4 describe -s $change|" );
		local (@describe) = ();
		my %branches;
		my %email_seen = ();
		while( <DESCRIBE> )
		{
			# don't allow single .'s through
			$_ = "..\n" if( $_ eq ".\n" );
	    
			push(@describe, $_);

			# email list
			foreach my $tok (keys %depot_email)
			{
				# This line checks the file versus what's stored in the maillist.txt
				if (m!^\.\.\. ($tok)!)
				{
					foreach my $e ( @{ $depot_email{$1} } ) 
					{
						$email_seen{$e} = 1;
		    			}
				}
	    		}

			# branch name -- add other if() cases here first for odd project/branches
			# example:
			# if (m!\.\.\. //depot/projecta/([^/]+/[^/]+)/[^\#]+\#\d+ \w+!)
			# {
			#   $branches{$1} = 1;
			# } else
			if (m!\.\.\. //depot/([^/]+/[^/]+)/[^\#]+\#\d+ \w+!)
			{
				$branches{$1} = 1;
			}
		}
		close( DESCRIBE );

		my @branches = keys(%branches);

		my $smtp = Net::SMTP->new($mailhost) || die "cannot connect to $mailhost via SMTP";
	    
		$smtp->mail("$email $fullName");
		$smtp->to("$email");

		foreach (keys %email_seen)
		{
		    $smtp->to($_);
		}
		foreach (@reviewers)
		{
		    $smtp->bcc($_);
		}
	
		$smtp->data();
		$smtp->datasend("To: $email\n");
		foreach (keys %email_seen)
		{
		    $smtp->datasend("To: $_\n");
		}
		$smtp->datasend("Reply-To: $email\n");

		$smtp->datasend("Subject: PERFORCE change $change for review on $p4server");

		if (scalar(@branches))
		{
		    $smtp->datasend(", branch(es): " . join(" ", @branches));
		}
		$smtp->datasend("\n\n");

		# if you have a P4DB, here is where you can put the 
		$smtp->datasend("<" . $p4db . $change . ">\n") if defined $p4db;
		$smtp->datasend(@describe);
		$smtp->dataend();
		$smtp->quit();
	
		print(localtime() . "......mail end: From: $email\n") if ($doOutput);
	
		$topChange = $change;
	}
    
	#
	# Update counter to reflect changes reviewed.
	#
    
	system( "$p4 review -c $topChange -t $counter" ) if( $topChange );

	print("Update counters...\n") if ($doOutput)
}
while( !$once && sleep($sleepTime) );

print("END: " . localtime() . "\n") if ($doOutput);
unlink "$lockfile";

