use Cwd;
use strict;
use ConfigFile;
use Perforce;
use TreeFile;

my $debug     = 1;
my $justPrint = 0;

# Grab branch from commandline, default to current.
my $branch = shift;
$branch = 'current' if !defined($branch);
print "branch: $branch\n" if $debug;

# Grab p4 changelist number for treefile.
my $p4ChangelistOutput = `p4 changes -m1 //depot/swg/$branch/data/...#have`;
my $p4ChangelistNumber = $1 if ($p4ChangelistOutput =~ m/\s*Change\s*(\d+)/) || die "Failed to find changelist number";
print "changelist number: $p4ChangelistNumber\n" if $debug;

# Construct config file common.cfg file location.  We just need the loose-file treefile paths.
my $configPathName = Perforce::findOnDiskFileName("//depot/swg/$branch/exe/win32/client.cfg");
$configPathName =~ s!\\!/!g;
print "config file pathname: [$configPathName]\n" if $debug;

# Setup ConfigFile.
ConfigFile::processConfigFile($configPathName) if !$justPrint;

# Build treefile map pathname, places it in current directory.
my $treefileLookupPathName = getcwd();
$treefileLookupPathName .= '/' if !($treefileLookupPathName =~ m!/$!);
$treefileLookupPathName .= "treefile-xlat-$branch-$p4ChangelistNumber.dat";
print "treefile lookup pathname: [$treefileLookupPathName]\n" if $debug;

# Open treefile map filehandle.
my $fileHandle;
die "could not open treefile handle: $!" if !($justPrint || open($fileHandle, "> " . $treefileLookupPathName));

# Construct rooted directory path for relative treefile searchpath locations.
# Just chop off everything after and including the last slash in the config pathname.
my $rootedBaseSearchPath = $configPathName;
$rootedBaseSearchPath =~ s!/[^/]+$!!;
print "treefile rooted base searchpath: [$rootedBaseSearchPath]\n" if $debug;

# Build the TreeFile map file.
TreeFile::buildFileLookupTable(1, $rootedBaseSearchPath) if !$justPrint;

# Save the TreeFile map file.
TreeFile::saveFileLookupTable($fileHandle) if !$justPrint;

# Close the map file.
die "could not close treefile handle: $!" if !($justPrint || close($fileHandle));

print "Done.\n" if $debug;
