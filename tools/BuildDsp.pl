#!/usr/bin/perl
# =====================================================================

# figure out what project file we're building
$project = $ARGV[0];
die "no project name specified" if (!defined($project));

# lop off the directories
$project =~ s#^.*[/\\]##;

# lop off the extension
$project =~ s#\.dsp$##;

# capitalize the first letter of the string
$Project = $project;
substr($Project,0,1) =~ tr/a-z/A-Z/;

# get the directory path, paths need to be relative to the project files
$directory = $ARGV[0];
if ($directory =~ s#[/\\][^/\\]+$## != 0)
{
	chdir($directory) || die "could not change into directory ". $directory;
}

# =====================================================================

# setup defaults
@defines_debug      = ("WIN32", "_DEBUG", "_MBCS", "DEBUG_LEVEL=2");
@defines_optimized  = ("WIN32", "_DEBUG", "_MBCS", "DEBUG_LEVEL=1"); 
@defines_release    = ("WIN32", "NDEBUG", "_MBCS", "DEBUG_LEVEL=0");

$fixQt = 0;

$optimizedOptimizations = " /Ox /Ot /Og /Oi /Oy-";
$dbgInfo_d = makeDebugInfoFlag("pdb");
$dbgInfo_o = makeDebugInfoFlag("pdb");
$dbgInfo_r = makeDebugInfoFlag("pdb");
$minimalRebuild = " /Gm";

# =====================================================================
# process RSP files

open(RSP, "settings.rsp") || die "could not open settings.rsp for " . $project . ", ";
while (<RSP>)
{
	# handle comments
	s/#.*//;

	foreach (split)
	{
		if ($_ eq "windows")
		{
			$output = $template_windows;
			push(@defines_debug,      "_WINDOWS");
			push(@defines_optimized,  "_WINDOWS");
			push(@defines_release,    "_WINDOWS");
		}
		elsif ($_ eq "mfc")
		{
			$output = $template_mfc;
			push(@defines_debug,      "_WINDOWS");
			push(@defines_optimized,  "_WINDOWS");
			push(@defines_release,    "_WINDOWS");
		}
		elsif ($_ eq "qt334")
		{
			$output = $template_windows;
			push(@defines_debug,      "_WINDOWS", "QT_DLL", "QT_NO_STL", "QT_ACCESSIBILITY_SUPPORT");
			push(@defines_optimized,  "_WINDOWS", "QT_DLL", "QT_NO_STL", "QT_ACCESSIBILITY_SUPPORT");
			push(@defines_release,    "_WINDOWS", "QT_DLL", "QT_NO_STL", "QT_ACCESSIBILITY_SUPPORT");
			$qt_version = "3.3.4";
			$fixQt = 1;
		}
		elsif ($_ eq "qt410" || $_ eq "qt")
		{
			$output = $template_windows;
			push(@defines_debug,      "_WINDOWS", "QT_DLL", "QT_NO_STL", "QT_ACCESSIBILITY_SUPPORT", "QT3_SUPPORT");
			push(@defines_optimized,  "_WINDOWS", "QT_DLL", "QT_NO_STL", "QT_ACCESSIBILITY_SUPPORT", "QT3_SUPPORT");
			push(@defines_release,    "_WINDOWS", "QT_DLL", "QT_NO_STL", "QT_ACCESSIBILITY_SUPPORT", "QT3_SUPPORT");
			$qt_version = "4.1.0";
			$fixQt = 1;
		}
		elsif ($_ eq "console")
		{
			$output = $template_console;
			push(@defines_debug,      "_CONSOLE");
			push(@defines_optimized,  "_CONSOLE");
			push(@defines_release,    "_CONSOLE");
		}
		elsif ($_ eq "library")
		{
			$output = $template_library;

			push(@defines_debug,      "_LIB");
			push(@defines_optimized,  "_LIB");
			push(@defines_release,    "_LIB");
		}
		elsif ($_ eq "utility")
		{
			$output = $template_utility;
		}
		elsif ($_ eq "noPchDirectory")
		{
			$noPchDir = 1;
		}
		elsif ($_ eq "stdafx")
		{
			$stdafx = 1;
		}
		elsif ($_ eq "p4")
		{
			push(@defines_debug,      "CASE_INSENSITIVE", "OS_NT");
			push(@defines_optimized,  "CASE_INSENSITIVE", "OS_NT");
			push(@defines_release,    "CASE_INSENSITIVE", "OS_NT");
		}
		elsif ($_ eq "unicode")
		{
			push(@defines_debug,      "_UNICODE", "UNICODE");
			push(@defines_optimized,  "_UNICODE", "UNICODE");
			push(@defines_release,    "_UNICODE", "UNICODE");
		}
		elsif (s/^Zm//)
		{
			$zm = " /Zm" . $_ . " ";
		}
		elsif (s/^dbgInfo_d_//)
		{
			$dbgInfo_d = makeDebugInfoFlag($_);
		}
		elsif (s/^dbgInfo_o_//)
		{
			$dbgInfo_o = makeDebugInfoFlag($_);
		}
		elsif (s/^dbgInfo_r_//)
		{
			$dbgInfo_r = makeDebugInfoFlag($_);
		}
		elsif (s/^incremental_d_//)
		{
			$incremental_d = " /incremental:" . $_;
		}
		elsif (s/^incremental_o_//)
		{
			$incremental_o = " /incremental:" . $_;
		}
		elsif (s/^incremental_r_//)
		{
			$incremental_r = " /incremental:" . $_;
		}
		elsif (/Gm-/)
		{
			$minimalRebuild = " /Gm-";
		
		}
		elsif ($_ eq "copyDev")
		{
			$copyDev = 1;
		}
		elsif ($_ eq "debugInline")
		{
			$debugInline = " /Ob1";
		}
		elsif ($_ eq "disableOptimizationsInOpt")
		{
		  $optimizedOptimizations = " /Od /Oy-";
		}
		else
		{
			die "unknown option ", $_, "\n";
		}
	}
}
close(RSP);

# read in the includes list
push(@defines_debug,      process_rsp("defines_d.rsp", "defines.rsp"));
push(@defines_optimized,  process_rsp("defines_o.rsp", "defines.rsp"));
push(@defines_release,    process_rsp("defines_r.rsp", "defines.rsp"));

# read in the includes list
@includeDirectories_debug      = process_rsp("includePaths_d.rsp", "includePaths.rsp");
@includeDirectories_optimized  = process_rsp("includePaths_o.rsp", "includePaths.rsp");
@includeDirectories_release    = process_rsp("includePaths_r.rsp", "includePaths.rsp");

# get in the libraries 
@libraries_debug      = process_rsp("libraries_d.rsp", "libraries.rsp");
@libraries_optimized  = process_rsp("libraries_o.rsp", "libraries.rsp");
@libraries_release    = process_rsp("libraries_r.rsp", "libraries.rsp");

# get the libraries to ignore
@ignoreLibraries_debug      = process_rsp("ignoreLibraries_d.rsp", "ignoreLibraries.rsp");
@ignoreLibraries_optimized  = process_rsp("ignoreLibraries_o.rsp", "ignoreLibraries.rsp");
@ignoreLibraries_release    = process_rsp("ignoreLibraries_r.rsp", "ignoreLibraries.rsp");

# get the libraries search directory paths
@libraryDirectories_debug     = process_rsp("libraryPaths_d.rsp", "libraryPaths.rsp");
@libraryDirectories_optimized = process_rsp("libraryPaths_o.rsp", "libraryPaths.rsp");
@libraryDirectories_release   = process_rsp("libraryPaths_r.rsp", "libraryPaths.rsp");


if ($fixQt)
{
	fixup_qt_path(@includeDirectories_debug);
	fixup_qt_path(@includeDirectories_optimized);
	fixup_qt_path(@includeDirectories_release);
	fixup_qt_path(@libraryDirectories_debug);
	fixup_qt_path(@libraryDirectories_optimized);
	fixup_qt_path(@libraryDirectories_release);
	
	fixup_qt_lib(@libraries_debug);
	fixup_qt_lib(@libraries_optimized);
	fixup_qt_lib(@libraries_release);
}


# =====================================================================
# scan the current vcproj looking for per-file settings to preserve

if (open(DSP, $project . ".dsp"))
{
	while (<DSP>)
	{
		s/\r//;
		
		# look for per-file settings to preserve
		if ($state == 1)
		{
			if ($_ eq "# End Source File\n")
			{
				$state = 0;
			}
			else
			{
				$settings{$filename} .= $_;
			}
		}
		if ($state == 0 && s/^SOURCE=//)
		{
			chomp;
			s/^"//;
			s/"$//;
			$filename = $_;
			$state = 1;
		}
	}
	close(DSP);
}

# override the custom build steps for headers that need moc'ed
open(RSP, "mocHeaders.rsp");
while (<RSP>)
{
	chomp;

	# handle comments
	s/#.*//;

	# clean up the input
	s/^\s+//;
	s/\s+$//;
	s#/#\\#g;

	if ($_ ne "")
	{
		# get just the file name
		$name = $_;
		$name =~ s#^.*\\##;
		$name =~ s#\..*$##;
		
		$settings{$_} = $mocHeader;
		$settings{$_} =~ s/%%inputPath%%/$_/g;
		$settings{$_} =~ s/%%inputName%%/$name/g;
	}
}
close(RSP);


# =====================================================================
# 

sub makeDebugInfoFlag
{
  my $input = $_[0];
  local $flag = "";
  local $_;
  
  if ( $input eq "line_numbers_only" )
  {
  	$flag = " /Zd";
  }
  elsif ( $input eq "pdb" )
  {
  	$flag = " /Zi";
  }
  elsif ( $input eq "edit_and_continue" )
  {
  	$flag = " /ZI";
  }
  elsif ( $input eq "none" )
  {
  	$flag = "";
  }
  else
  {
  	die "Unknown setting for dbgInfo: $input\n";
  }

	return $flag;
}

sub fixup_qt_path
{
	foreach (@_)
	{
		s/qt\\[0-9]\.[0-9]\.[0-9]/qt\\$qt_version/;
	}
}

sub fixup_qt_lib
{
	my $qtlibver = $qt_version;
	$qtlibver =~ s/\.//g;
	
	foreach (@_)
	{
		s/qt-mt[0-9][0-9][0-9]/qt-mt$qtlibver/;
	}
}


# =====================================================================
# find all the non-linux source files

sub addfile
{
	my $pathed = $_[0];
	local $_ = $pathed;
	
	# lop off the directories
	s#.*/##;
	s#.*\\##;
	
	if (/\.cpp$/)
	{
		$sourceNames{$_} = $pathed;
	}
	elsif (/\.h$/)
	{
		$headerNames{$_} = $pathed;
	}
	elsif (/\.def$/)
	{
		$headerNames{$_} = $pathed;
		$settings{$pathed} = "# PROP Exclude_From_Build 1\n";
	}
	elsif (/\.ui$/)
	{
		$uiNames{$_} = $pathed;

		$settings{$pathed} = $ui;
		$settings{$pathed} =~ s/%%inputPath%%/$pathed/g;
		$noExt = $_;
		$noExt =~ s/\.ui$//;
		$settings{$pathed} =~ s/%%inputName%%/$noExt/g;
	}
	elsif (/\.template$/)
	{
		$templateNames{$_} = $pathed;
	}
	elsif (/\.rc$/)
	{
		$resourceNames{$_} = $pathed;
	}
	elsif (/\.ico$/ || /\.cur$/ || /\.bmp$/)
	{
		$resourceNames{$_} = $pathed;
	}
}

sub dodir
{
	local $_;
	my $dir = $_[0];
	
	opendir(DIR, $dir) || return;
	my @filenames = readdir(DIR);
	closedir(DIR);
	
	for (@filenames)
	{
		next if $_ eq ".";
		next if $_ eq "..";

		$pathed = $dir . "\\" . $_;
		
		if (-d $pathed)
		{
			next if ($_ eq "linux");
			next if ($_ eq "solaris");
			&dodir($pathed);
		}
		else
		{
			&addfile($pathed);
		}
	}
}
&dodir("..\\..\\src");
&dodir("..\\..\\src_oci");
&dodir("..\\..\\src_odbc");
&dodir("..\\..\\ui");

# get any additional files to include in the build
open(RSP, "additionalFiles.rsp");
while (<RSP>)
{
	# handle comments
	s/#.*//;

	chomp;
	s/\s+$//;
	&addfile($_) if ($_ ne "");
}
close(RSP);

# =====================================================================
# process all the source files

# Make sure all First*.cpp projects build the PCH

$_ = $settings{$sourceNames{"First$Project.cpp"}};

if (! /.*\/Yc.*/ )
{
	$settings{$sourceNames{"First$Project.cpp"}} = $_ . "\n# ADD CPP /Yc\n";
}

foreach (sort { lc($a) cmp lc($b) } keys %sourceNames)
{
	$_ = $sourceNames{$_};
	$sources .= "# Begin Source File\n\nSOURCE=$_\n$settings{$_}# End Source File\n";
}

foreach (sort { lc($a) cmp lc($b) } keys %headerNames)
{
	$_ = $headerNames{$_};
	$headers .= "# Begin Source File\n\nSOURCE=$_\n$settings{$_}# End Source File\n";
}

foreach (sort { lc($a) cmp lc($b) } keys %resourceNames)
{
	$_ = $resourceNames{$_};
	$resources .= "# Begin Source File\n\nSOURCE=$_\n$settings{$_}# End Source File\n";
}

foreach (sort { lc($a) cmp lc($b) } keys %templateNames)
{
	$_ = $templateNames{$_};
	$templates .= "# Begin Source File\n\nSOURCE=$_\n$settings{$_}# End Source File\n";
}

foreach (sort { lc($a) cmp lc($b) } keys %uiNames)
{
	$_ = $uiNames{$_};
	$uis .= "# Begin Source File\n\nSOURCE=$_\n$settings{$_}# End Source File\n";

	s/^.*[\\\/]//;
	s/\.ui$//;

	$uiGeneratedSources_debug      .= "# Begin Source File\n\nSOURCE=..\\..\\..\\..\\..\\..\\compile\\win32\\%%project%%\\Debug\\${_}_d.cpp\n$debug_ui_cpp# End Source File\n";
	$uiGeneratedHeaders_debug      .= "# Begin Source File\n\nSOURCE=..\\..\\..\\..\\..\\..\\compile\\win32\\%%project%%\\Debug\\$_.h\n# End Source File\n";
	$uiGeneratedSources_optimized  .= "# Begin Source File\n\nSOURCE=..\\..\\..\\..\\..\\..\\compile\\win32\\%%project%%\\Optimized\\${_}_o.cpp\n$optimized_ui_cpp# End Source File\n";
	$uiGeneratedHeaders_optimized  .= "# Begin Source File\n\nSOURCE=..\\..\\..\\..\\..\\..\\compile\\win32\\%%project%%\\Optimized\\$_.h\n# End Source File\n";
	$uiGeneratedSources_release    .= "# Begin Source File\n\nSOURCE=..\\..\\..\\..\\..\\..\\compile\\win32\\%%project%%\\Release\\${_}_r.cpp\n$release_ui_cpp# End Source File\n";
	$uiGeneratedHeaders_release    .= "# Begin Source File\n\nSOURCE=..\\..\\..\\..\\..\\..\\compile\\win32\\%%project%%\\Release\\$_.h\n# End Source File\n";
}

# =====================================================================
# set up the replacements

# setup the replacement strings
$replace{"%%project%%"}                        = $project;
$replace{"%%sources%%\n"}                      = $sources;
$replace{"%%headers%%\n"}                      = $headers;
$replace{"%%resources%%\n"}                    = $resources;
$replace{"%%templates%%\n"}                    = $templates;
$replace{" %%debugInline%%"}                   = $debugInline;
$replace{" %%dbgInfo_r%%"}                     = $dbgInfo_r;
$replace{" %%dbgInfo_o%%"}                     = $dbgInfo_o;
$replace{" %%dbgInfo_d%%"}                     = $dbgInfo_d;
$replace{" %%incremental_r%%"}                 = $incremental_r;
$replace{" %%incremental_o%%"}                 = $incremental_o;
$replace{" %%incremental_d%%"}                 = $incremental_d;
$replace{" %%minimalRebuild%%"}                = $minimalRebuild;
$replace{" %%optimizedOptimizations%%"}        = $optimizedOptimizations;
$replace{" %%zm%%"}                            = $zm;
$replace{" %%includeDirectories_debug%%"}      = explode("/I \"", "\"", @includeDirectories_debug);
$replace{" %%includeDirectories_optimized%%"}  = explode("/I \"", "\"", @includeDirectories_optimized);
$replace{" %%includeDirectories_release%%"}    = explode("/I \"", "\"", @includeDirectories_release);
$replace{" %%defines_debug%%"}                 = explode("/D \"", "\"", @defines_debug);
$replace{" %%defines_optimized%%"}             = explode("/D \"", "\"", @defines_optimized);
$replace{" %%defines_release%%"}               = explode("/D \"", "\"", @defines_release);
$replace{" %%libraries_debug%%"}               = explode("", "", @libraries_debug);
$replace{" %%libraries_optimized%%"}           = explode("", "", @libraries_optimized);
$replace{" %%libraries_release%%"}             = explode("", "", @libraries_release);
$replace{" %%libraryDirectories_debug%%"}      = explode("/libpath:\"", , "\"", @libraryDirectories_debug);
$replace{" %%libraryDirectories_optimized%%"}  = explode("/libpath:\"", , "\"", @libraryDirectories_optimized);
$replace{" %%libraryDirectories_release%%"}    = explode("/libpath:\"", , "\"", @libraryDirectories_release);
$replace{" %%ignoreLibraries_debug%%"}         = explode("/nodefaultlib:\"", , "\"", @ignoreLibraries_debug);
$replace{" %%ignoreLibraries_optimized%%"}     = explode("/nodefaultlib:\"", , "\"", @ignoreLibraries_optimized);
$replace{" %%ignoreLibraries_release%%"}       = explode("/nodefaultlib:\"", , "\"", @ignoreLibraries_release);

$replace{"%%uis%%"}                            = $uis;
$replace{"%%uiGeneratedSources_debug%%"}       = $uiGeneratedSources_debug;
$replace{"%%uiGeneratedHeaders_debug%%"}       = $uiGeneratedHeaders_debug;
$replace{"%%uiGeneratedSources_optimized%%"}   = $uiGeneratedSources_optimized;
$replace{"%%uiGeneratedHeaders_optimized%%"}   = $uiGeneratedHeaders_optimized;
$replace{"%%uiGeneratedSources_release%%"}     = $uiGeneratedSources_release;
$replace{"%%uiGeneratedHeaders_release%%"}     = $uiGeneratedHeaders_release;

$replace{"%%qt_version%%"}                     = $qt_version;

if ($copyDev)
{
	$replace{"%%specialBuildTool_release%%\n"}    = $specialBuildTool_release;
	$replace{"%%specialBuildTool_optimized%%\n"}  = $specialBuildTool_optimized;
	$replace{"%%specialBuildTool_debug%%\n"}      = $specialBuildTool_debug;
}
else
{
	$replace{"%%specialBuildTool_release%%\n"}    = "";
	$replace{"%%specialBuildTool_optimized%%\n"}  = "";
	$replace{"%%specialBuildTool_debug%%\n"}      = "";
}

if ($copyDev)
{
	$replace{"%%postBuild_release%%\n"}    = $postBuild_release;
	$replace{"%%postBuild_optimized%%\n"}  = $postBuild_optimized;
	$replace{"%%postBuild_debug%%\n"}      = $postBuild_debug;
}
else
{
	$replace{"%%postBuild_release%%\n"}    = "";
	$replace{"%%postBuild_optimized%%\n"}  = "";
	$replace{"%%postBuild_debug%%\n"}      = "";
}

if ($copyDev)
{
	$replace{"%%preLink_release%%\n"}    = "";
	$replace{"%%preLink_optimized%%\n"}  = "";
	$replace{"%%preLink_debug%%\n"}      = "";
}
else
{
	$replace{"%%preLink_release%%\n"}    = "";
	$replace{"%%preLink_optimized%%\n"}  = "";
	$replace{"%%preLink_debug%%\n"}      = "";
}

if ($copyDev)
{
	$replace{"%%copyDev_release%%"}         = "copy \$(TargetPath) ..\\..\\..\\..\\..\\..\\..\\dev\\win32\\%%project%%_r.exe";
	$replace{"%%copyDev_optimized%%"}       = "copy \$(TargetPath) ..\\..\\..\\..\\..\\..\\..\\dev\\win32\\%%project%%_o.exe";
	$replace{"%%copyDev_debug%%"}           = "copy \$(TargetPath) ..\\..\\..\\..\\..\\..\\..\\dev\\win32\\%%project%%_d.exe";
}
else
{
	$replace{"%%copyDev_release%%"}         = "";
	$replace{"%%copyDev_optimized%%"}       = "";
	$replace{"%%copyDev_debug%%"}           = "";
}

if ($stdafx)
{
	$replace{"%%pch%%"} = "StdAfx.h";
}
else
{
	if ($noPchDir)
	{
		$replace{"%%pch%%"} = "First" . $Project . ".h";
	}
	else
	{
		$replace{"%%pch%%"} = $project . "\\First" . $Project . ".h";
	}
}

# =====================================================================

# do all the replacements repeatedly until no more replacements can be made
do
{
	$changed = 0;
	foreach $key (keys %replace)
	{
		$changed += $output =~ s/$key/$replace{$key}/;
	}
} while ($changed > 0);

# convert newlines to cr/lf sequences
$output =~ s/\n/\cM\cJ/g;

# save the output
open(DSP, ">" . $project . ".dsp") || die "could not open project file " . $project . ".dsp for writing\n";
binmode(DSP);
print DSP $output;
close(DSP);

# =====================================================================

BEGIN
{

sub process_rsp
{
	local $_;
	my @rsp;
	while (@_)
	{
		open(RSP, shift @_);
		while (<RSP>)
		{
			chomp;

			# handle comments
			s/#.*//;

			s/\s+$//;
			tr/\//\\/;
			push(@rsp, $_) if ($_ ne "");
		}
		close(RSP);
	}
	return @rsp;
}

sub explode
{
	local $_;
	my $result = "";
	my $prefix = shift @_;
	my $suffix = shift @_;

	foreach (@_)
	{
		$result .= " " . $prefix . $_ . $suffix;
	}
	return $result;
}

# ---------------------------------------------------------------------

$template_library =
q@# Microsoft Developer Studio Project File - Name="%%project%%" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Static Library" 0x0104

CFG=%%project%% - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "%%project%%.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "%%project%%.mak" CFG="%%project%% - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "%%project%% - Win32 Release" (based on "Win32 (x86) Static Library")
!MESSAGE "%%project%% - Win32 Optimized" (based on "Win32 (x86) Static Library")
!MESSAGE "%%project%% - Win32 Debug" (based on "Win32 (x86) Static Library")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName "%%project%%"
# PROP Scc_LocalPath "..\.."
CPP=cl.exe
RSC=rc.exe

!IF  "$(CFG)" == "%%project%% - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Release"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Release"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_MBCS" /D "_LIB" /YX /FD /c
# ADD CPP /nologo /G6 /MT /W4 /WX /GR /GX %%dbgInfo_r%% /O2 %%includeDirectories_release%% %%defines_release%% /Yu"%%pch%%" /FD %%zm%% /c
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LIB32=link.exe -lib
# ADD BASE LIB32 /nologo
# ADD LIB32 /nologo

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Optimized"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Optimized"
# PROP BASE Intermediate_Dir "Optimized"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Optimized"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Optimized"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_MBCS" /D "_LIB" /YX /FD /c
# ADD CPP /nologo /G6 /MTd /W4 /WX %%minimalRebuild%% /GR /GX %%dbgInfo_o%% %%optimizedOptimizations%% /Gf %%includeDirectories_optimized%% %%defines_optimized%% /Yu"%%pch%%" /FD %%zm%% /c
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LIB32=link.exe -lib
# ADD BASE LIB32 /nologo
# ADD LIB32 /nologo

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Debug"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Debug"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_MBCS" /D "_LIB" /YX /FD /GZ /c
# ADD CPP /nologo /G6 /MTd /W4 /WX %%minimalRebuild%% /GR /GX %%dbgInfo_d%% /Od %%debugInline%% %%includeDirectories_debug%% %%defines_debug%% /Yu"%%pch%%" /FD %%zm%% /GZ /c
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LIB32=link.exe -lib
# ADD BASE LIB32 /nologo
# ADD LIB32 /nologo

!ENDIF 

# Begin Target

# Name "%%project%% - Win32 Release"
# Name "%%project%% - Win32 Optimized"
# Name "%%project%% - Win32 Debug"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;rc"
%%sources%%
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "def;h;hpp;inl"
%%headers%%
# End Group
# Begin Group "Resource Files"

# PROP Default_Filter "ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe"
%%resources%%
# End Group
# Begin Group "Template Files"

# PROP Default_Filter "template"
%%templates%%
# End Group
# End Target
# End Project
@;

# ---------------------------------------------------------------------

$template_windows =
q@# Microsoft Developer Studio Project File - Name="%%project%%" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Application" 0x0101

CFG=%%project%% - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "%%project%%.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "%%project%%.mak" CFG="%%project%% - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "%%project%% - Win32 Release" (based on "Win32 (x86) Application")
!MESSAGE "%%project%% - Win32 Optimized" (based on "Win32 (x86) Application")
!MESSAGE "%%project%% - Win32 Debug" (based on "Win32 (x86) Application")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName "%%project%%"
# PROP Scc_LocalPath "..\.."
CPP=cl.exe
MTL=midl.exe
RSC=rc.exe

!IF  "$(CFG)" == "%%project%% - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Release"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Release"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_MBCS" /D "_LIB" /YX /FD /c
# ADD CPP /nologo /G6 /MT /W4 /WX /GR /GX %%dbgInfo_r%% /O2 %%includeDirectories_release%% %%defines_release%% /Yu"%%pch%%" /FD %%zm%% /c
# ADD BASE MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /machine:I386
# ADD LINK32 %%libraries_release%% kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /debug /machine:I386 %%ignoreLibraries_release%% /out:"..\..\..\..\..\..\compile\win32\%%project%%\Release\%%project%%_r.exe" /pdbtype:sept %%libraryDirectories_release%% %%incremental_r%%
# SUBTRACT LINK32 /pdb:none
%%specialBuildTool_release%%

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Optimized"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Optimized"
# PROP BASE Intermediate_Dir "Optimized"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Optimized"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Optimized"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_MBCS" /D "_LIB" /YX /FD /c
# ADD CPP /nologo /G6 /MTd /W4 /WX %%minimalRebuild%% /GR /GX %%dbgInfo_o%% %%optimizedOptimizations%% /Gf %%includeDirectories_optimized%% %%defines_optimized%% /Yu"%%pch%%" /FD %%zm%% /c
# ADD BASE MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /debug /machine:I386 /pdbtype:sept
# ADD LINK32 %%libraries_optimized%% kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /debug /machine:I386 %%ignoreLibraries_optimized%% /out:"..\..\..\..\..\..\compile\win32\%%project%%\Optimized\%%project%%_o.exe" /pdbtype:sept %%libraryDirectories_optimized%% %%incremental_o%%
# SUBTRACT LINK32 /pdb:none
%%specialBuildTool_optimized%%

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Debug"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Debug"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_MBCS" /D "_LIB" /YX /FD /GZ /c
# ADD CPP /nologo /G6 /MTd /W4 /WX %%minimalRebuild%% /GR /GX %%dbgInfo_d%% /Od %%debugInline%% %%includeDirectories_debug%% %%defines_debug%% /Yu"%%pch%%" /FD %%zm%% /GZ /c
# ADD BASE MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /debug /machine:I386 /pdbtype:sept
# ADD LINK32 %%libraries_debug%% kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /debug /machine:I386 %%ignoreLibraries_debug%% /out:"..\..\..\..\..\..\compile\win32\%%project%%\Debug\%%project%%_d.exe" /pdbtype:sept %%libraryDirectories_debug%% %%incremental_d%%
# SUBTRACT LINK32 /pdb:none
%%specialBuildTool_debug%%

!ENDIF 

# Begin Target

# Name "%%project%% - Win32 Release"
# Name "%%project%% - Win32 Optimized"
# Name "%%project%% - Win32 Debug"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;rc"
%%sources%%
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "def;h;hpp;inl"
%%headers%%
# End Group
# Begin Group "Resource Files"

# PROP Default_Filter "ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe"
%%resources%%
# End Group
# Begin Group "Template Files"

# PROP Default_Filter "template"
%%templates%%
# End Group
# Begin Group "Ui Files"

# PROP Default_Filter "ui"
%%uis%%
# End Group
# Begin Group "Ui Generated Files"

# PROP Default_Filter ""
# Begin Group "Release"

# PROP Default_Filter ""
# Begin Group "Release Ui Source Files"

# PROP Default_Filter ""
%%uiGeneratedSources_release%%
# End Group
# Begin Group "Release Ui HeaderFiles"

# PROP Default_Filter ""
%%uiGeneratedHeaders_release%%
# End Group
# End Group
# Begin Group "Optimized"

# PROP Default_Filter ""
# Begin Group "Optimized Ui Source Files"

# PROP Default_Filter ""
%%uiGeneratedSources_optimized%%
# End Group
# Begin Group "Optimized Ui Header Files"

# PROP Default_Filter ""
%%uiGeneratedHeaders_optimized%%
# End Group
# End Group
# Begin Group "Debug"

# PROP Default_Filter ""
# Begin Group "Debug Ui Source Files"

# PROP Default_Filter ""
%%uiGeneratedSources_debug%%
# End Group
# Begin Group "Debug Ui Header Files"

# PROP Default_Filter ""
%%uiGeneratedHeaders_debug%%
# End Group
# End Group
# End Group
# End Target
# End Project
@;


# ---------------------------------------------------------------------

$template_mfc =
q@# Microsoft Developer Studio Project File - Name="%%project%%" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Application" 0x0101

CFG=%%project%% - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "%%project%%.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "%%project%%.mak" CFG="%%project%% - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "%%project%% - Win32 Release" (based on "Win32 (x86) Application")
!MESSAGE "%%project%% - Win32 Optimized" (based on "Win32 (x86) Application")
!MESSAGE "%%project%% - Win32 Debug" (based on "Win32 (x86) Application")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName "%%project%%"
# PROP Scc_LocalPath "..\.."
CPP=cl.exe
MTL=midl.exe
RSC=rc.exe

!IF  "$(CFG)" == "%%project%% - Win32 Release"

# PROP BASE Use_MFC 5
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 5
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Release"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Release"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_MBCS" /D "_LIB" /YX /FD /c
# ADD CPP /nologo /G6 /MT /W4 /WX /GR /GX %%dbgInfo_r%% /O2 %%includeDirectories_release%% %%defines_release%% /Yu"%%pch%%" /FD %%zm%% /c
# ADD BASE MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 /nologo /subsystem:windows /machine:I386
# ADD LINK32 %%libraries_release%% /nologo /subsystem:windows /debug /machine:I386 %%ignoreLibraries_release%%  /out:"..\..\..\..\..\..\compile\win32\%%project%%\Release\%%project%%_r.exe" /pdbtype:sept %%libraryDirectories_release%% %%incremental_r%%
# SUBTRACT LINK32 /pdb:none
%%specialBuildTool_release%%

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Optimized"

# PROP BASE Use_MFC 5
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Optimized"
# PROP BASE Intermediate_Dir "Optimized"
# PROP BASE Target_Dir ""
# PROP Use_MFC 5
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Optimized"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Optimized"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_MBCS" /D "_LIB" /YX /FD /c
# ADD CPP /nologo /G6 /MTd /W4 /WX %%minimalRebuild%% /GR /GX %%dbgInfo_o%% %%optimizedOptimizations%% /Gf %%includeDirectories_optimized%% %%defines_optimized%% /Yu"%%pch%%" /FD %%zm%% /c
# ADD BASE MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 /nologo /subsystem:windows /debug /machine:I386 /pdbtype:sept
# ADD LINK32 %%libraries_optimized%% /nologo /subsystem:windows /debug /machine:I386 %%ignoreLibraries_optimized%% /out:"..\..\..\..\..\..\compile\win32\%%project%%\Optimized\%%project%%_o.exe" /pdbtype:sept %%libraryDirectories_optimized%% %%incremental_o%%
# SUBTRACT LINK32 /pdb:none
%%specialBuildTool_optimized%%

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Debug"

# PROP BASE Use_MFC 5
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 5
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Debug"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Debug"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_MBCS" /D "_LIB" /YX /FD /GZ /c
# ADD CPP /nologo /G6 /MTd /W4 /WX %%minimalRebuild%% /GR /GX %%dbgInfo_d%% /Od %%debugInline%% %%includeDirectories_debug%% %%defines_debug%% /Yu"%%pch%%" /FD %%zm%% /GZ /c
# ADD BASE MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 /nologo /subsystem:windows /debug /machine:I386 /pdbtype:sept
# ADD LINK32 %%libraries_debug%% /nologo /subsystem:windows /debug /machine:I386 %%ignoreLibraries_debug%% /out:"..\..\..\..\..\..\compile\win32\%%project%%\Debug\%%project%%_d.exe" /pdbtype:sept %%libraryDirectories_debug%% %%incremental_d%%
# SUBTRACT LINK32 /pdb:none
%%specialBuildTool_debug%%

!ENDIF 

# Begin Target

# Name "%%project%% - Win32 Release"
# Name "%%project%% - Win32 Optimized"
# Name "%%project%% - Win32 Debug"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;rc"
%%sources%%
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "def;h;hpp;inl"
%%headers%%
# End Group
# Begin Group "Resource Files"

# PROP Default_Filter "ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe"
%%resources%%
# End Group
# Begin Group "Template Files"

# PROP Default_Filter "template"
%%templates%%
# End Group
# End Target
# End Project
@;

# ---------------------------------------------------------------------

$template_console = 
q@# Microsoft Developer Studio Project File - Name="%%project%%" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Console Application" 0x0103

CFG=%%project%% - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "%%project%%.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "%%project%%.mak" CFG="%%project%% - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "%%project%% - Win32 Release" (based on "Win32 (x86) Console Application")
!MESSAGE "%%project%% - Win32 Optimized" (based on "Win32 (x86) Console Application")
!MESSAGE "%%project%% - Win32 Debug" (based on "Win32 (x86) Console Application")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName "%%project%%"
# PROP Scc_LocalPath "..\.."
CPP=cl.exe
RSC=rc.exe

!IF  "$(CFG)" == "%%project%% - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Release"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Release"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_MBCS" /D "_LIB" /YX /FD /c
# ADD CPP /nologo /G6 /MT /W4 /WX /GR /GX %%dbgInfo_r%% /O2 %%includeDirectories_release%% %%defines_release%% /Yu"%%pch%%" /FD %%zm%% /c
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /machine:I386
# ADD LINK32 %%libraries_release%% kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /debug /machine:I386 %%ignoreLibraries_release%% /out:"..\..\..\..\..\..\compile\win32\%%project%%\Release\%%project%%_r.exe" /pdbtype:sept %%libraryDirectories_release%% %%incremental_r%%
# SUBTRACT LINK32 /pdb:none
%%specialBuildTool_release%%

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Optimized"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Optimized"
# PROP BASE Intermediate_Dir "Optimized"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Optimized"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Optimized"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_MBCS" /D "_LIB" /YX /FD /c
# ADD CPP /nologo /G6 /MTd /W4 /WX %%minimalRebuild%% /GR /GX %%dbgInfo_o%% %%optimizedOptimizations%% /Gf %%includeDirectories_optimized%% %%defines_optimized%% /Yu"%%pch%%" /FD %%zm%% /c
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /debug /machine:I386 /pdbtype:sept
# ADD LINK32 %%libraries_optimized%% kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /debug /machine:I386 %%ignoreLibraries_optimized%% /out:"..\..\..\..\..\..\compile\win32\%%project%%\Optimized\%%project%%_o.exe" /pdbtype:sept %%libraryDirectories_optimized%% %%incremental_o%%
# SUBTRACT LINK32 /pdb:none
%%specialBuildTool_optimized%%

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Debug"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Debug"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_MBCS" /D "_LIB" /YX /FD /GZ /c
# ADD CPP /nologo /G6 /MTd /W4 /WX %%minimalRebuild%% /GR /GX %%dbgInfo_d%% /Od %%debugInline%% %%includeDirectories_debug%% %%defines_debug%% /Yu"%%pch%%" /FD %%zm%% /GZ /c
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /debug /machine:I386 /pdbtype:sept
# ADD LINK32 %%libraries_debug%% kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /debug /machine:I386 %%ignoreLibraries_debug%% /out:"..\..\..\..\..\..\compile\win32\%%project%%\Debug\%%project%%_d.exe" /pdbtype:sept %%libraryDirectories_debug%% %%incremental_d%%
# SUBTRACT LINK32 /pdb:none
%%specialBuildTool_debug%%

!ENDIF 

# Begin Target

# Name "%%project%% - Win32 Release"
# Name "%%project%% - Win32 Optimized"
# Name "%%project%% - Win32 Debug"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;rc"
%%sources%%
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "def;h;hpp;inl"
%%headers%%
# End Group
# Begin Group "Resource Files"

# PROP Default_Filter "ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe"
%%resources%%
# End Group
# Begin Group "Template Files"

# PROP Default_Filter "template"
%%templates%%
# End Group
# End Target
# End Project
@;

# ---------------------------------------------------------------------

$template_utility = 
q@# Microsoft Developer Studio Project File - Name="%%project%%" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Generic Project" 0x010a

CFG=%%project%% - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "%%project%%.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "%%project%%.mak" CFG="%%project%% - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "%%project%% - Win32 Release" (based on "Win32 (x86) Generic Project")
!MESSAGE "%%project%% - Win32 Optimized" (based on "Win32 (x86) Generic Project")
!MESSAGE "%%project%% - Win32 Debug" (based on "Win32 (x86) Generic Project")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName "%%project%%"
# PROP Scc_LocalPath "..\.."
MTL=midl.exe

!IF  "$(CFG)" == "%%project%% - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Release"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Release"
# PROP Target_Dir ""

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Optimized"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Debug"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Debug"
# PROP Target_Dir ""

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Debug"
# PROP Intermediate_Dir "..\..\..\..\..\..\compile\win32\%%project%%\Debug"
# PROP Target_Dir ""

!ENDIF 

# Begin Target

# Name "%%project%% - Win32 Release"
# Name "%%project%% - Win32 Optimized"
# Name "%%project%% - Win32 Debug"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;rc"
%%sources%%
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "def;h;hpp;inl"
%%headers%%
# End Group
# Begin Group "Resource Files"

# PROP Default_Filter "ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe"
%%resources%%
# End Group
# Begin Group "Template Files"

# PROP Default_Filter "template"
%%templates%%
# End Group
# End Target
# End Project
@;

# ---------------------------------------------------------------------

$mocHeader= q@
!IF  "$(CFG)" == "%%project%% - Win32 Release"

# Begin Custom Build - moc $(InputName)
TargetDir=..\..\..\..\..\..\compile\win32\%%project%%\Release
InputPath=%%inputPath%%
InputName=%%inputName%%

"$(TargetDir)\$(InputName).moc" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\moc -i $(InputPath) -o $(TargetDir)\$(InputName).moc

# End Custom Build

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Optimized"

# Begin Custom Build - moc $(InputName)
TargetDir=..\..\..\..\..\..\compile\win32\%%project%%\Optimized
InputPath=%%inputPath%%
InputName=%%inputName%%

"$(TargetDir)\$(InputName).moc" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\moc -i $(InputPath) -o $(TargetDir)\$(InputName).moc

# End Custom Build

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Debug"

# Begin Custom Build - moc $(InputName)
TargetDir=..\..\..\..\..\..\compile\win32\%%project%%\Debug
InputPath=%%inputPath%%
InputName=%%inputName%%

"$(TargetDir)\$(InputName).moc" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\moc -i $(InputPath) -o $(TargetDir)\$(InputName).moc

# End Custom Build

!ENDIF
@;

# ---------------------------------------------------------------------

$ui = q@
!IF  "$(CFG)" == "%%project%% - Win32 Release"

# Begin Custom Build - ui $(InputName)
TargetDir=..\..\..\..\..\..\compile\win32\%%project%%\Release
InputPath=%%inputPath%%
InputName=%%inputName%%

BuildCmds= \
	..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\uic -o $(TargetDir)\$(InputName).h $(InputPath) \
	..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\uic -o $(TargetDir)\$(InputName)_r.cpp -impl $(TargetDir)\$(InputName).h $(InputPath) \
	..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\moc  $(TargetDir)\$(InputName).h >> $(TargetDir)\$(InputName)_r.cpp

"$(TargetDir)/$(InputName).h" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
   $(BuildCmds)

"$(TargetDir)/$(InputName)_r.cpp" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
   $(BuildCmds)
# End Custom Build

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Optimized"

# Begin Custom Build - ui $(InputName)
TargetDir=..\..\..\..\..\..\compile\win32\%%project%%\Optimized
InputPath=%%inputPath%%
InputName=%%inputName%%

BuildCmds= \
	..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\uic -o $(TargetDir)\$(InputName).h $(InputPath) \
	..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\uic -o $(TargetDir)\$(InputName)_o.cpp -impl $(TargetDir)\$(InputName).h $(InputPath) \
	..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\moc  $(TargetDir)\$(InputName).h >> $(TargetDir)\$(InputName)_o.cpp

"$(TargetDir)\$(InputName).h" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
   $(BuildCmds)

"$(TargetDir)\$(InputName)_o.cpp" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
   $(BuildCmds)
# End Custom Build

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Debug"

# Begin Custom Build - ui $(InputName)
TargetDir=..\..\..\..\..\..\compile\win32\%%project%%\Debug
InputPath=%%inputPath%%
InputName=%%inputName%%

BuildCmds= \
	..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\uic -o $(TargetDir)\$(InputName).h $(InputPath) \
	..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\uic -o $(TargetDir)\$(InputName)_d.cpp -impl $(TargetDir)\$(InputName).h $(InputPath) \
	..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\moc  $(TargetDir)\$(InputName).h >> $(TargetDir)\$(InputName)_d.cpp

"$(TargetDir)\$(InputName).h" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
   $(BuildCmds)

"$(TargetDir)\$(InputName)_d.cpp" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
   $(BuildCmds)
# End Custom Build

!ENDIF

@;

# ---------------------------------------------------------------------

$release_ui_cpp = q@
!IF  "$(CFG)" == "%%project%% - Win32 Release"

# ADD CPP /W3
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Optimized"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Debug"

# PROP Exclude_From_Build 1

!ENDIF
@;

$optimized_ui_cpp = q@
!IF  "$(CFG)" == "%%project%% - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Optimized"

# ADD CPP /W3
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Debug"

# PROP Exclude_From_Build 1

!ENDIF
@;

$debug_ui_cpp = q@
!IF  "$(CFG)" == "%%project%% - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Optimized"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "%%project%% - Win32 Debug"

# ADD CPP /W3
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF
@;

# ---------------------------------------------------------------------

$specialBuildTool_release = 
q@# Begin Special Build Tool
TargetPath=..\..\..\..\..\..\compile\win32\%%project%%\Release\%%project%%_r.exe
SOURCE="$(InputPath)"
%%preLink_release%%
%%postBuild_release%%
# End Special Build Tool
@;

$specialBuildTool_optimized = 
q@# Begin Special Build Tool
TargetPath=..\..\..\..\..\..\compile\win32\%%project%%\Optimized\%%project%%_o.exe
SOURCE="$(InputPath)"
%%preLink_optimized%%
%%postBuild_optimized%%
# End Special Build Tool
@;

$specialBuildTool_debug = 
q@# Begin Special Build Tool
TargetPath=..\..\..\..\..\..\compile\win32\%%project%%\Debug\%%project%%_d.exe
SOURCE="$(InputPath)"
%%preLink_debug%%
%%postBuild_debug%%
# End Special Build Tool
@;

$postBuild_release = 
q@PostBuild_Desc=Post build steps
PostBuild_Cmds=%%copyDev_release%%
@;

$postBuild_optimized= 
q@PostBuild_Desc=Post build steps
PostBuild_Cmds=%%copyDev_optimized%%
@;

$postBuild_debug = 
q@PostBuild_Desc=Post build steps
PostBuild_Cmds=%%copyDev_debug%%
@;

$resourceDebugLevels =
q@
!IF  "$(CFG)" == "SwgClient - Win32 Release"

# ADD BASE RSC /l 0x409 /i "\work\swg\live\src\game\client\application\SwgClient\src\win32" /i "\work\swg\current\src\game\client\application\SwgClient\src\win32"
# ADD RSC /l 0x409 /i "\work\swg\live\src\game\client\application\SwgClient\src\win32" /i "\work\swg\current\src\game\client\application\SwgClient\src\win32" /d DEBUG_LEVEL=0

!ELSEIF  "$(CFG)" == "SwgClient - Win32 Optimized"

# ADD BASE RSC /l 0x409 /i "\work\swg\live\src\game\client\application\SwgClient\src\win32" /i "\work\swg\current\src\game\client\application\SwgClient\src\win32"
# ADD RSC /l 0x409 /i "\work\swg\live\src\game\client\application\SwgClient\src\win32" /i "\work\swg\current\src\game\client\application\SwgClient\src\win32" /d DEBUG_LEVEL=1

!ELSEIF  "$(CFG)" == "SwgClient - Win32 Debug"

# ADD BASE RSC /l 0x409 /i "\work\swg\live\src\game\client\application\SwgClient\src\win32" /i "\work\swg\current\src\game\client\application\SwgClient\src\win32"
# ADD RSC /l 0x409 /i "\work\swg\live\src\game\client\application\SwgClient\src\win32" /i "\work\swg\current\src\game\client\application\SwgClient\src\win32" /d DEBUG_LEVEL=2

!ENDIF 

@;

# ---------------------------------------------------------------------

}
