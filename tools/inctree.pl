#!/usr/bin/perl

# Usage: inctree [options] [files]

# Configuration parameters.

$CPP = 'gcc -E';
# $CPP = "cc -P";
# $CPP = "/lib/cpp";

$shiftwidth = 4;

# Process switches.

while ($ARGV[0] =~ /^-/) {
    $_ = shift;
    if (/^-D(.*)/) {
	$defines .= " -D" . ($1 ? $1 : shift);
    }
    elsif (/^-BW/) {
			$CPP = 'cl /nologo /E';
    	$count = 0;
    	while (! chdir "build/win32")
    	{
   		die "could not find build/win32 in search backwards" if (++$count > 50);
    		chdir "..";
    	}
    }
    elsif (/^-I(.*)/) {
	
	$include = ($1 ? $1 : shift);

	if ($include =~ /\.rsp$/)
	{
		open(RSP, $include);
		while (<RSP>)
		{
			chop;
			$includes .= " -I" . $_;
		}
		close(RSP);
	}
	else {
		$includes .= " -I" . $include;
	}
    }
    elsif (/^-m(.*)/) {
	push(@pats, $1 ? $1 : shift);
    }
    elsif (/^-l/) {
	$lines++;
    }
    else {
	die "Unrecognized switch: $_\n";
    }
}

# Build a subroutine to scan for any specified patterns.

if (@pats) {
    $sub = "sub pats {\n";
    foreach $pat (@pats) {
	$sub .= "    print '>>>>>>> ',\$_ if m$pat;\n";
    }
    $sub .= "}\n";
    eval $sub;
    ++$pats;
}

# Now process each file on the command line.

foreach $file (@ARGV) {
    open(CPP,"$CPP $defines $includes $file|")
	|| die "Can't run cpp: $!\n";
    $line = 2;

    while (<CPP>) {
	++$line;
	&pats if $pats;      # Avoid expensive call if we can.
	s/^#line /# /; # handle dev-studio style line info as well
	next unless /^#/;
	next unless /^# \d/;
	chop;
	s/\\+/\\/g;
	s/\\/\//g;
	while (s#/\w+/../#/#) {}
	($junk,$newline,$filename) = split(/\s+/, $_, 3);
	$filename =~ s/"//g;
	$filename =~ s/^\s+//;
	$filename =~ s/\s+$//;

	# Now figure out if it's a push, a pop, or neither.

	if ($stack[$#stack] eq $filename) {     # Same file.
	    $line = $newline-1;
	    next;
	}

	if ($stack[$#stack-1] eq $filename) {   # Leaving file.
	    $indent -= $shiftwidth;
	    $line = pop(@lines)-1;
	    pop(@stack);
	}
	else {                                  # New file.
	    printf "%6d  ", $line-2 if $lines;
	    push(@lines,$line);
	    $line = $newline;
	    print " " x ($indent), $filename;
	    print "  DUPLICATE" if $seen{$filename}++;
	    print "\n";
	    $indent += $shiftwidth;
	    push(@stack,$filename);
	}
    }
    close CPP;
    $indent = 0;
    %seen = ();
    print "\n\n";
    $line = 0;
}
