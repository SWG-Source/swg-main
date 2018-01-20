#!/usr/bin/perl

while (<>)
{
    if (/^\./)
    {
	$debug .= $_;
	s/\/debug\//\/release\//;
	$release .= $_;
    }
    else
    {
	$debug .= $_;
	$release .= $_;
    }
}

print $debug;
print $release;
