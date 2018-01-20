#!/usr/bin/perl

# Given a planet name, searches a log file to check that every chunk on that planet was loaded

($targetPlanet, $logfile)=@ARGV;
open(LOGFILE,$logfile);
while (<LOGFILE>)
{
    if (/ChunkLocator:Chunk (\w+) ([-\d]+) ([-\d]+)/)
    {
	($planet, $x, $z) = ($1, $2, $3);
	if ($planet eq $targetPlanet)
	{
	    $chunks{$x.":".$z}+=1;
	}
    }
}

for ($x=-8000; $x<=8000; $x+=100)
{
    for ($z=-8000; $z<=8000; $z+=100)
    {
	if ($chunks{$x.":".$z}!=2)
	{
	    print "Chunk error $targetPlanet $x,$z.  Was in logs ".($chunks{$x.":".$z}+0)." times (should be 2 times)\n";
	}
    }
}
