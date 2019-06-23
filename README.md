# SWGSource V2.0 Build Instructions

## Credit
Credit the StellaBellum team (DarthArgus, Cekis, SilentGuardian, Ness, SwgNoobs, DevCodex) for making their repositories open.  All source is forked from
those repositories and progressed from that point.

## What Do You Need To Do To Get A Server Running?

Most of what is contained in this section assumes you're running a Linux base VM - specifically Debian.  It is assumed your home directory is /home/swg.

Download the main repo:

		cd /home/swg
		git clone https://github.com/SWG-Source/swg-main.git

When the GIT repository has been cloned successfully, open the swg-main directory:

		cd /home/swg/swg-main

## Building
### Requirements
- Java 8 (1.8_u101)
- Apache ANT 1.9+

First and foremost, IF YOU DO NOT HAVE ANT INSTALLED ALREADY, you'll need to install Apache ANT (at least version 1.9) on your VM.  ANT is required for the build process to run successfully.  ANT
will be included in the next VM build, but for now here are the steps to do so manually:

1. Go to https://ant.apache.com/download and download the latest version of ANT (1.10.5 is latest as of this writing, but anything over 1.9.x should work fine).
2. Expand the ANT package (.zip or .tar) into your VM (or server) directories somewhere.  Take note of the location where you expanded it.
3. Edit your .profile and add a line that sets the location where you expanded it as ANT_HOME.
4. While you're editing your profile, make sure that JAVA_HOME is set to the right spot too.  You can figure out where Java is installed by using the
"which" command:  ```which java```
5. Save your .profile edits and test out that ANT_HOME is installed properly by typing in "ant" at any location on your command line.  You should get a
non-standard error message about how build.xml is missing.  If JAVA_HOME isn't set correctly, you'll get an error about that too.

### Starting the Build Process
To complete building, kick off the build script from your swg-main directory by typing in: ```ant swg```

The build process is fully configured in the build.properties file.  There is no need to touch this file unless you have a fully customized version that you
would like to run.  For starters, just don't worry about touching it.

You can also run sections of the build script manually (not recommended until you are used to the environment of which you're working in).

#### ANT Usage
DID YOU KNOW?: You can specify multiple ANT targets with a single command as well (this goes for any of these targets you give it).  ANT will execute them and make sure all
of their dependencies are met in the order you provide them:

```
ant git_src git_dsrc
```

#### Final configuration:

After build_linux.sh is finished, you may want to edit your configuration to turn off/on planets and other zones. The configuration files will be located at `/home/swg/swg-main/exe/linux/` NOT at `/home/swg/swg-main/configs`. (Those are just the templates for the build script.)

## First Start
To start the server after building, execute the following script:

		./startServer.sh

Point your login.cfg in your game folder (on your client machine, NOT the VM) to the IP address of the Virtual Machine such that you can connect successfully.

AND YOU'RE DONE!

#MORE READING...

The following targets ARE NOT REQUIRED, but you may find yourself wanting to build certain parts of the dsrc individually instead of all at once as done in the
ANT build script. Here is some information about the specific targets in ANT build file:

#### Compiling the mIFF files
The "compile_miff" target will compile all *.mif files into *.iff binary files.

		```ant compile_miff```

#### Compiling the Datatable files
The "compile_tab" target will compile all the *.tab files into *.iff binary files:

		```ant compile_tab```

#### Compiling Template Files
The "compile_tpf" target will compile all the *.tpf files into *.iff binary files:

		```ant compile_tpf```

If you have built the TPF files in this step (i.e. you didn't skip this step) then the target will also attempt to recreate the Object Template and Quest CRC
tables and subsequently will attempt to push those changes to the database since this will also be required.  A GREAT feature to have when creating new template files
or changing existing ones.

Again... if you wish to do a multiple of these things, you can string multiple targets together like so (not all 3 are required and they can be added in any order as
ANT handles any dependencies already):

```ant compile_miff compile_tab compile_tpf```

This particular command will first build the MIFF files, then compile the TAB files, then compile and load the Template Files into the database.

### Database Phase
#### Building Object Template and Quest CRC Files
This step will compile the object template and quest CRC files.  These files translate the long name of these files (including file path) into a very short code that
allows the server to identify them without the danger of long text being transferred over the internet in packets.  Basically an optimization that SOE implemented:

		```ant load_templates```

Building these files will also trigger the target to then populate the database with the CRC's that were generated.  If you are doing this target in pieces
(i.e. you're selectively building), this is a GREAT way to re-import new or changed TPF file changes.  In order to re-import CRC's into the database, if you haven't
already entered it above, it will ask you for the database information here.
