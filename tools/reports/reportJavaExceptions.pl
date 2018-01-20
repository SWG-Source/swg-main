#!/usr/bin/perl


# initialize all of the variables

$mode = 0;
$stackFound = 0;
$temp = 0;
$i = 0;
$j = 0;
$strStack = "";
$stackArray[0] = "";
$allStacks[0] = "";
$prev1 = "prev1";
$prev2 = "prev2";
$prev3 = "prev3";
$prev4 = "prev4";
$prev5 = "prev5";
$prev6 = "prev6";
$prev7 = "prev7";
$prev8 = "prev8";
$prev9 = "prev9";
$prev10 = "prev10";
$blank = "\n ";
$spacer = "===========================================\n";



# process input by line

while(<STDIN>)
{

	# save current line of text as $line
	$line = $_;


	# if we're in print mode and if the line starts with a blank space
	# decrement the line counter
	if( ($line =~ /^\s+/) && $mode > 0)
	{
		$mode = $mode - 1;
		if ($temp == 0)
		{
			#save the stack to compare against found stacks
			$strStack = $strStack . $line;
		}
	}
	elsif( $mode > 0)
	{
		$temp = 1;
	}

	
	# increment for each line that we read, if we're in print mode
	# or if we're not in print mode and we see a java exception line, then go into print mode.
	if($mode > 0)
	{
		$mode = $mode + 1;
	}
	elsif( $line =~ /^java\./)
	{
		$mode = 2;
	}


	# save the stack if we're in print mode. otherwise, adjust for previous lines
	if( ($mode > 0) && ($mode < 10))
	{
		$stackArray[$i] = $line;
		$i = $i + 1;
	}
	elsif( $mode < 1 )
	{
		$mode = 0;
		$prev10 = $prev9;
		$prev9 = $prev8;
		$prev8 = $prev7;
		$prev7 = $prev6;
		$prev6 = $prev5;
		$prev5 = $prev4;
		$prev4 = $prev3;
		$prev3 = $prev2;
		$prev2 = $prev1;
		$prev1 = $line;
	}


	# check to see if we've copied the entire stack.
	if ( $mode > 9 )
	{
		
		# check to see if this stack has already been found
		$x = 0;
		while ($x < $j)
		{
			if ($allStacks[$x] eq $strStack)
			{
				#stack already been found
				$stackFound = 1;
			}
			
			$x = $x +1;
		}
		
		
		if ($stackFound == 1)
		{
			#this stack has already been found, skip the printing
		}
		else
		{
		
			#add this stack to the list of known stacks
			$allStacks[$j] = $strStack;
			$j = $j + 1;
			
					
			# print out the previous lines
			print $blank;
			print $spacer;
			print $blank;
			print $prev10;
			print $prev9;
			print $prev8;
			print $prev7;
			print $prev6;
			print $prev5;
			print $prev4;
			print $prev3;
			print $prev2;
			print $prev1;
			
			
			# print the stack
			$x = 0;
			while ($x < $i)
			{
				print $stackArray[$x];
				$x = $x + 1;
			}
			
		
		}
		
		# re-initialize some variables
		$prev1 = "";
		$prev2 = "";
		$prev3 = "";
		$prev4 = "";
		$prev5 = "";
		$prev6 = "";
		$prev7 = "";
		$prev8 = "";
		$prev9 = "";
		$prev10 = "";
		$strStack = "";
		$i = 0;
		$stackFound = 0;
		$temp = 0;
		$mode = 0;
		
	}

	
}

