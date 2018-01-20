# ======================================================================
#
# moveUpOrAddAttribute.pl
#
# Copyright 2001 Sony Online Entertainment Inc.
# All Rights Reserved.
# 
# PURPOSE (object template .tpf file utility):
#
#   If a given attribute exists for a specified class, move the attribute
#   from the old class into the new class.  The new class must be higher
#   up (more general) in the class hierarchy.  If the given attribute
#   doesn't exist, add (or replace) it with the given default value in the 
#   new class section.  If the new class section doesn't exist, create
#   the new class section.
#
# SYNTAX:
#
#   perl moveUpOrAddAttribute.pl <tpf filename> <old class name> <new class name> <attribute name> <default value>
# 
# ======================================================================

# check for proper argument count
if (scalar(@ARGV) != 5)
{
	die "syntax: perl moveUpOrAddAttribute.pl <tpf filename> <old class name> <new class name> <attribute name> <default value>\n";
}

# states
$SCAN_OUTSIDE   = 1;
$SCAN_OLD_CLASS = 2;
$SCAN_NEW_CLASS = 3;
$COPY_REMAINDER = 4;

# open source tpf file
$sourcePathname = $ARGV[0];
open (SOURCE, $sourcePathname) or die "failed to open source filename for reading [$sourcePathname]\n";

# open temp work filename
$destPathname = $sourcePathname . '.tmp';
open (DEST, '>' . $destPathname) or die "failed to open dest filename for writing [$destPathname]\n";

# initialize state
$oldClassName   = $ARGV[1];
$newClassName   = $ARGV[2];
$attributeName  = $ARGV[3];

$currentState   = $SCAN_OUTSIDE;
$writeValue     = $ARGV[4];

# process each line from source file
while (<SOURCE>)
{
	SWITCH:
	{
		if ($currentState == $SCAN_OUTSIDE)
			{
				# check for new states
				if (/^\@class $oldClassName/)
				{
					$currentState = $SCAN_OLD_CLASS;
				}
				elsif (/^\@class $newClassName/)
				{
					$currentState = $SCAN_NEW_CLASS;
				}

				# always copy input
				print DEST;

				last SWITCH;
			}

		if ($currentState == $SCAN_OLD_CLASS)
			{
				# check for new states
				if (/^$attributeName\s=\s(.*)$/)
				{
					# found the old attribute, save its setting.
					# do not emit the attribute in the new file (we're moving it)
					$writeValue = $1;
				}
				else
				{
					# for all other input, we do copy the input
					if (/^\@class\s(.*)\s$/)
					{
						# we're in the old class, moving to a new class
						if ($1 eq $newClassName)
						{
							$currentState = $SCAN_NEW_CLASS;
						}
						else
						{
							$currentState = $SCAN_OUTSIDE;
						}
					}

					# copy the input
					print DEST;
				}
				last SWITCH;
			}

		if ($currentState == $SCAN_NEW_CLASS)
			{
				if (/^$attributeName\s=/)
				{
					# found the attribute in the new class, replace it.
					# do not emit the attribute in the new file (we're moving it)

					print DEST "$attributeName = $writeValue\n";
					
					# we're done, copy the rest
					$currentState = $COPY_REMAINDER;
				}
				else
				{
					# for all other input, we do copy the input

					if (/^\@class\s/)
					{
						# we're moving to a new class, need to inject the attribute since it hasn't appeared yet.
						print DEST "$attributeName = $writeValue\n\n";

						# we're done, copy the rest
						$currentState = $COPY_REMAINDER;
					}

					# copy the input
					print DEST;
				}

				last SWITCH;
			}

		if ($currentState == $COPY_REMAINDER)
			{
				# always copy input
				print DEST;

				last SWITCH;
			}

		die "unknown state $currentState\n";
	}
}

# let all states deal with the end-of-source-file event
{
	SWITCH:
	{
		if ($currentState == $SCAN_OUTSIDE)
			{
				# print missing class and attribute
				print DEST "\n\@class $newClassName\n$attributeName = $writeValue\n";

				last SWITCH;
			}
		if ($currentState == $SCAN_OLD_CLASS)
			{
				# print missing class and attribute
				print DEST "\n\@class $newClassName\n$attributeName = $writeValue\n";

				last SWITCH;
			}
		if ($currentState == $SCAN_NEW_CLASS)
			{
				# print missing attribute
				print DEST "$attributeName = $writeValue\n";

				last SWITCH;
			}
		if ($currentState == $COPY_REMAINDER)
			{
				# nothing to do
				last SWITCH;
			}

		die "unknown state $currentState\n";
	}
}

# close the source and dest file
close SOURCE;
close DEST;

# rename dest filename to source filename, clobbering the original source
rename $destPathname, $sourcePathname
