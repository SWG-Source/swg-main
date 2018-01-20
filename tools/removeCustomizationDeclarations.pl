# Purpose: remove customization declarations from shared object templates.
#          Handle p4 checkouts of TPFs requiring changes and do a templatecompile on them.
#
# Strategy:
#
# * Make deletions at the line level: either a whole line stays or gets deleted.
# * Identify lines for removal.
#   * Line removal starts when we see "paletteColorCustomizationVariables = [" or "rangedIntCustomizationVariables = [".
#   * Line remove ends when we hit a line that doesn't match "[variableName=".
#
# * P4 handling.
#
#   * Two passes over the file.  First one is read-only pass where we scan for "paletteColorCustomizationVariables"
#     or "rangedIntCustomizationVariables".
#   * If first pass find a match on any line, start an edit pass.  Edit pass does this:
#     * Does a p4 edit on the tpf and iff.  Die if unsuccessful.
#     * Generates new file contents to a temporary file.
#     * Closes the temporary file.
#     * Renames the temporary file to the p4 file.
#     * Does a templateCompiler -compile on the new file.

use strict;

use Cwd;
use File::Find;
use File::Spec;
use File::Temp;

# =====================================================================

(@ARGV > 0) or die "Usage: perl removeCustomizationDeclarations.pl <TPF directory> [<TPF directory> ...]\n";

# =====================================================================

my $debug = 0;

my $checkedFileCount = 0;
my $changedFileCount = 0;

my $newTotalBytes = 0;
my $savedBytes    = 0;

my $p4EditRetryCount = 10;

# =====================================================================

sub doesFileNeedModification
{
    my $tpfFileName = shift;

    # Looks like the base must have this.
    if ($tpfFileName =~ m/shared_tangible_base\.tpf$/)
    {
	return 0;
    }

    my $inputFile;
    open($inputFile, "< " . $tpfFileName) or die "Failed to open [$tpfFileName] for reading: $!";

    my $foundMatch = 0;

    while (<$inputFile>)
    {
	++$foundMatch if (m/(paletteColorCustomizationVariables|rangedIntCustomizationVariables)\s*=/);
    }

    close($inputFile) or die "Failed to close file [$tpfFileName]: $!";

    ++$checkedFileCount;

    return ($foundMatch > 0);
}

# ----------------------------------------------------------------------

sub getIffFileName
{
    my $iffFileName = shift;
    $iffFileName =~ s!/dsrc/!/data/!;
    $iffFileName =~ s!\.tpf$!.iff!;

    return $iffFileName;
}

# ----------------------------------------------------------------------

sub p4EditFile
{
    my $fileName     = shift;
    my $attemptCount = 0;

    # Do a p4 edit on the file.
    do
    {
	++$attemptCount;
	my $commandResult = `p4 edit $fileName`;
	print "p4 edit $fileName: $commandResult\n" if $debug;
    } while (($? != 0) && ($attemptCount < $p4EditRetryCount));

    die "Failed to run p4 edit on $fileName, tried $attemptCount times: [$?]" if ($? != 0);
}

# ----------------------------------------------------------------------

sub removeCustomizationDeclarations
{
    # Get args.
    my $tpfFileName = shift;
    my $iffFileName = shift;

    # Find directory name of tpf.
    my ($tpfVolumeName, $tpfDirName, $unusedFileName) = File::Spec->splitpath($tpfFileName);
    my $tempFileDir = File::Spec->catpath($tpfVolumeName, $tpfDirName, "");
    print "tempFileDir=$tempFileDir\n" if $debug;

    # Create the tempfile.
    my ($outputFile, $outputFileName) = File::Temp::tempfile(DIR => $tempFileDir);
    die "failed to create tempfile: $!" if !defined($outputFile);

    # Open the tpf file for reading.
    my $inputFile;
    open($inputFile, "< " . $tpfFileName) or die "failed to open tpf file [$tpfFileName] for reading: $!";

    my $skipLines = 0;

    # Process the TPF
    while (<$inputFile>)
    {
	chomp();

	# Determine if we should be skipping lines.
	if (!$skipLines)
	{
	    # Check if we should start skipping lines.
	    $skipLines = m/(?:paletteColorCustomizationVariables|rangedIntCustomizationVariables)\s*=/;
	}
	else
	{
	    # Check if should keep skipping lines.
	    $skipLines = m/\[variableName\s*=/;
	}
	
	print $outputFile "$_\n" if !$skipLines;
	print "DEL: $_\n" if $skipLines && $debug;
    }

    # Close up.
    close($inputFile) or die "failed to close tpf file [$tpfFileName]: $!";
    close($outputFile) or die "failed to close temp output file [$outputFileName]: $!";

    # Rename modified file to tpf file.
    rename($outputFileName, $tpfFileName) or die "failed to rename modified tpf file [$outputFileName] to [$tpfFileName]: $!";

    ++$changedFileCount;
}

# ----------------------------------------------------------------------

sub compileTpf
{
    my $tpfFileName = shift;
    my $output = `TemplateCompiler -compile $tpfFileName`;
    die "failed to compile $tpfFileName: $output" if ($? != 0);
    print "TemplateCompiler -compile $tpfFileName: $output\n" if $debug;
}

# ----------------------------------------------------------------------

sub filenameProcessor
{
    # Check if target is a file, is readable and is a TPF.
    if (-f and -r and m/\.tpf$/i)
    {
	# Process the file.
	my $tpfFileName = $File::Find::name;
	print "Processing file [$tpfFileName].\n" if $debug;

	# Check if the file needs to be modified.
	if (doesFileNeedModification($tpfFileName))
	{
	    print "Modifying [$tpfFileName].\n";

	    # Get the iff filename for the given tpf filename.
	    my $iffFileName = getIffFileName($tpfFileName);

	    # Get stats for the original iff file.
	    my @originalStats = stat $iffFileName;

	    # Open files for edit.
	    p4EditFile($tpfFileName);
	    p4EditFile($iffFileName);

	    # Remove the customization-related entries.
	    removeCustomizationDeclarations($tpfFileName, $iffFileName);

	    # Compile the tpf into the iff.
	    compileTpf($tpfFileName);

	    # Get stats for the modified iff file.
	    my @modifiedStats = stat $iffFileName;

	    # Update statistics.
	    $newTotalBytes += $modifiedStats[7];
	    $savedBytes    += ($originalStats[7] - $modifiedStats[7]);
	}
    }
}

# ----------------------------------------------------------------------

my @dirs;

foreach my $dir (@ARGV)
{
    push @dirs, Cwd::abs_path($dir);
}

File::Find::find(\&filenameProcessor, @dirs);

print "Statistics:\n";
print  "\tfiles checked:   $checkedFileCount\n";
print  "\tfiles modified:  $changedFileCount\n";
printf "\tmodified size:   %.2f KB\n", $newTotalBytes / (1024);
printf "\treduced size by: %.2f KB\n", $savedBytes / (1024);

# =====================================================================
