#!/perl/bin

die "usage: perl assignVertexShaderConstants.pl input_template hlsl.inc dx.inc shaderBuilder.inc\n" if (@ARGV != 4);

my $register = 0;

# define the sizes of some intrinsic types
my %size;
$size{"float"}    = 1;
$size{"float2"}   = 1;
$size{"float3"}   = 1;
$size{"float4"}   = 1;
$size{"float4x4"} = 4;

# open all the files
open(INPUT, shift);
open(HLSL, ">".shift);
open(CPP, ">".shift);
open(SB, ">".shift);

while (<INPUT>)
{
	chomp;
	
	if (/^struct/)
	{
		# begin recording information about a struct
		print HLSL "$_\n";
		s/^struct\s+//;
		$struct = $_;
	}
	elsif ($struct ne "" && /^};/ )
	{
		# end recording information about a struct
		print HLSL "$_\n";
		undef $struct;
	}
	elsif (/^\/\// || /^#pragma/ || /^{/ || /^\s*$/)
	{
		# copy any comments, pragmas, open curly braces, or blank lines
		print HLSL "$_\n";
	}
	elsif (/^static const int /)
	{
		# record global integer values for array sizes
		print HLSL "$_\n";
		s/^static const int //;
		s/;//;
		s/=//;
		($variable, $value) = split;
		$variable{$variable} = $value;
	}
	else
	{
		# assume this is a global variable or structure member
		s/;//;

		my $array = 0;
		my $count = 1;
		
		if (/\[(.+)\]/)
		{
			if (defined $variable{$1})
			{
				$count = $variable{$1};
			}
			else
			{
				$count = $1;
			}
			$array = 1;
		}
		
		($type, $variable) = split;

		die "unknown size for $type\n" if (!defined $size{$type});

		if (defined $struct)
		{
			print HLSL "$_;\n";
			$size{$struct} += $size{$type} * $count;

			@array = ( "" );
			@array = (0 .. $count-1) if ($array);
			$variable =~ s/\[.*//;

			foreach $index (@array)
			{
				# handle structure members

				$index = "[$index]" if ($index ne "");
				if (defined $members{$type})
				{
					my @members = split (/\s+/, $members{$type});
					while (@members)
					{
						my $member = shift @members;
						my $size = shift @members;
						$members{$struct} .= " " if (defined $members{$struct});
						$members{$struct} .= "$variable$index.$member $size";
					}
				}
				else
				{
					$members{$struct} .= " " if (defined $members{$struct});
					$members{$struct} .= "$variable$index $size{$type}";
				}
			}
		}
		else
		{
			# handle global variables

			s/;//;

			if (defined $members{$type})
			{
				# emit registers for all the stucture members
				my $offset = 0;
				my @members = split (/\s+/, $members{$type});
				while (@members)
				{
					my $member = shift @members;
					print SB "\t\taddConstantRegister(\"$variable.$member\", ", $register + $offset, ");\n";
					$offset += shift @members;		
				}
			}
			else
			{
				# emit register for the variable
				print SB "\t\taddConstantRegister(\"$variable\", $register);\n";
			}

			print CPP "\tVSCR_$variable = $register,\n";
			print HLSL "$_ : register(c$register);\n";
			$register += $size{$type} * $count;
		}
	}
}

print CPP "\tVSCR_MAX", " = $register\n";

close(INPUT);
close(HLSL);
close(CPP);
close(SB);

