###################################################
#
# createClientOTs.pl
# authored by Eric Sebesta (esebesta@soe.sony.com
#
# Purpose: When run in a directory, it generates, and submits to
#          perforce a basic set of object templates (client and server
#          based on the files in the directory, which must be appearances.
#          The user must pass in client and server tdf files so that we can
#          generate object templates appropriate for the given appearances.
#
###################################################

use Cwd;

#initialize an array with all the possible extensions a valid appearance would have
#we use this array to check that a given file is actually an appearance
@appearanceExtensions = (".lod", ".cmp", ".msh", ".sat");

#the template compiler must be run from the area where the tpf files should live, so make
#sure they are in a currently accepted location for them
$requiredSourceDir = "plt.shared\loc.shared\compiled\game\object";
$requiredSourceDirFront = "plt.shared/loc.shared/compiled/game/object";

#users must pass in 2 parameters, the appearance directory and the tdf file used to generate the tpfs
if (scalar(@ARGV) != 2)
{
    die "usage: createClientOTs <appearance directory> <TDF> \nRequire 2 parameters, received $numArgs\n";
}

#if(!cwd() =~ "sys.client")
#{
#	die "must be in client template directory!\n";
#}

#TODO this isn't working?
#check the current directory against the required ones
if(!cwd() =~ $requiredSourceDir)
{
    if(!cwd() =~ $requiredSourceDirFront)
    {
        print "not in correct dir, must be in dsrc\"\\<blah blah blah>\\game\\object\" or below\n";
        die;
    }
}

#get the various command line parameters
my $appearanceDir = $ARGV[0];
print "appearance directory is $appearanceDir\n";

$TDF = $ARGV[1];
print "Tdf is $TDF\n";

#we're all done with initial listing, delimite with a line
print "\n";

#make sure the appearance directory exists before proceeding, since we'll want to open all those files
-e $appearanceDir or die "ERROR: appearance directory does not compute, I mean exist\n";

#read the files from the current directory
opendir CURRENTDIR, $appearanceDir or die "ERROR: can't read current directory, bad: $1";
my @files = readdir CURRENTDIR;
closedir CURRENTDIR;

#process each file, building, editing, compiling, and submitting the tpf and iff file
foreach $file (@files)
{
  print "processing $file...\n";

  #validate that the current file is an appearance
  my $found = 0;
  foreach $ext (@appearanceExtensions)
  {
    if($file =~ /$ext/)
    {
      $found = 1;
    }
  }
  if($found == 0)
  {
    print "  WARNING: not an appearance file, skipping\n"
  }

  #okay, the file exists and is an appearance, and we are in a directory to drop tpf's into, go for it

  createOT($file);

  #one line seperator between files
  print "\n";
}

############################################################################
sub createOT     #11/08/01 10:58:AM
############################################################################
{
  #the new client template name is passed in as a parameter
  my $appearanceFileName = @_[0];

  #turn the filename into a short client template name (i.e. remove any pathing info and remove the extension)
  $appearanceFileName =~ m/^(.*)\./;
  my $base = $1;

  my @args = ("templateCompiler", "-generate", $TDF, $base);
  print "@args...";
  if(system(@args) != 0)
  {
    print "\ncouldn't run templatecompiler for template, skipping)";
    return;
  }
  else
  {
    print "success\n";
  }

  #now get the actual tpf filename
  my $templateFileName = $base . ".tpf";

  #the base template has been generated, now fill in the appearance name
  my $TEMPLATE = $templateFileName;
  if (-e $TEMPLATE)
  {
    #build the new line we want to write (the new appearance name)
    my $newLine = "appearanceFilename = \"appearance\\" . $appearanceFileName . "\"\n";
    #open the new tpf file for read, so we can set the appearance name
    open (TEMPLATE, '<' . $templateFileName) or die "failed to open original tpf file for editing\n";
    #open a temporary file for us to write the new contents into
    my $tempPathname = $templateFileName . '.tmp';
    open (TEMP, '>' . $tempPathname) or die "failed to open dest filename for writing [$destPathname]\n";

    #search the tpf the appearance line
    while ($line = <TEMPLATE>)
    {
        if($line =~ "appearanceFilename = ")
        {
            #output our new line with the appearance name
            print TEMP $newLine;
        }
        else
        {
          #otherwise, write back out the original contents
          print TEMP $line;
        }
    }
    #close all filehandles
    close TEMPLATE;
    close TEMP;

    # rename dest filename to source filename, clobbering the original source
    rename $tempPathname, $templateFileName;
  }
  else
  {
    print "\ncouldn't client template file does not exist, skipping....\n";
    return;
  }

  @args = ("templateCompiler", "-compile", $templateFileName);
  print "@args...";
  if(system(@args) != 0)
  {
    print "\ncouldn't run templatecompiler -compile for template, skipping)";
    return;
  }
  else
  {
    print "success\n";
  }

  @args = ("templateCompiler", "-submit", $templateFileName);
  print "@args...";
  print "not run\n";
  #if(system(@args) != 0)
  #{
  #  print "couldn't run templatecompiler -submit for client template, skipping)";
  #  return;
  #}
  #else
  #{
  #  print "success\n";
  #}
}  ##createOT

