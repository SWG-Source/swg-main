#!/usr/bin/perl

while (<>)
{
    print unless ($_ eq $lastline);
    $lastline = $_;
}
