#
# provide simple xargs-like functionality in perl.
#
# This takes each argument passed to the script, adds each line of
# standard input as an additional arg, and executes the result.
#

$DEBUG_PRINT = 0;
$EXECUTE     = 1;

# collect the initial commands from the command line options
@commands = @ARGV;

# push each line from standard input as an additional argument
while (<STDIN>)
{
    chomp();
    push @commands, ($_);
}

# print the commands
if ($DEBUG_PRINT)
{
    print "command: ";
    foreach $part (@commands)
    {
	print $part . " ";
    }
    print "\n";
}

# print @commands;
if ($EXECUTE)
{
    system @commands;
}
