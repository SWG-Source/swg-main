#!/usr/bin/perl

$fileName = $ARGV[0];

open(SOURCE, $fileName) or die "Can't open $fileName";

while(<SOURCE>)
{
    $scriptFile[++$#scriptFile] = $_;
}

$lineNo = 0;
foreach $l(@scriptFile)
{
    $lineNo = $lineNo + 1;
    $messageHandler = "";
    if ($l =~ /messageHandler\s*(\w+)\s*\(\)/)
    {
	if(length($1) > 0)
	{
	    $messageHandler = $1;
	    $scope = 0;
	    for($i = $lineNo; $i < $#scriptFile; ++$i)
	    {
		if( $scriptFile[$i] =~ /(\{).*/ )
		{
		    if($1 == "{")
		    {
			$scope = $scope + 1;
		    }
		} 
		if( $scriptFile[$i] =~ /(\}).*/ )
		{
		    if($1 == "}")
		    {
			$scope = $scope - 1;
			if($scope < 1)
			{
			    $i = $#scriptFile;
			    break;
			}
		    }
		}
		if ($scriptFile[$i] =~ /messageTo/)
		{
		    if ($scriptFile[$i] =~ /($messageHandler)/)
		    {
			if($scope == 1)
			{
			    $lineno = $i + 1;
			    if($scriptFile[$i] =~ /true/)
			    {
				print "$fileName:$lineno: WARNING: $messageHandler may be in an infinite messageTo loop AND is persisting the message\n";
			    }
			    else
			    {
				print "$fileName:$lineno: WARNING: $messageHandler may be in an infinite messageTo loop\n";
			    }
			}
		    }
		}
	    }
	}
    }
}
