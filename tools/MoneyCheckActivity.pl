#! /usr/bin/perl

use strict;
use warnings;
use Getopt::Std;
use Math::BigInt;

my	%player_hash;

# key (player id) => (# trans to, total amt to them, last time to them, 
# 		      # trans from, total amt from them, last time from them)
# money_hash is a global hash referece for whatever player we are analyzing
my	$money_hash;

my 	$cnt 		= 0;
my 	$sort_val 	= 0;
my 	$max_cnt 	= 0;
my	%args;
my	$start_time;
my 	$min_thresh 	= 0;
my	$max_thresh 	= 0;
my	$player_id	= 0;
my	$start_date;
my	$end_date;
my 	$num_days;

my 	$total_in 	= new Math::BigInt '0';
my 	$total_out 	= new Math::BigInt '0';
my 	$num_total_in	= new Math::BigInt '0';
my	$num_total_out	= new Math::BigInt '0';
my 	@keys;

my	$big_zero	= new Math::BigInt '0';
my	$str_out;

my 	$abridged 	= 1;

# Usage
sub usage 
{
	my $name = $0;
	$name =~ s/^(.*)\\//;
	print STDERR "\nUsage:\n";
	print STDERR "\t$name <optional parameters> <server> <start date> <end date> <player id> ... (as many player ids as you want to scan)\n";
	print STDERR "\t\tDate format = yyyy-mm-dd (eg: 2004-06-08)\n";
	print STDERR "\t$name <optional parameters> -f <money log file> <player id> ... (as many player ids as you want to scan)\n";
	print STDERR "Optional parameters:\n";
	print STDERR "\t[-l <num>] [-s <str> | -S <str>] [-n | -a | -t | -N | -A | -T] [-m <str> | -x <str> | -e <str>] [-d]\n";
	print STDERR "\t-l <num>\tOnly process <num> lines of log file\n";
	print STDERR "\t-s <time>\tStart processing at <time> \(eg \"2004-06-01 17:00:03\"\)\n";
	print STDERR "\t-S <time>\tEnd processing at <time>\n";
	print STDERR "\t-p      \tSort by player id number (default)\n";
	print STDERR "\t-n      \tSort by number of transactions to the player\n";
	print STDERR "\t-a      \tSort by total amount of money to the player\n";
	print STDERR "\t-t      \tSort by time of most recent transaction to the player\n";
	print STDERR "\t-N      \tSort by number of transactions from the player\n";
	print STDERR "\t-A      \tSort by total amount of money from the player\n";
	print STDERR "\t-T      \tSort by time of most recent transaction from the player\n";
	print STDERR "\t-m <str>\tSet minimum threshold for sorted parameter\n";
	print STDERR "\t-x <str>\tSet maximum threshold for sorted parameter\n";
	print STDERR "\t-e <str>\tSet threshold to exactly <num>\n";
	print STDERR "\t-d      \tShow detailed output\n";
	die "\n";
}

# Adds money / player id into hash 
# Two arguments - key, amount of money, and (to / from)
sub put_into
{
	my ($key, $amt, $tim, $tf) = @_;
	
	$tf = ($tf * 3); 
	
	$$money_hash{$key} = [0, 0, 0, 0, 0, 0, 0] if(!exists $$money_hash{$key});
	
	$$money_hash{$key}->[$tf] += 1;
	$$money_hash{$key}->[$tf+1] += $amt;
	$$money_hash{$key}->[$tf+2] = $tim if($tim gt $$money_hash{$key}->[$tf+2]);
}

# Will sort numbers and strings - returns -1, 0, or 1
# Takes two arguments, to compare
sub str_num_cmp 
{
	my($a, $b) = @_;
	
	# Both are numbers
	return $a <=> $b if($a =~ /^\d+$/ && $b =~ /^\d+$/);

	# Both are not numbers
	return $a cmp $b if(!($a =~ /^\d+$/) && !($b =~ /^\d+$/));

	# $a is a number, $b is not
	return 1 if($a =~ /^\d+$/);
	
	# $a is not a number, $ b is
	return -1;
}

# Displays the money chart in %money_hash
# Takes no arguments
sub display_money_chart 
{ 
	my 	$temp_total = $big_zero;
	my 	$temp_hash = $_[0];
	my 	@key_vals;
	my 	@sorted_vals;	

	@key_vals = keys %$money_hash;
	@sorted_vals = ();
	foreach my $sub_elem (@key_vals)
	{
		push(@sorted_vals, [$sub_elem, $$money_hash{$sub_elem}->[0], $$money_hash{$sub_elem}->[1],
				$$money_hash{$sub_elem}->[2], $$money_hash{$sub_elem}->[3],
				$$money_hash{$sub_elem}->[4], $$money_hash{$sub_elem}->[5]]);
	}
	
	@sorted_vals = sort { &str_num_cmp($b->[$sort_val], $a->[$sort_val]) } @sorted_vals;
	@sorted_vals = reverse(@sorted_vals) if($sort_val == 0);
	foreach my $val (@sorted_vals)
	{
		if((!exists $args{"m"} || (&str_num_cmp($val->[$sort_val], $min_thresh) == 0 || &str_num_cmp($val->[$sort_val], $min_thresh) == 1))
		&& (!exists $args{"x"} || (&str_num_cmp($val->[$sort_val], $max_thresh) == 0 || &str_num_cmp($val->[$sort_val], $max_thresh) == -1))
		&& (!exists $args{"e"} || &str_num_cmp($val->[$sort_val], $max_thresh) == 0))
		{
			$total_in += $val->[5];
			$total_out += $val->[2];
			
			$num_total_in += $val->[4];
			$num_total_out += $val->[1];

			if(!$abridged)
			{
				printf "\t%-34s%-8s%-12s%-24s%-8s%-12s%-24s\n", $val->[0], $val->[1], $val->[2], $val->[3], $val->[4], $val->[5], $val->[6];
			}
			else
			{
				$str_out = sprintf "%s\t%s\t%s\t%s\t%s\t%s\n", $val->[5], $val->[4], $val->[2], $val->[1], ($val->[5] - $val->[2]), $val->[0];
				$str_out =~ s/\+//g;
				print $str_out;
			}
		}
	}
	
}

$start_time = time;
&usage() if(!getopts('dpnatNATm:x:l:e:s:S:f:', \%args));
&usage if(((exists $args{"n"}) + (exists $args{"a"}) + (exists $args{"t"}) 
	 + (exists $args{"N"}) + (exists $args{"A"}) + (exists $args{"T"}) + (exists $args{"p"})) > 1);
&usage if((exists $args{"e"}) && (exists $args{"m"} || exists $args{"x"}));

# Process arguments
$sort_val = 0 if(exists $args{"p"});
$sort_val = 1 if(exists $args{"n"});
$sort_val = 2 if(exists $args{"a"});
$sort_val = 3 if(exists $args{"t"});
$sort_val = 4 if(exists $args{"N"});
$sort_val = 5 if(exists $args{"A"});
$sort_val = 6 if(exists $args{"T"});
$max_cnt = $args{"l"} if(exists($args{"l"}));
$min_thresh = $args{"m"} if(exists($args{"m"}));
$max_thresh = $args{"x"} if(exists($args{"x"}));
$min_thresh = $max_thresh = $args{"e"} if(exists($args{"e"}));
$start_date = $args{"s"} if(exists($args{"s"}));
$end_date = $args{"S"} if(exists($args{"S"}));
$abridged = 0 if(exists($args{"d"}));

if(exists($args{"f"}))
{
	&usage if(@ARGV < 1);
	open (MONEY, $args{"f"});
}
else
{
	&usage if(@ARGV < 4);
	my $server = shift;
	my $start = shift;
	my $end = shift;
	open(MONEY, "/m2/logsrv/log_dump.pl swg money $server $start $end |");
}

# Fill the player hash
foreach(@ARGV)
{
	$player_hash{$_} = {};
}

	while (<MONEY>)
	{
		# Clear out three possible Unicode chars
		s/^...20(\d{2})/20$1/;
		chomp;
	
		my $day;
		my $time;
		my $planet;
		my $vara;
		my $varb;
		my $varc;
		my $type;
		my $from;
		my $to;	
		my $amount;
		my $total;
	
		# Check start date if argument was passed
		if(exists $args{"s"} && /^(\S+)\s+(\S+)/)
		{
			my $date = $1." ".$2;
			next if($date lt $start_date);
		}
		# Check end date if argument was passed
		if(exists $args{"S"} && /^(\S+)\s+(\S+)/)
		{
			my $date = $1." ".$2;
			last if($date gt $end_date);
		}
		
		# Check a few special cases
		if(/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+) (from|to) bank by (.+), amount (\d+), (total|total\(from\)) -?(\d+):$/)
		{
			#player deposited / withdrew money from bank
			
			$day	= $1;
			$time	= $2;
			$planet	= $3;
			$vara	= $4;
			$varb	= $5;
			$varc	= $6;
			$type	= $7;
			$from	= $8;
			$to	= $9;
			$amount	= $10;
			$total 	= $11;

			#Strip the station id - can cause problems searching for player id
			$from =~ s/StationId\(\d+\)//g;
			$to =~ s/StationId\(\d+\)//g;

			# If it's a named account, strip the name out
			$to =~ s/named account //;

			# Extract player Id number
			$to =~ s/.*\((\d+)\).*/$1/ if($to =~ /Player/);

			# Add into the approproiate hash
			if($from eq "to" && exists $player_hash{$to})
			{
				$money_hash = $player_hash{$to};
				&put_into("bank", $amount, ($day." ".$time), 0);	
			}

			if($to eq "from" && exists $player_hash{$to})
			{
				$money_hash = $player_hash{$to};
				&put_into("bank", $amount, ($day." ".$time), 1);	
			}

		}
		elsif(/logging out with/ || /logged in with/)
		{
			#player logged in / out
			next;
		}
		elsif(/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+) from (.+) to (.+), amount (\d+), (total|total\(from\)) -?(\d+):$/)
		{
			$day	= $1;
			$time	= $2;
			$planet	= $3;
			$vara	= $4;
			$varb	= $5;
			$varc	= $6;
			$type	= $7;
			$from	= $8;
			$to	= $9;
			$amount	= $10;
			$total 	= $11;

			#Strip the station id - can cause problems searching for player id
			$from =~ s/StationId\(\d+\)//g;
			$to =~ s/StationId\(\d+\)//g;

			# If it's a named account, strip the name out
			$from =~ s/named account //;
			$to =~ s/named account //;

			# Extract player Id number
			$from =~ s/.*\((\d+)\).*/$1/ if($from =~ /Player/);
			$to =~ s/.*\((\d+)\).*/$1/ if($to =~ /Player/);

			# Special case where player has " from " in store title
			if($type =~ /Player/)
			{
				$type =~ s/(.*) from /$1/;
				$from =~ s/.*\((\d+)\).*/$1/;
			}

			# Add into the approproiate hash
			if(exists $player_hash{$from})
			{
				$money_hash = $player_hash{$from};
				&put_into($to, $amount, ($day." ".$time), 0);	
			}

			if(exists $player_hash{$to})
			{
				$money_hash = $player_hash{$to};
				&put_into($from, $amount, ($day." ".$time), 1);	
			}


		}
		else
		{
			print "$_\n";
			die "Error in log file format.\n";
		}
	

		# Check counter
		++$cnt;
		last if($cnt == $max_cnt);
	}

close (MONEY);

#update money hash
foreach my $player (keys %player_hash)
{
	$money_hash = $player_hash{$player};

	$total_in	= $big_zero;
	$total_out	= $big_zero;
	$num_total_in	= $big_zero;
	$num_total_out	= $big_zero;

	if(!$abridged)
	{
		print "Transactions for user $player_id:\n";
		print "---------------------------------\n\n";
		print "\tTransactions:\n";
		printf "\t%-34s%-8s%-12s%-24s%-8s%-12s%-24s\n", "Player Id:", "# To:", "Amt To:", "Last Tm To", "# Fr:", "Amt Fr:", "Last Tm Fr";
		printf "\t%-34s%-8s%-12s%-24s%-8s%-12s%-24s\n", "----------", "-----", "-------", "----------", "-----", "-------", "----------";

		display_money_chart();

		print "\n";
		print "Total money given to $player_id: $total_in\n";
		print "Total money $player_id gave: $total_out\n";
		print "\nFinished in ".(time - $start_time)." seconds.\n";
	}
	else
	{
		print "Information for player id: $player\n";
		printf "%s\t%s\t%s\t%s\t%s\t%s\n", "To:", "# To:", "From:", "# From", "Delta:", "Account:";
		display_money_chart();
		$str_out = sprintf "\n%s\t%s\t%s\t%s\t%s\t%s\n", $total_in, $num_total_in, $total_out, $num_total_out, ($total_in - $total_out), "Total";
		$str_out =~ s/\+//g;
		print $str_out;
	}
print "\n";
}
