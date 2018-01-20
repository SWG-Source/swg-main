#!/usr/bin/perl

my %channels;
my %examples;

while(<STDIN>)
{
    @sections = split(':', $_);
    if(@sections[1] eq "SwgGameServer")
    {
	if(exists($channels{@sections[3]}))
	{
	    $channels{@sections[3]}++;
	}
	else
	{
	    $channels{@sections[3]} = 1;
	    $examples{@sections[3]} = $_;
	}
    }
}

foreach my $key (sort{$channels{$b} <=> $channels{$a}} keys %channels)
{
    print "\n=============================================\n\n";
    print "Channel $key: $channels{$key} reports\n";
    print "Example: $examples{$key}\n";
}
