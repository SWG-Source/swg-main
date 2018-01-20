#! /usr/bin/perl
# ======================================================================
# 
# ======================================================================

use strict;
use warnings;
use POSIX qw(ceil);

# ======================================================================
# Globals
# ======================================================================

my $scriptName = $0;
my $absoluteScriptName = $scriptName;
$scriptName =~ s/^(.*)[\\\/]//;

my $inputFile;
my $outputFile;

my @simulation;

my $template = 
qq%# Use pound to comment
Label: <simulation label>
NumberOfRounds: <num rounds>
CombatConsts:
	BaseToHit: <base to hit>
	MaxToHit: <max to hit>
	MinToHit: <min to hit>
	ToHitScale: <to hit scale>
	ToHitStep: <to hit step>
	DamageScale: <damage scale>
Attacker:
	Stats:
		AttackValue: <attack value>
	CombatSkillMods:
		SpeedMod: <speed value>
	WeaponStats:
		RateOfFire: <rate of fire>
		MaxDamage: <max damage>
		MinDamage: <min damage>
Defender:
	Stats:
		DefenseValue: <defense value>
	ArmorStats:
		Effectiveness: <armor value>
IncrementAttribute: 
	Attribute: <attribute> 
	IncrementValue: <increment value> 
	MaxValue: <max>
End:
# You can put multiple of these entries in one file, but each must end with End:
%;

# ======================================================================
# Combat consts
# ======================================================================

use constant DEFAULT_BASE_TO_HIT  => 90.0;
use constant DEFAULT_MAX_TO_HIT   => 95.0;
use constant DEFAULT_MIN_TO_HIT   => 60.0;
use constant DEFAULT_TO_HIT_SCALE => 50.0;
use constant DEFAULT_TO_HIT_STEP  => 5.0;
use constant DEFAULT_DAMAGE_SCALE => 500.0;

# ======================================================================
# Subroutines
# ======================================================================

sub usage()
{
	die "\nUsage:\n\t$scriptName <input file>\n\n".
		"\t$scriptName --template <file name> : will dump out a template file for the input\n";
}

sub calculateHit
{
	my $hashRef = $_[0];

	my $success = 0;
	my $damage  = 0;

	my $baseToHit   = (exists $hashRef->{"CombatConsts"}->{"BaseToHit"})   ? $hashRef->{"CombatConsts"}->{"BaseToHit"}   : DEFAULT_BASE_TO_HIT;
	my $maxToHit    = (exists $hashRef->{"CombatConsts"}->{"MaxToHit"})    ? $hashRef->{"CombatConsts"}->{"MaxToHit"}    : DEFAULT_MAX_TO_HIT;
	my $minToHit    = (exists $hashRef->{"CombatConsts"}->{"MinToHit"})    ? $hashRef->{"CombatConsts"}->{"MinToHit"}    : DEFAULT_MIN_TO_HIT;
	my $toHitScale  = (exists $hashRef->{"CombatConsts"}->{"ToHitScale"})  ? $hashRef->{"CombatConsts"}->{"ToHitScale"}  : DEFAULT_TO_HIT_SCALE;
	my $toHitStep   = (exists $hashRef->{"CombatConsts"}->{"ToHitStep"})   ? $hashRef->{"CombatConsts"}->{"ToHitStep"}   : DEFAULT_TO_HIT_STEP;
	my $damageScale = (exists $hashRef->{"CombatConsts"}->{"DamageScale"}) ? $hashRef->{"CombatConsts"}->{"DamageScale"} : DEFAULT_DAMAGE_SCALE;

	# ----- START BASE RESOLUTION FORMULA -----
	my $attackVal = $hashRef->{"Attacker"}->{"Stats"}->{"AttackValue"} - $hashRef->{"Defender"}->{"Stats"}->{"DefenseValue"};
	my $resultAttackVal = $attackVal;
	$attackVal /= $toHitScale;
	
	my $stepDir = 0.0;
	if ($attackVal > $stepDir) 
	{
		$stepDir = 1.0;
	}
	elsif ($attackVal < $stepDir) 
	{
		$stepDir = -1.0;
	}

	my $toHitChance = $baseToHit;
	my $maxStep = ceil(($baseToHit - $minToHit)/$toHitStep);
	for (my $i = 1; $i < $maxStep; $i++)
	{
		if (($attackVal * $stepDir) > $i)
		{
			$toHitChance += $stepDir * $toHitStep;
			$attackVal -= $stepDir * $i;
		}
		else
		{
			$toHitChance += ($attackVal/$i) * $toHitStep;
			last;
		}
	}

	$toHitChance = $maxToHit if ($toHitChance > $maxToHit);
	$toHitChance = $minToHit if ($toHitChance < $minToHit);

	if ((rand(99.0) + 1) < $toHitChance)
	{
		$success = 1;
		my $dist = 0.5 + ($resultAttackVal / $damageScale);
		$damage = distributedRand($hashRef->{"Attacker"}->{"WeaponStats"}->{"MinDamage"}, $hashRef->{"Attacker"}->{"WeaponStats"}->{"MaxDamage"}, $dist);
	}

	my @result = ($success, $damage);
	return @result;
	# ----- END BASE RESOLUTION FORMULA -----
}

sub distributedRand
{
	my ($min, $max, $dist) = @_;

	my $inverted = 0;
	my $_min = $min;
	my $_max = $max;

	$dist = -1 if ($dist < -1);
	$dist = 2 if ($dist > 2);

	if ($min > $max)
	{
		$inverted = 1;
		$min = $_max;
		$max = $_min;
	}

	my $mid = $min + (($max - $min) * $dist);

	if ($mid < $min)  { $max += ($mid-$min); $mid = $min; }
	if ($mid > $max)  { $min += ($mid-$max); $mid = $max; }

	my $minRand = (rand(int($mid+0.5) - $min) + $min);
	my $maxRand = (rand($max - int($mid+0.5)) + int($mid+0.5));

	my $randNum = (rand($maxRand - $minRand) + $minRand);

	$randNum = $_min + ($_max - $randNum) if ($inverted);

	return $randNum;
}	

sub specialCombatSort
{
	my ($a, $b) = @_;
	
	return -1 if ($a eq "Label");
	return 1 if ($b eq "Label");
	return -1 if ($a eq "NumberOfRounds");
	return 1 if ($b eq "NumberOfRounds");
	return -1 if ($a eq "Attacker");
	return 1 if ($b eq "Attacker");
	return -1 if ($a eq "Defender");
	return 1 if ($b eq "Defender");
	return $a cmp $b;
}

sub printHash
{
	my ($hashRef, $handle, $tab) = @_;
	
	foreach my $key (sort { specialCombatSort($a, $b) } keys %{$hashRef})
	{
		if (ref($$hashRef{$key}) eq "HASH")
		{
			print $handle "$tab$key\n";
			printHash($$hashRef{$key}, $handle, "$tab\t");
		}
		else
		{
			print $handle "$tab$key: $$hashRef{$key}\n";
		}
	}
}

sub getFromHash
{
	my ($key, $hashRef) = @_;
	my $subKey;
	
	$key .= ":" if ($key !~ /:$/);
	
	while ($key)
	{
		$key =~ s/^([^:\s]+)://;
		$subKey = $1;
		last if ($key eq "");
		$$hashRef{$subKey} = {} if (!exists $$hashRef{$subKey});
		$hashRef = $$hashRef{$subKey};
	}
	
	return undef if (!exists $$hashRef{$subKey});
	return $$hashRef{$subKey};
}

sub putIntoHash
{
	my ($key, $val, $hashRef) = @_;
	my $subKey;
	
	$key .= ":" if ($key !~ /:$/);
	
	while ($key)
	{
		$key =~ s/^([^:\s]+)://;
		$subKey = $1;
		last if ($key eq "");
		$$hashRef{$subKey} = {} if (!exists $$hashRef{$subKey});
		$hashRef = $$hashRef{$subKey};
	}
	
	if (!defined $val || $val eq "")
	{
		$$hashRef{$subKey} = {};
	}
	else
	{
		$$hashRef{$subKey} = $val;
	}
}

sub parseInput
{
	my $current = "";
	my $line = 0;
	push @simulation, {};
	
	my @currentLabel;
	open(INPUTFILE, $inputFile) || die "cannot open $inputFile\n";
	while (<INPUTFILE>)
	{
		++$line;
		# skip whitespace and comments
		next if (/^\s+$/ || /^\s*#/);
		
		if (/End:/i)
		{
			push @simulation, {};
			next;
		}
		
		s/^(\s*)(\S+):\s*(.*)//;
		my $tabs = $1;
		my $label = $2;
		my $value = $3;
		die "Lines must be led with tabs\n" if ($tabs !~ /^\t*$/);
		my $tabNum = length $tabs;
		
		if ($tabNum == @currentLabel)
		{
			push @currentLabel, $label;
		}
		elsif ($tabNum < @currentLabel)
		{
			while ($tabNum < @currentLabel)
			{
				pop @currentLabel;			
			}
			push @currentLabel, $label;
		}
		else
		{
			die "Error in input at line $line\n";
		}
		
		my $key = (join ":", @currentLabel);
		putIntoHash($key, $value, $simulation[$#simulation]);
	}
	close(INPUTFILE);
	
	# for extra hash ref at the end
	pop @simulation;
}

sub printHeader
{
	my $hashRef = $_[0];
	
	printHash($hashRef, *OUTPUT);
	
	print OUTPUT "\n";
	# grab the resolution formula and put it in, too
	my $foundResolution = 0;
	print OUTPUT "BaseResolutionFormula\n";
	open (SCRIPT, $absoluteScriptName) || die "Can't open own script\n";
	while (<SCRIPT>)
	{
		last if (/----- END BASE RESOLUTION FORMULA -----/);
		print OUTPUT "\t$_" if ($foundResolution);
		$foundResolution = 1 if (/----- START BASE RESOLUTION FORMULA -----/);
	}
	close (SCRIPT);
	
	print OUTPUT "\n";
	print OUTPUT join("\t", "Time Stamp", "Hit?", "Base Damage", "Damage Reduction", "Net Damage", "Running DPS", "Running DPM", "Running Hit Rate", "Total Damage Done"), "\n";
}

# ======================================================================
# Main
# ======================================================================

if (@ARGV == 2 && $ARGV[0] =~ /--template/i)
{
	shift;
	my $templateFile = shift;
	open (TEMPLATE, ">$templateFile") || die "cannot open $templateFile\n";
	print TEMPLATE $template;
	close (TEMPLATE);
	die "Created template.\n";
}

usage() if (@ARGV != 1);

$inputFile = shift;

parseInput();

while (@simulation)
{
	my @summaryInfo;
	my $hashRef = shift @simulation;
	print "Running simulation for ", $hashRef->{"Label"}, "\n";
	$outputFile = "FOMCS_";
	$outputFile .= $hashRef->{"Label"};
	$outputFile =~ s/\s+/_/g;

	open (OUTPUT, ">$outputFile.detailed") || die "cannot open $outputFile.detailed for output\n";
	
	printHeader($hashRef);
	
	my $incrementAttribute = (exists $hashRef->{"IncrementAttribute"}->{"Attribute"}) ? $hashRef->{"IncrementAttribute"}->{"Attribute"} : "";
	my $incrementValue     = (exists $hashRef->{"IncrementAttribute"}->{"IncrementValue"}) ? $hashRef->{"IncrementAttribute"}->{"IncrementValue"} : 0;
	my $maxValue           = (exists $hashRef->{"IncrementAttribute"}->{"MaxValue"}) ? $hashRef->{"IncrementAttribute"}->{"MaxValue"} : 1;
	my $tick = $hashRef->{"Attacker"}->{"WeaponStats"}->{"RateOfFire"};
	
	die "Cannot find $incrementAttribute in input!\n" if ($incrementAttribute ne "" && !defined getFromHash($incrementAttribute, $hashRef));
	
	while (1)
	{
		my $timeStamp = 0;
		my $damageTotal = 0;
		my $hitRate = 0;
		push @summaryInfo, [getFromHash($incrementAttribute, $hashRef), 0, 0, 0, 0, 0, 0, 0] if ($incrementAttribute ne "");

		for (my $simNum = 1; $simNum <= $hashRef->{"NumberOfRounds"}; $simNum++)
		{
			my @hit = calculateHit($hashRef);
			
			my $oldTime = $timeStamp;
			# calculate any necessary speed mods
			my $speedMod = (exists $hashRef->{"Attacker"}->{"CombatSkillMods"}->{"SpeedMod"}) ? $hashRef->{"Attacker"}->{"CombatSkillMods"}->{"SpeedMod"} : 0;
			my $basePower = 0.985;
			my $scale = 1.1;
			$timeStamp += ($tick * ((($basePower**$speedMod) + $scale) / ($scale + 1.0)));

			++$hitRate if ($hit[0]);
			$damageTotal += $hit[1];
			my $armorReduction = ($hit[1] * ($hashRef->{"Defender"}->{"ArmorStats"}->{"Effectiveness"} / 10000.0));

			print OUTPUT join("\t", $oldTime, $hit[0], $hit[1], $armorReduction, ($hit[1] - $armorReduction), ($damageTotal / $timeStamp), ($damageTotal / $timeStamp / 60.0), ($hitRate / $simNum), $damageTotal), "\n";
			
			if ($incrementAttribute ne "")
			{
				$summaryInfo[$#summaryInfo]->[1] += ($hit[1] / $hashRef->{"NumberOfRounds"});
				$summaryInfo[$#summaryInfo]->[2] += ($armorReduction / $hashRef->{"NumberOfRounds"});
				$summaryInfo[$#summaryInfo]->[3] += (($hit[1] - $armorReduction) / $hashRef->{"NumberOfRounds"});
				
				if ($simNum == $hashRef->{"NumberOfRounds"})
				{
					$summaryInfo[$#summaryInfo]->[4] = ($damageTotal / $timeStamp);
					$summaryInfo[$#summaryInfo]->[5] = ($damageTotal / $timeStamp / 60.0);
					$summaryInfo[$#summaryInfo]->[6] = ($hitRate / $simNum);
					$summaryInfo[$#summaryInfo]->[7] = $damageTotal;
				}
			}
		}
		print OUTPUT "\n";
		
		last if ($incrementAttribute eq "");
		
		print "Completed for $incrementAttribute ", getFromHash($incrementAttribute, $hashRef), "\n";

		if (getFromHash($incrementAttribute, $hashRef) <= ($maxValue - $incrementValue))
		{
			putIntoHash($incrementAttribute, ($incrementValue + getFromHash($incrementAttribute, $hashRef)), $hashRef);
		}
		else
		{
			last;
		}
	}
	close (OUTPUT);
	print "\n";
	
	if ($incrementAttribute ne "")
	{
		# output the summary
		open (SUMMARY, ">$outputFile.summary") || die "Cannot open $outputFile.summary\n";
		print SUMMARY join("\t", $incrementAttribute, "Av. Base Damage", "Av. Damage Red.", "Av. Net Damage", "DPS", "DPM", "Hit Rate", "Total Damage"), "\n";
		foreach my $elem (@summaryInfo)
		{
			print SUMMARY (join "\t", @{$elem}), "\n";
		}
		close (SUMMARY);
	}
}

print "Done.\n";