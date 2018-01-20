#! /usr/bin/perl

use strict;
use warnings;
use Getopt::Std;
use Math::BigInt;

my	%from_hash;
my 	%to_hash;
my 	$cnt 		= 0;
my 	$sort_val 	= 0;
my 	$max_cnt 	= 0;
my	%args;
my	$start_time;
my 	$min_thresh 	= 0;
my	$max_thresh 	= 0;
my 	$start_date;
my	$end_date;

my 	$total_in 	= new Math::BigInt '0';
my 	$total_out 	= new Math::BigInt '0';
my 	$num_total_in 	= new Math::BigInt '0';
my 	$num_total_out 	= new Math::BigInt '0';

my	$temp_out	= new Math::BigInt '0';
my	$temp_in	= new Math::BigInt '0';
my	$num_temp_out	= new Math::BigInt '0';
my	$num_temp_in	= new Math::BigInt '0';

my	$big_zero	= new Math::BigInt '0';
my	$str_out;

my 	$abridged	= 1;
my 	@keys;

# Usage
sub usage 
{
	my $name = $0;
	$name =~ s/^(.*)\\//;
	print STDERR "\nUsage:\n";
	print STDERR "\t$name <optional parameters> <server> <start date> <end date>\n";
	print STDERR "\t\tDate format = yyyy-mm-dd (eg: 2004-06-08)\n";
	print STDERR "\t$name <optional parameters> -f <money log file>\n\n";
	print STDERR "Optional parameters:\n";
	print STDERR "\t[-l <num>] [-s <time> | -S <time>] [-p | -n | -a] [-m <num> | -x <num> | -e <num>] [-d]\n";
	print STDERR "\t-l <num>\tOnly process <num> lines of log file\n";
	print STDERR "\t-s <time>\tStart processing at <time> \(eg \"2004-06-01 17:00:03\"\)\n";
	print STDERR "\t-S <time>\tEnd processing at <time>\n";
	print STDERR "\t-p      \tSort results by player id number (default)\n";
	print STDERR "\t-n      \tSort results by number of transactions\n";
	print STDERR "\t-a      \tSort results by total amount of money changed\n";
	print STDERR "\t-t      \tSort results by time of most recent transaction\n";
	print STDERR "\t-m <num>\tSet minimum threshold for sorted parameter\n";
	print STDERR "\t-x <num>\tSet maximum threshold for sorted parameter\n";
	print STDERR "\t-e <num>\tSet threshold to exactly <num>\n";
	print STDERR "\t-d      \tShow detailed output\n";
	die "\n";
}

# Adds money / player id into hash 
# Three arguments - key, value, amount of money, and which hash (to / from)
sub put_into
{
	my %head;
	my ($key, $val, $amt, $tim, $tf) = @_;
	
	%head = ($tf ? %to_hash : %from_hash);

	$head{$key} = {} if(!exists $head{$key});
	$head{$key}->{$val} = [0, 0, 0] if(!exists $head{$key}->{$val});
	
	$head{$key}->{$val}->[0] += 1;
	$head{$key}->{$val}->[1] += $amt;
	$head{$key}->{$val}->[2] = $tim if($tim gt $head{$key}->{$val}->[2]);

	if($tf) { %to_hash = %head; } 
	else { %from_hash = %head; }
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

sub display_money_chart { 
	my 	$temp_total = new Math::BigInt '0';
	my 	$temp_num = new Math::BigInt '0';
	my 	$temp_hash = $_[0];
	my	$t_out = $_[1];
	my 	@inner_keys;
	my 	@sorted_vals;

	@inner_keys = keys %$temp_hash;
	@inner_keys = sort @inner_keys;
	@sorted_vals = ();
	foreach my $sub_elem (@inner_keys)
	{
		push(@sorted_vals, [$sub_elem, %$temp_hash->{$sub_elem}->[0], %$temp_hash->{$sub_elem}->[1], %$temp_hash->{$sub_elem}->[2]]);
	}
	
	@sorted_vals = sort { &str_num_cmp($b->[$sort_val], $a->[$sort_val]) } @sorted_vals;
	@sorted_vals = reverse(@sorted_vals) if($sort_val == 0);
	foreach my $val (@sorted_vals)
	{
		if((!exists $args{"m"} || (&str_num_cmp($val->[$sort_val], $min_thresh) == 0 || &str_num_cmp($val->[$sort_val], $min_thresh) == 1))
		&& (!exists $args{"x"} || (&str_num_cmp($val->[$sort_val], $max_thresh) == 0 || &str_num_cmp($val->[$sort_val], $max_thresh) == -1))
		&& (!exists $args{"e"} || &str_num_cmp($val->[$sort_val], $max_thresh) == 0))
		{
			if($t_out) 
			{ 
				$total_out += $val->[2]; 
				$num_total_out += $val->[1];
			} 
			else 
			{ 
				$total_in += $val->[2]; 
				$num_total_in += $val->[1];
			}
			
			$temp_total += $val->[2];
			$temp_num += $val->[1];

			if(!$abridged) 
			{
				printf "\t\t%-32s%-10d%-12d%-24s\n", $val->[0], $val->[1], $val->[2], $val->[3];
			}
		}
	}
	
	return ($temp_total, $temp_num);
}

$start_time = time;
&usage() if(!getopts('dpnatm:x:l:e:s:S:f:', \%args));
&usage if(((exists $args{"p"}) + (exists $args{"n"}) + (exists $args{"a"})) > 1);
&usage if((exists $args{"e"}) && (exists $args{"m"} || exists $args{"x"}));

# Process arguments
$sort_val = 0 if(exists $args{"p"});
$sort_val = 1 if(exists $args{"n"});
$sort_val = 2 if(exists $args{"a"});
$sort_val = 3 if(exists $args{"t"});
$max_cnt = $args{"l"} if(exists($args{"l"}));
$min_thresh = $args{"m"} if(exists($args{"m"}));
$max_thresh = $args{"x"} if(exists($args{"x"}));
$min_thresh = $max_thresh = $args{"e"} if(exists($args{"e"}));
$start_date = $args{"s"} if(exists($args{"s"}));
$end_date = $args{"S"} if(exists($args{"S"}));
$abridged = 0 if(exists($args{"d"}));

if(exists($args{"f"}))
{
	&usage if(@ARGV != 0);
	open (MONEY, $args{"f"});
}
else
{
	&usage if(@ARGV != 3);
	open(MONEY, "/m2/logsrv/log_dump.pl swg money $ARGV[0] $ARGV[1] $ARGV[2] |");
}

	while (<MONEY>)
	{
		# Clear out three possible Unicode chars
		s/^...20(\d{2})/20$1/;
		chomp;

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
		if(/cash withdraw from bank by/ || /cash deposit to bank/) 
		{
			#player deposited / withdrew money from bank
		}
		elsif(/logging out with/ || /logged in with/)
		{
			#player logged in / out
		}
		elsif(/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+) from (.+) to (.+), amount (\d+), (total|total\(from\)) -?(\d+):$/)
		{
			my $day		= $1;
			my $time	= $2;
			my $planet	= $3;
			my $vara	= $4;
			my $varb	= $5;
			my $varc	= $6;
			my $type	= $7;
			my $from	= $8;
			my $to		= $9;
			my $amount	= $10;
			my $total 	= $11;
			
			my $from_named 	= $from =~ s/named account //;
			my $to_named 	= $to =~ s/named account //;
			
			#Strip the station id - can cause problems searching for player id
			$from =~ s/StationId\(\d+\)//g;
			$to =~ s/StationId\(\d+\)//g;
			
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
			if($from_named)
			{
				&put_into($from, $to, $amount, ($day." ".$time), 0);	
			}
			
			if($to_named)
			{
				&put_into($to, $from, $amount, ($day." ".$time), 1);	
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


print "Named users transaction information:\n" if (!$abridged);
print "------------------------------------\n\n" if (!$abridged);
@keys = keys %from_hash;
push (@keys, (keys %to_hash));
@keys = sort @keys;

my $prev = -1;
@keys = grep($_ ne $prev && ($prev = $_), @keys);

printf "%s\t%s\t%s\t%s\t%s\t%s\n", "To:", "# To:", "From:", "# From:", "Delta:", "Account:" if($abridged);

foreach my $elem (@keys)
{
	$temp_in = $big_zero;
	$temp_out = $big_zero;
	
	$num_temp_in = $big_zero;
	$num_temp_out = $big_zero;

	
	print "$elem:\n" if(!$abridged);
	if(exists $from_hash{$elem})
	{
		if(!$abridged)
		{
			print "\tMoney from $elem:\n";
			printf "\t\t%-32s%-10s%-12s%-24s\n", "To:", "# Times:", "Total Amt:", "Most Recent Time:";
			printf "\t\t%-32s%-10s%-12s%-24s\n", "---", "--------", "----------", "-----------------";
		}

		($temp_out, $num_temp_out) = display_money_chart($from_hash{$elem}, 0);

		if(!$abridged)
		{
			print "\tTotal $elem gave:\n";
			print "\t\t$temp_out\n\n";
		}
	}
	if(exists $to_hash{$elem})
	{
		if(!$abridged)
		{		
			print "\tMoney to $elem:\n";
			printf "\t\t%-32s%-10s%-12s%-24s\n", "From:", "# Times:", "Total Amt:", "Most Recent Time:";
			printf "\t\t%-32s%-10s%-12s%-24s\n", "-----", "--------", "----------", "-----------------";
		}

		($temp_in, $num_temp_in) = display_money_chart($to_hash{$elem}, 1);

		if(!$abridged)
		{
			print "\tTotal given to $elem:\n";
			print "\t\t$temp_in\n\n";
		}
	}
	
	printf "%s\t%s\t%s\t%s\t%s\t%s\n", "To:", "# To:", "From:", "# From:", "Delta:", "Account:" if(!$abridged);
	$str_out = sprintf "%s\t%s\t%s\t%s\t%s\t%s\n", $temp_in, $num_temp_in, $temp_out, $num_temp_out, ($temp_out - $temp_in), $elem;
	$str_out =~ s/\+//g;
	print $str_out;

}

if(!$abridged)
{
	print "\nTotal out:\t$total_out\n";
	print "Total in:\t$total_in\n";
	print "Total Delta:\t".($total_in - $total_out)."\n";
	print "\nFinished in ".(time - $start_time)." seconds.\n";
}
else
{
	$str_out = sprintf "\n%s\t%s\t%s\t%s\t%s\t%s\n", $total_out, $num_total_out, $total_in, $num_total_in, ($total_in - $total_out), "Total";
	$str_out =~ s/\+//g;
	print $str_out;
}

