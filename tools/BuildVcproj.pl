#!/usr/bin/perl
# =====================================================================

# figure out what project file we're building
$project = $ARGV[0];
die "no project name specified" if (!defined($project));

# lop off the directories
$project =~ s#^.*[/\\]##;

# lop off the extension
$project =~ s#\.vcproj$##;

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
@defines_debug      = ("WIN32", "_DEBUG", "_MBCS", "DEBUG_LEVEL=2", "_CRT_SECURE_NO_DEPRECATE=1", "_USE_32BIT_TIME_T=1");
@defines_optimized  = ("WIN32", "_DEBUG", "_MBCS", "DEBUG_LEVEL=1", "_CRT_SECURE_NO_DEPRECATE=1", "_USE_32BIT_TIME_T=1");
@defines_release    = ("WIN32", "NDEBUG", "_MBCS", "DEBUG_LEVEL=0", "_CRT_SECURE_NO_DEPRECATE=1", "_USE_32BIT_TIME_T=1");

$opt_optimizationLevel = "3";
$opt_intrinsicFunctions = "TRUE";
$opt_sizeOrSpeed = "1";

$fixMfc = 0;
$fixQt = 0;

$dbgInfo_d = makeDebugInfoFlag("pdb");
$dbgInfo_o = makeDebugInfoFlag("pdb");
$dbgInfo_r = makeDebugInfoFlag("pdb");
$incremental_d = makeIncrementalLinkFlag("yes");
$incremental_o = makeIncrementalLinkFlag("yes");
$incremental_r = makeIncrementalLinkFlag("no");
$minimalRebuild = "TRUE";
$debugInline = "0";

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
			
			# Don't fix mfc paths. We want to compile using mfc, not atlmfc
			# $fixMfc = 1;
		}
		elsif ($_ eq "qt334" || $_ eq "qt")
		{
			$output = $template_qt;
			push(@defines_debug,      "_WINDOWS", "QT_DLL", "QT_NO_STL", "QT_ACCESSIBILITY_SUPPORT");
			push(@defines_optimized,  "_WINDOWS", "QT_DLL", "QT_NO_STL", "QT_ACCESSIBILITY_SUPPORT");
			push(@defines_release,    "_WINDOWS", "QT_DLL", "QT_NO_STL", "QT_ACCESSIBILITY_SUPPORT");
			$qt_version = "3.3.4";
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
		elsif ($_ eq "noPch")
		{
			$noPch = 1;
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
		elsif (/^dbgInfo_/)
		{
			print "ignoring $_ directive\n";
		}
		#elsif (s/^dbgInfo_d_//)
		#{
		#	$dbgInfo_d = makeDebugInfoFlag($_);
		#}
		#elsif (s/^dbgInfo_o_//)
		#{
		#	$dbgInfo_o = makeDebugInfoFlag($_);
		#}
		#elsif (s/^dbgInfo_r_//)
		#{
		#	$dbgInfo_r = makeDebugInfoFlag($_);
		#}
		elsif (/^incremental_/)
		{
			print "ignoring $_ directive\n";
		}
		#elsif (s/^incremental_d_//)
		#{
		#	$incremental_d = makeIncrementalLinkFlag($_);
		#}
		#elsif (s/^incremental_o_//)
		#{
		#	$incremental_o = makeIncrementalLinkFlag($_);
		#}
		#elsif (s/^incremental_r_//)
		#{
		#	$incremental_r = makeIncrementalLinkFlag($_);
		#}
		elsif (/Gm-/)
		{
			$minimalRebuild = "FALSE";
		}
		elsif ($_ eq "copyDev")
		{
			$copyDev = 1;
		}
		elsif ($_ eq "debugInline")
		{
			$debugInline = "1";
		}
		elsif ($_ eq "disableOptimizationsInOpt")
		{
			$opt_optimizationLevel = "0";
			$opt_intrinsicFunctions = "FALSE";
			$opt_sizeOrSpeed = "0";
		}
		elsif ($_ eq "versionNumber")
		{
			$versionNumber = 1;
		}
		elsif ($_ eq "versionResource")
		{
			$versionResource = 1;
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

if ($fixMfc)
{
	fixup_mfc_path(@includeDirectories_debug);
	fixup_mfc_path(@includeDirectories_optimized);
	fixup_mfc_path(@includeDirectories_release);
	fixup_mfc_path(@libraryDirectories_debug);
	fixup_mfc_path(@libraryDirectories_optimized);
	fixup_mfc_path(@libraryDirectories_release);
}


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

if (open(VCPROJ, $project . ".vcproj"))
{
	while (<VCPROJ>)
	{
		# remember the guid
		if (/ProjectGUID/)
		{
			chomp;
			s/^.*{//;
			s/}.*$//;

			$guid = $_;
		}

		# eat a > line
		if ($state == 2)
		{
			if (/^\t+>$/)
			{
				s/^.*$//;
				chomp;
			}
			$state = 3;
		}
		# look for per-file settings to preserve
		if ($state == 3)
		{
			if (/\/File>/)
			{
				$state = 0;
			}
			else
			{
				$settings{$filename} .= $_;
			}
		}
		if ($state == 1 && /^\t+RelativePath=/)
		{
			chomp;
			s/^[^"]+"//;
			s/"[^"]*$//;
			$filename = $_;
			$state = 2;
		}
		if (/^\t\t\t<File[^A-Za-z]/)
		{
			$state = 1;
		}
	}
	close(VCPROJ);
}

if ($guid eq "")
{
	open(P4, "p4 where //depot/swg/s8/tools/newguid|");
	$_ = <P4>;
	close(P4);
	($where_depot, $where_client, $where_local) = split;
	
	# couldn't find it, so make a new guids
	open(GUID, $where_local . "|");
	$guid = <GUID>;
	chomp $guid;
	close(GUID);
}
$guid = uc $guid;

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

sub makeIncrementalLinkFlag
{
  my $input = $_[0];
  local $flag = "";
  local $_;
  
  if ( $input eq "yes" )
  {
  	$flag = "2";
  }
  elsif ( $input eq "no" )
  {
  	$flag = "1";
  }
  else
  {
  	die "Unknown setting for incremental_link: $input\n";
  }

	return $flag;
}

# =====================================================================
# 

sub makeDebugInfoFlag
{
  my $input = $_[0];
  local $flag = "";
  local $_;
  
  if ( $input eq "line_numbers_only" )
  {
  	$flag = "2";
  }
  elsif ( $input eq "pdb" )
  {
  	$flag = "3";
  }
  elsif ( $input eq "edit_and_continue" )
  {
  	$flag = "4";
  }
  elsif ( $input eq "none" )
  {
  	$flag = "0";
  }
  else
  {
  	die "Unknown setting for dbgInfo: $input\n";
  }

	return $flag;
}


sub fixup_mfc_path
{
	foreach (@_)
	{
		s/library\\mfc/library\\atlmfc/;
	}
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
		$settings{$pathed} = $excludeFromBuild;
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
		$settings{$pathed} = $resourceDebugLevels if ($versionResource);
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
$settings{$sourceNames{"First$Project.cpp"}} = $createPrecompiledHeader;

foreach (sort keys %sourceNames)
{
	$_ = $sourceNames{$_};
	$sources .= "\t\t\t<File\n\t\t\t\tRelativePath=\"" .$_ . "\"\n\t\t\t\t>\n" . $settings{$_} . "\t\t\t</File>\n";
}

foreach (sort keys %headerNames)
{
	$_ = $headerNames{$_};
	$headers .= "\t\t\t<File\n\t\t\t\tRelativePath=\"" . $_ . "\"\n\t\t\t\t>\n" . $settings{$_} . "\t\t\t</File>\n";
}

foreach (sort keys %resourceNames)
{
	$_ = $resourceNames{$_};
	$resources .= "\t\t\t<File\n\t\t\t\tRelativePath=\"" . $_ . "\"\n\t\t\t\t>\n\t\t\t</File>\n";
}

foreach (sort keys %uiNames)
{
	# add the ui with the custom build step
	$uis .= "\t\t\t<File\n\t\t\t\tRelativePath=\"" . $uiNames{$_} . 
q@"
				>
				<FileConfiguration
					Name="Debug|Win32"
					>
					<Tool
						Name="VCCustomBuildTool"
						Description="ui $(InputName)"
						CommandLine="..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\uic -o $(TargetDir)$(InputName).h $(InputPath)&#x0D;&#x0A;..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\uic -o $(TargetDir)$(InputName)_d.cpp -impl $(TargetDir)$(InputName).h $(InputPath)&#x0D;&#x0A;..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\moc  $(TargetDir)$(InputName).h &gt;&gt; $(TargetDir)$(InputName)_d.cpp"
						Outputs="$(TargetDir)$(InputName).h;$(TargetDir)$(InputName)_d.cpp"
					/>
				</FileConfiguration>
				<FileConfiguration
					Name="Optimized|Win32"
					>
					<Tool
						Name="VCCustomBuildTool"
						Description="ui $(InputName)"
						CommandLine="..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\uic -o $(TargetDir)$(InputName).h $(InputPath)&#x0D;&#x0A;..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\uic -o $(TargetDir)$(InputName)_o.cpp -impl $(TargetDir)$(InputName).h $(InputPath)&#x0D;&#x0A;..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\moc  $(TargetDir)$(InputName).h &gt;&gt; $(TargetDir)$(InputName)_o.cpp"
						Outputs="$(TargetDir)$(InputName).h;$(TargetDir)$(InputName)_o.cpp"
					/>
				</FileConfiguration>
				<FileConfiguration
					Name="Release|Win32"
					>
					<Tool
						Name="VCCustomBuildTool"
						Description="ui $(InputName)"
						CommandLine="..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\uic -o $(TargetDir)$(InputName).h $(InputPath)&#x0D;&#x0A;..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\uic -o $(TargetDir)$(InputName)_r.cpp -impl $(TargetDir)$(InputName).h $(InputPath)&#x0D;&#x0A;..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\moc  $(TargetDir)$(InputName).h &gt;&gt; $(TargetDir)$(InputName)_r.cpp"
						Outputs="$(TargetDir)$(InputName).h;$(TargetDir)$(InputName)_r.cpp"
					/>
				</FileConfiguration>
			</File>
@;

	$cpp_debug = $_;
	$cpp_debug =~ s/\.ui/_d.cpp/;
	$cpp_optimized = $_;
	$cpp_optimized =~ s/\.ui/_o.cpp/;
	$cpp_release = $_;
	$cpp_release =~ s/\.ui/_r.cpp/;
	$h = $_;
	$h =~ s/\.ui/.h/;

	# add the ui-generated files separately for debug, optimized, and release builds
	$uiGeneratedSources_debug .= q@
					<File
						RelativePath="..\\..\\..\\..\\..\\..\\compile\\win32\\%%Project%%\\Debug\\@ . $cpp_debug . q@"
						>
						<FileConfiguration
							Name="Debug|Win32"
							>
							<Tool
								Name="VCCLCompilerTool"
								UsePrecompiledHeader="0"
								WarningLevel="3"
							/>
						</FileConfiguration>
						<FileConfiguration
							Name="Optimized|Win32"
							ExcludedFromBuild="TRUE"
							>
							<Tool
								Name="VCCLCompilerTool"
							/>
						</FileConfiguration>
						<FileConfiguration
							Name="Release|Win32"
							ExcludedFromBuild="TRUE"
							>
							<Tool
								Name="VCCLCompilerTool"
							/>
						</FileConfiguration>
					</File>
@;

	$uiGeneratedSources_optimized .= q@
					<File
						RelativePath="..\\..\\..\\..\\..\\..\\compile\\win32\\%%Project%%\\Optimized\\@ . $cpp_optimized . q@"
						>
						<FileConfiguration
							Name="Debug|Win32"
							ExcludedFromBuild="TRUE"
							>
							<Tool
								Name="VCCLCompilerTool"
							/>
						</FileConfiguration>
						<FileConfiguration
							Name="Optimized|Win32"
							>
							<Tool
								Name="VCCLCompilerTool"
								UsePrecompiledHeader="0"
								WarningLevel="3"
							/>
						</FileConfiguration>
						<FileConfiguration
							Name="Release|Win32"
							ExcludedFromBuild="TRUE"
							>
							<Tool
								Name="VCCLCompilerTool"
							/>
						</FileConfiguration>
					</File>
@;

	$uiGeneratedSources_release .= q@
					<File
						RelativePath="..\\..\\..\\..\\..\\..\\compile\\win32\\%%Project%%\\Release\\@ . $cpp_release . q@"
						>
						<FileConfiguration
							Name="Debug|Win32"
							ExcludedFromBuild="TRUE"
							>
							<Tool
								Name="VCCLCompilerTool"
							/>
						</FileConfiguration>
						<FileConfiguration
							Name="Optimized|Win32"
							ExcludedFromBuild="TRUE"
							>
							<Tool
								Name="VCCLCompilerTool"
							/>
						</FileConfiguration>
						<FileConfiguration
							Name="Release|Win32"
							>
							<Tool
								Name="VCCLCompilerTool"
								UsePrecompiledHeader="0"
								WarningLevel="3"
							/>
						</FileConfiguration>
					</File>
@;

	$uiGeneratedHeaders_debug .= q@
					<File
						RelativePath="..\\..\\..\\..\\..\\..\\compile\\win32\\%%Project%%\\Debug\\@  . $h . q@"
						>
					</File>
@;

	$uiGeneratedHeaders_optimized .= q@
					<File
						RelativePath="..\\..\\..\\..\\..\\..\\compile\\win32\\%%Project%%\\Optimized\\@  . $h . q@"
						>
					</File>
@;

	$uiGeneratedHeaders_release .= q@
					<File
						RelativePath="..\\..\\..\\..\\..\\..\\compile\\win32\\%%Project%%\\Release\\@  . $h . q@"
						>
					</File>
@;

}

foreach (sort keys %templateNames)
{
	$_ = $templateNames{$_};
	$templates .= "\t\t\t<File\n\t\t\t\tRelativePath=\"" .$_ . "\"\n\t\t\t\t>\n" . $settings{$_} . "\t\t\t</File>\n";
}

# =====================================================================
# set up the replacements

# setup the replacement strings
$replace{"%%guid%%"}                           = $guid;
$replace{"%%project%%"}                        = $project;
$replace{"%%Project%%"}                        = $Project;
$replace{"%%sources%%"}                        = $sources;
$replace{"%%headers%%"}                        = $headers;
$replace{"%%resource%%"}                       = $template_resource;
$replace{"%%resources%%"}                      = $resources;
$replace{"%%template%%"}                       = $template_template;
$replace{"%%templates%%"}                      = $templates;

$replace{"%%debugInline%%"}                   = $debugInline;
$replace{"%%dbgInfo_r%%"}                     = $dbgInfo_r;
$replace{"%%dbgInfo_o%%"}                     = $dbgInfo_o;
$replace{"%%dbgInfo_d%%"}                     = $dbgInfo_d;
$replace{"%%incremental_r%%"}                 = $incremental_r;
$replace{"%%incremental_o%%"}                 = $incremental_o;
$replace{"%%incremental_d%%"}                 = $incremental_d;
$replace{"%%minimalRebuild%%"}                = $minimalRebuild;
$replace{"%%opt_optimizationLevel%%"}         = $opt_optimizationLevel;
$replace{"%%opt_intrinsicFunctions%%"}        = $opt_intrinsicFunctions;
$replace{"%%opt_sizeOrSpeed%%"}               = $opt_sizeOrSpeed;

$replace{"%%includeDirectories_debug%%"}       = explode(",", @includeDirectories_debug);
$replace{"%%includeDirectories_optimized%%"}   = explode(",", @includeDirectories_optimized);
$replace{"%%includeDirectories_release%%"}     = explode(",", @includeDirectories_release);
$replace{"%%defines_debug%%"}                  = explode(";", @defines_debug);
$replace{"%%defines_optimized%%"}              = explode(";", @defines_optimized);
$replace{"%%defines_release%%"}                = explode(";", @defines_release);
$replace{"%%libraries_debug%%"}                = explode(" ", @libraries_debug);
$replace{"%%libraries_optimized%%"}            = explode(" ", @libraries_optimized);
$replace{"%%libraries_release%%"}              = explode(" ", @libraries_release);
$replace{"%%libraryDirectories_debug%%"}       = explode(",", @libraryDirectories_debug);
$replace{"%%libraryDirectories_optimized%%"}   = explode(",", @libraryDirectories_optimized);
$replace{"%%libraryDirectories_release%%"}     = explode(",", @libraryDirectories_release);
$replace{"%%ignoreLibraries_debug%%"}          = explode(",", @ignoreLibraries_debug);
$replace{"%%ignoreLibraries_optimized%%"}      = explode(",", @ignoreLibraries_optimized);
$replace{"%%ignoreLibraries_release%%"}        = explode(",", @ignoreLibraries_release);

$replace{"%%uis%%"}                            = $uis;
$replace{"%%uiGeneratedSources_debug%%"}       = $uiGeneratedSources_debug;
$replace{"%%uiGeneratedHeaders_debug%%"}       = $uiGeneratedHeaders_debug;
$replace{"%%uiGeneratedSources_optimized%%"}   = $uiGeneratedSources_optimized;
$replace{"%%uiGeneratedHeaders_optimized%%"}   = $uiGeneratedHeaders_optimized;
$replace{"%%uiGeneratedSources_release%%"}     = $uiGeneratedSources_release;
$replace{"%%uiGeneratedHeaders_release%%"}     = $uiGeneratedHeaders_release;

$replace{"%%qt_version%%"}                     = $qt_version;

$replace{"%%usepch%%"} = "3";

if ($stdafx)
{
	$replace{"%%pch%%"} = "StdAfx.h";
}
else
{
	if ($noPch)
	{
		$replace{"%%usepch%%"} = "0";
		$replace{"%%pch%%"} = "";
	}
	elsif ($noPchDir)
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

# remove all blank lines
$output =~ s/^\n+//;
$output =~ s/\n\n+/\n/g;

# convert newlines to cr/lf sequences
$output =~ s/\n/\cM\cJ/g;

# save the output
open(DSP, ">" . $project . ".vcproj") || die "could not open project file " . $project . ".vcproj for writing\n";
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
	my $separator = shift @_;
	my $result = shift @_;
	
	foreach (@_)
	{
		$result .= $separator . $_;
	}
	
	return $result;
}

# ---------------------------------------------------------------------

$template_windows = q@
<?xml version="1.0" encoding="Windows-1252"?>
<VisualStudioProject
	ProjectType="Visual C++"
	Version="8.00"
	Name="%%project%%"
	ProjectGUID="{%%guid%%}"
	Keyword="Win32Proj"
	>
	<Platforms>
		<Platform
			Name="Win32"
		/>
	</Platforms>
	<ToolFiles>
	</ToolFiles>
	<Configurations>
		<Configuration
			Name="Debug|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="1"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="0"
				InlineFunctionExpansion="%%debugInline%%"
				AdditionalIncludeDirectories="%%includeDirectories_debug%%"
				PreprocessorDefinitions="%%defines_debug%%"
				MinimalRebuild="%%minimalRebuild%%"
				BasicRuntimeChecks="3"
				RuntimeLibrary="1"
				EnableFunctionLevelLinking="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_d.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_d%%"
				CompileAs="0"
				UseFullPaths="TRUE"
				TreatWChar_tAsBuiltInType="FALSE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLinkerTool"
				AdditionalDependencies="%%libraries_debug%%"
				OutputFile="$(OutDir)/$(ProjectName)_d.exe"
				LinkIncremental="%%incremental_d%%"
				AdditionalLibraryDirectories="%%libraryDirectories_debug%%"
				IgnoreDefaultLibraryNames="%%ignoreLibraries_debug%%"
				GenerateDebugInformation="TRUE"
				ProgramDatabaseFile="$(OutDir)/$(ProjectName)_d.pdb"
				SubSystem="2"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="_DEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
		<Configuration
			Name="Optimized|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="1"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="%%opt_optimizationLevel%%"
				InlineFunctionExpansion="1"
				EnableIntrinsicFunctions="%%opt_intrinsicFunctions%%"
				FavorSizeOrSpeed="%%opt_sizeOrSpeed%%"
				OmitFramePointers="FALSE"
				AdditionalIncludeDirectories="%%includeDirectories_optimized%%"
				PreprocessorDefinitions="%%defines_optimized%%"
				MinimalRebuild="%%minimalRebuild%%"
				RuntimeLibrary="1"
				EnableFunctionLevelLinking="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_o.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_o%%"
				CompileAs="0"
				UseFullPaths="TRUE"
				TreatWChar_tAsBuiltInType="FALSE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLinkerTool"
				AdditionalDependencies="%%libraries_optimized%%"
				OutputFile="$(OutDir)/$(ProjectName)_o.exe"
				LinkIncremental="%%incremental_o%%"
				AdditionalLibraryDirectories="%%libraryDirectories_optimized%%"
				IgnoreDefaultLibraryNames="%%ignoreLibraries_optimized%%"
				GenerateDebugInformation="TRUE"
				ProgramDatabaseFile="$(OutDir)/$(ProjectName)_o.pdb"
				SubSystem="2"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="_DEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
		<Configuration
			Name="Release|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="1"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="2"
				InlineFunctionExpansion="1"
				EnableIntrinsicFunctions="TRUE"
				FavorSizeOrSpeed="1"
				OmitFramePointers="TRUE"
				AdditionalIncludeDirectories="%%includeDirectories_release%%"
				PreprocessorDefinitions="%%defines_release%%"
				StringPooling="TRUE"
				RuntimeLibrary="0"
				EnableFunctionLevelLinking="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_r.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_r%%"
				CompileAs="0"
				UseFullPaths="TRUE"
				TreatWChar_tAsBuiltInType="FALSE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLinkerTool"
				AdditionalDependencies="%%libraries_release%%"
				OutputFile="$(OutDir)/$(ProjectName)_r.exe"
				LinkIncremental="%%incremental_r%%"
				AdditionalLibraryDirectories="%%libraryDirectories_release%%"
				IgnoreDefaultLibraryNames="%%ignoreLibraries_release%%"
				GenerateDebugInformation="TRUE"
				ProgramDatabaseFile="$(OutDir)/$(ProjectName)_r.pdb"
				SubSystem="2"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="NDEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
	</Configurations>
	<References>
	</References>
	<Files>
		<Filter
			Name="Source Files"
			Filter="cpp;c;rc"
			>
%%sources%%
		</Filter>
		<Filter
			Name="Header Files"
			Filter="def;h;hpp;inl"
			>
%%headers%%
		</Filter>
%%template%%
%%resource%%
	</Files>
	<Globals>
	</Globals>
</VisualStudioProject>
@;

$template_mfc = q@
<?xml version="1.0" encoding="Windows-1252"?>
<VisualStudioProject
	ProjectType="Visual C++"
	Version="8.00"
	Name="%%project%%"
	ProjectGUID="{%%guid%%}"
	Keyword="MFCProj"
	>
	<Platforms>
		<Platform
			Name="Win32"
		/>
	</Platforms>
	<ToolFiles>
	</ToolFiles>	
	<Configurations>
		<Configuration
			Name="Debug|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="1"
			UseOfMFC="1"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="0"
				InlineFunctionExpansion="%%debugInline%%"
				AdditionalIncludeDirectories="%%includeDirectories_debug%%"
				PreprocessorDefinitions="%%defines_debug%%"
				MinimalRebuild="%%minimalRebuild%%"
				BasicRuntimeChecks="3"
				RuntimeLibrary="1"
				EnableFunctionLevelLinking="TRUE"
				TreatWChar_tAsBuiltInType="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_d.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_d%%"
				CompileAs="0"
				UseFullPaths="TRUE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLinkerTool"
				AdditionalDependencies="%%libraries_debug%%"
				OutputFile="$(OutDir)/$(ProjectName)_d.exe"
				LinkIncremental="%%incremental_d%%"
				AdditionalLibraryDirectories="%%libraryDirectories_debug%%"
				IgnoreDefaultLibraryNames="%%ignoreLibraries_debug%%"
				GenerateDebugInformation="TRUE"
				ProgramDatabaseFile="$(OutDir)/$(ProjectName)_d.pdb"
				SubSystem="2"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="_DEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
		<Configuration
			Name="Optimized|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="1"
			UseOfMFC="1"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="%%opt_optimizationLevel%%"
				InlineFunctionExpansion="1"
				EnableIntrinsicFunctions="%%opt_intrinsicFunctions%%"
				FavorSizeOrSpeed="%%opt_sizeOrSpeed%%"
				OmitFramePointers="FALSE"
				AdditionalIncludeDirectories="%%includeDirectories_optimized%%"
				PreprocessorDefinitions="%%defines_optimized%%"
				MinimalRebuild="%%minimalRebuild%%"
				RuntimeLibrary="1"
				EnableFunctionLevelLinking="TRUE"
				TreatWChar_tAsBuiltInType="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_o.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_o%%"
				CompileAs="0"
				UseFullPaths="TRUE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLinkerTool"
				AdditionalDependencies="%%libraries_optimized%%"
				OutputFile="$(OutDir)/$(ProjectName)_o.exe"
				LinkIncremental="%%incremental_o%%"
				AdditionalLibraryDirectories="%%libraryDirectories_optimized%%"
				IgnoreDefaultLibraryNames="%%ignoreLibraries_optimized%%"
				GenerateDebugInformation="TRUE"
				ProgramDatabaseFile="$(OutDir)/$(ProjectName)_o.pdb"
				SubSystem="2"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="_DEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
		<Configuration
			Name="Release|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="1"
			UseOfMFC="1"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="2"
				InlineFunctionExpansion="1"
				EnableIntrinsicFunctions="TRUE"
				FavorSizeOrSpeed="1"
				OmitFramePointers="TRUE"
				AdditionalIncludeDirectories="%%includeDirectories_release%%"
				PreprocessorDefinitions="%%defines_release%%"
				StringPooling="TRUE"
				RuntimeLibrary="0"
				EnableFunctionLevelLinking="TRUE"
				TreatWChar_tAsBuiltInType="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_r.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_r%%"
				CompileAs="0"
				UseFullPaths="TRUE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLinkerTool"
				AdditionalDependencies="%%libraries_release%%"
				OutputFile="$(OutDir)/$(ProjectName)_r.exe"
				LinkIncremental="%%incremental_r%%"
				AdditionalLibraryDirectories="%%libraryDirectories_release%%"
				IgnoreDefaultLibraryNames="%%ignoreLibraries_release%%"
				GenerateDebugInformation="TRUE"
				ProgramDatabaseFile="$(OutDir)/$(ProjectName)_r.pdb"
				SubSystem="2"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="NDEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
	</Configurations>
	<References>
	</References>
	<Files>
		<Filter
			Name="Source Files"
			Filter="cpp;c;rc"
			>
%%sources%%
		</Filter>
		<Filter
			Name="Header Files"
			Filter="def;h;hpp;inl"
			>
%%headers%%
		</Filter>
%%template%%
%%resource%%
	</Files>
	<Globals>
	</Globals>
</VisualStudioProject>
@;

$template_qt= q@
<?xml version="1.0" encoding="Windows-1252"?>
<VisualStudioProject
	ProjectType="Visual C++"
	Version="8.00"
	Name="%%project%%"
	ProjectGUID="{%%guid%%}"
	Keyword="Win32Proj"
	>
	<Platforms>
		<Platform
			Name="Win32"
		/>
	</Platforms>
	<ToolFiles>
	</ToolFiles>
	<Configurations>
		<Configuration
			Name="Debug|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="1"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="0"
				InlineFunctionExpansion="%%debugInline%%"
				AdditionalIncludeDirectories="%%includeDirectories_debug%%"
				PreprocessorDefinitions="%%defines_debug%%"
				MinimalRebuild="%%minimalRebuild%%"
				BasicRuntimeChecks="3"
				RuntimeLibrary="1"
				EnableFunctionLevelLinking="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_d.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_d%%"
				CompileAs="0"
				UseFullPaths="TRUE"
				TreatWChar_tAsBuiltInType="FALSE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLinkerTool"
				AdditionalDependencies="%%libraries_debug%%"
				OutputFile="$(OutDir)/$(ProjectName)_d.exe"
				LinkIncremental="%%incremental_d%%"
				AdditionalLibraryDirectories="%%libraryDirectories_debug%%"
				IgnoreDefaultLibraryNames="%%ignoreLibraries_debug%%"
				GenerateDebugInformation="TRUE"
				ProgramDatabaseFile="$(OutDir)/$(ProjectName)_d.pdb"
				SubSystem="2"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="_DEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
		<Configuration
			Name="Optimized|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="1"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="%%opt_optimizationLevel%%"
				InlineFunctionExpansion="1"
				EnableIntrinsicFunctions="%%opt_intrinsicFunctions%%"
				FavorSizeOrSpeed="%%opt_sizeOrSpeed%%"
				OmitFramePointers="FALSE"
				AdditionalIncludeDirectories="%%includeDirectories_optimized%%"
				PreprocessorDefinitions="%%defines_optimized%%"
				MinimalRebuild="%%minimalRebuild%%"
				RuntimeLibrary="1"
				EnableFunctionLevelLinking="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_o.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_o%%"
				CompileAs="0"
				UseFullPaths="TRUE"
				TreatWChar_tAsBuiltInType="FALSE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLinkerTool"
				AdditionalDependencies="%%libraries_optimized%%"
				OutputFile="$(OutDir)/$(ProjectName)_o.exe"
				LinkIncremental="%%incremental_o%%"
				AdditionalLibraryDirectories="%%libraryDirectories_optimized%%"
				IgnoreDefaultLibraryNames="%%ignoreLibraries_optimized%%"
				GenerateDebugInformation="TRUE"
				ProgramDatabaseFile="$(OutDir)/$(ProjectName)_o.pdb"
				SubSystem="2"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="_DEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
		<Configuration
			Name="Release|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="1"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="2"
				InlineFunctionExpansion="1"
				EnableIntrinsicFunctions="TRUE"
				FavorSizeOrSpeed="1"
				OmitFramePointers="TRUE"
				AdditionalIncludeDirectories="%%includeDirectories_release%%"
				PreprocessorDefinitions="%%defines_release%%"
				StringPooling="TRUE"
				RuntimeLibrary="0"
				EnableFunctionLevelLinking="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_r.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_r%%"
				CompileAs="0"
				UseFullPaths="TRUE"
				TreatWChar_tAsBuiltInType="FALSE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLinkerTool"
				AdditionalDependencies="%%libraries_release%%"
				OutputFile="$(OutDir)/$(ProjectName)_r.exe"
				LinkIncremental="%%incremental_r%%"
				AdditionalLibraryDirectories="%%libraryDirectories_release%%"
				IgnoreDefaultLibraryNames="%%ignoreLibraries_release%%"
				GenerateDebugInformation="TRUE"
				ProgramDatabaseFile="$(OutDir)/$(ProjectName)_r.pdb"
				SubSystem="2"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="NDEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
	</Configurations>
	<References>
	</References>
	<Files>
		<Filter
			Name="Source Files"
			Filter="cpp;c;rc"
			>
%%sources%%
		</Filter>
		<Filter
			Name="Header Files"
			Filter="def;h;hpp;inl"
			>
%%headers%%
		</Filter>
		<Filter
			Name="Ui Files"
			Filter="ui"
			>
%%uis%%
		</Filter>
		<Filter
			Name="Ui Generated Files"
			Filter=""
			>
			<Filter
				Name="Debug"
				Filter=""
				>
				<Filter
					Name="Debug Ui Source Files"
					Filter=""
					>
%%uiGeneratedSources_debug%%
				</Filter>
				<Filter
					Name="Debug Ui Header Files"
					Filter=""
					>
%%uiGeneratedHeaders_debug%%
				</Filter>
			</Filter>
			<Filter
				Name="Optimized"
				Filter=""
				>
				<Filter
					Name="Optimized Ui Source Files"
					Filter=""
					>
%%uiGeneratedSources_optimized%%
				</Filter>
				<Filter
					Name="Optimized Ui Header Files"
					Filter=""
					>
%%uiGeneratedHeaders_optimized%%
				</Filter>
			</Filter>
			<Filter
				Name="Release"
				Filter=""
				>
				<Filter
					Name="Release Ui Source Files"
					Filter=""
					>
%%uiGeneratedSources_release%%
				</Filter>
				<Filter
					Name="Release Ui Header Files"
					Filter=""
					>
%%uiGeneratedHeaders_release%%
				</Filter>
			</Filter>
		</Filter>
%%resource%%
%%template%%
	</Files>
	<Globals>
	</Globals>
</VisualStudioProject>
@;

$template_console = q@
<?xml version="1.0" encoding="Windows-1252"?>
<VisualStudioProject
	ProjectType="Visual C++"
	Version="8.00"
	Name="%%project%%"
	ProjectGUID="{%%guid%%}"
	Keyword="Win32Proj"
	>
	<Platforms>
		<Platform
			Name="Win32"
		/>
	</Platforms>
	<ToolFiles>
	</ToolFiles>
	<Configurations>
		<Configuration
			Name="Debug|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="1"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="0"
				InlineFunctionExpansion="%%debugInline%%"
				AdditionalIncludeDirectories="%%includeDirectories_debug%%"
				PreprocessorDefinitions="%%defines_debug%%"
				MinimalRebuild="%%minimalRebuild%%"
				BasicRuntimeChecks="3"
				RuntimeLibrary="1"
				EnableFunctionLevelLinking="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_d.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_d%%"
				CompileAs="0"
				UseFullPaths="TRUE"
				TreatWChar_tAsBuiltInType="FALSE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLinkerTool"
				AdditionalDependencies="%%libraries_debug%%"
				OutputFile="$(OutDir)/$(ProjectName)_d.exe"
				LinkIncremental="%%incremental_d%%"
				AdditionalLibraryDirectories="%%libraryDirectories_debug%%"
				IgnoreDefaultLibraryNames="%%ignoreLibraries_debug%%"
				GenerateDebugInformation="TRUE"
				ProgramDatabaseFile="$(OutDir)/$(ProjectName)_d.pdb"
				SubSystem="1"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="_DEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
		<Configuration
			Name="Optimized|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="1"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="3"
				InlineFunctionExpansion="1"
				EnableIntrinsicFunctions="TRUE"
				FavorSizeOrSpeed="1"
				OmitFramePointers="FALSE"
				AdditionalIncludeDirectories="%%includeDirectories_optimized%%"
				PreprocessorDefinitions="%%defines_optimized%%"
				MinimalRebuild="%%minimalRebuild%%"
				RuntimeLibrary="1"
				EnableFunctionLevelLinking="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_o.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_o%%"
				CompileAs="0"
				UseFullPaths="TRUE"
				TreatWChar_tAsBuiltInType="FALSE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLinkerTool"
				AdditionalDependencies="%%libraries_optimized%%"
				OutputFile="$(OutDir)/$(ProjectName)_o.exe"
				LinkIncremental="%%incremental_o%%"
				AdditionalLibraryDirectories="%%libraryDirectories_optimized%%"
				IgnoreDefaultLibraryNames="%%ignoreLibraries_optimized%%"
				GenerateDebugInformation="TRUE"
				ProgramDatabaseFile="$(OutDir)/$(ProjectName)_o.pdb"
				SubSystem="1"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="_DEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
		<Configuration
			Name="Release|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="1"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="2"
				InlineFunctionExpansion="1"
				EnableIntrinsicFunctions="TRUE"
				FavorSizeOrSpeed="1"
				OmitFramePointers="TRUE"
				AdditionalIncludeDirectories="%%includeDirectories_release%%"
				PreprocessorDefinitions="%%defines_release%%"
				StringPooling="TRUE"
				RuntimeLibrary="0"
				EnableFunctionLevelLinking="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_r.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_r%%"
				CompileAs="0"
				UseFullPaths="TRUE"
				TreatWChar_tAsBuiltInType="FALSE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLinkerTool"
				AdditionalDependencies="%%libraries_release%%"
				OutputFile="$(OutDir)/$(ProjectName)_r.exe"
				LinkIncremental="%%incremental_r%%"
				AdditionalLibraryDirectories="%%libraryDirectories_release%%"
				IgnoreDefaultLibraryNames="%%ignoreLibraries_release%%"
				GenerateDebugInformation="TRUE"
				ProgramDatabaseFile="$(OutDir)/$(ProjectName)_r.pdb"
				SubSystem="1"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="NDEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
	</Configurations>
	<References>
	</References>
	<Files>
		<Filter
			Name="Source Files"
			Filter="cpp;c;rc"
			>
%%sources%%
		</Filter>
		<Filter
			Name="Header Files"
			Filter="def;h;hpp;inl"
			>
%%headers%%
		</Filter>
%%template%%
	</Files>
	<Globals>
	</Globals>
</VisualStudioProject>
@;

$template_library = q@
<?xml version="1.0" encoding="Windows-1252"?>
<VisualStudioProject
	ProjectType="Visual C++"
	Version="8.00"
	Name="%%project%%"
	ProjectGUID="{%%guid%%}"
	Keyword="Win32Proj"
	>
	<Platforms>
		<Platform
			Name="Win32"
		/>
	</Platforms>
	<ToolFiles>
	</ToolFiles>
	<Configurations>
		<Configuration
			Name="Debug|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="4"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="0"
				InlineFunctionExpansion="%%debugInline%%"
				AdditionalIncludeDirectories="%%includeDirectories_debug%%"
				PreprocessorDefinitions="%%defines_debug%%"
				MinimalRebuild="%%minimalRebuild%%"
				BasicRuntimeChecks="3"
				RuntimeLibrary="1"
				EnableFunctionLevelLinking="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_d.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_d%%"
				CompileAs="0"
				UseFullPaths="TRUE"
				TreatWChar_tAsBuiltInType="FALSE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLibrarianTool"
				OutputFile="$(OutDir)\$(ProjectName).lib"
				SuppressStartupBanner="TRUE"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="_DEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
		<Configuration
			Name="Optimized|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="4"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="3"
				InlineFunctionExpansion="1"
				EnableIntrinsicFunctions="TRUE"
				FavorSizeOrSpeed="1"
				OmitFramePointers="FALSE"
				AdditionalIncludeDirectories="%%includeDirectories_optimized%%"
				PreprocessorDefinitions="%%defines_optimized%%"
				MinimalRebuild="%%minimalRebuild%%"
				RuntimeLibrary="1"
				EnableFunctionLevelLinking="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_o.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_o%%"
				CompileAs="0"
				UseFullPaths="TRUE"
				TreatWChar_tAsBuiltInType="FALSE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLibrarianTool"
				OutputFile="$(OutDir)\$(ProjectName).lib"
				SuppressStartupBanner="TRUE"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="_DEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
		<Configuration
			Name="Release|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="4"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCLCompilerTool"
				Optimization="2"
				InlineFunctionExpansion="1"
				EnableIntrinsicFunctions="TRUE"
				FavorSizeOrSpeed="1"
				OmitFramePointers="TRUE"
				AdditionalIncludeDirectories="%%includeDirectories_release%%"
				PreprocessorDefinitions="%%defines_release%%"
				StringPooling="TRUE"
				RuntimeLibrary="0"
				EnableFunctionLevelLinking="TRUE"
				ForceConformanceInForLoopScope="TRUE"
				RuntimeTypeInfo="TRUE"
				UsePrecompiledHeader="%%usepch%%"
				PrecompiledHeaderThrough="%%pch%%"
				PrecompiledHeaderFile="$(OutDir)\$(ProjectName).pch"
				AssemblerListingLocation="$(OutDir)/"
				ObjectFile="$(OutDir)/"
				ProgramDataBaseFileName="$(OutDir)\$(ProjectName)_r.pdb"
				WarningLevel="4"
				WarnAsError="TRUE"
				SuppressStartupBanner="TRUE"
				Detect64BitPortabilityProblems="FALSE"
				DebugInformationFormat="%%dbgInfo_r%%"
				CompileAs="0"
				UseFullPaths="TRUE"
				TreatWChar_tAsBuiltInType="FALSE"
			/>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCLibrarianTool"
				OutputFile="$(OutDir)\$(ProjectName).lib"
				SuppressStartupBanner="TRUE"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
			<Tool
				Name="VCPreLinkEventTool"
			/>
			<Tool
				Name="VCResourceCompilerTool"
				PreprocessorDefinitions="NDEBUG"
				Culture="1033"
			/>
			<Tool
				Name="VCWebServiceProxyGeneratorTool"
			/>
			<Tool
				Name="VCXMLDataGeneratorTool"
			/>
			<Tool
				Name="VCManagedWrapperGeneratorTool"
			/>
			<Tool
				Name="VCAuxiliaryManagedWrapperGeneratorTool"
			/>
		</Configuration>
	</Configurations>
	<References>
	</References>
	<Files>
		<Filter
			Name="Source Files"
			Filter="cpp;c;rc"
			>
%%sources%%
		</Filter>
		<Filter
			Name="Header Files"
			Filter="def;h;hpp;inl"
			>
%%headers%%
		</Filter>
%%template%%
	</Files>
	<Globals>
	</Globals>
</VisualStudioProject>
@;

$template_utility = q@
<?xml version="1.0" encoding="Windows-1252"?>
<VisualStudioProject
	ProjectType="Visual C++"
	Version="8.00"
	Name="%%project%%"
	ProjectGUID="{%%guid%%}"
	Keyword="Win32Proj"
	>
	<Platforms>
		<Platform
			Name="Win32"
		/>
	</Platforms>
	<ToolFiles>
	</ToolFiles>
	<Configurations>
		<Configuration
			Name="Debug|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="10"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
		</Configuration>
		<Configuration
			Name="Optimized|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="10"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
		</Configuration>
		<Configuration
			Name="Release|Win32"
			OutputDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			IntermediateDirectory="..\..\..\..\..\..\compile\win32\$(ProjectName)\$(ConfigurationName)"
			ConfigurationType="10"
			UseOfMFC="0"
			ATLMinimizesCRunTimeLibraryUsage="FALSE"
			CharacterSet="2"
			>
			<Tool
				Name="VCCustomBuildTool"
			/>
			<Tool
				Name="VCMIDLTool"
			/>
			<Tool
				Name="VCPostBuildEventTool"
			/>
			<Tool
				Name="VCPreBuildEventTool"
			/>
		</Configuration>
	</Configurations>
	<References>
	</References>
	<Files>
		<Filter
			Name="Source Files"
			Filter="cpp;c;rc"
			>
%%sources%%
		</Filter>
		<Filter
			Name="Header Files"
			Filter="def;h;hpp;inl"
			>
%%headers%%
		</Filter>
%%template%%
%%resource%%
	</Files>
	<Globals>
	</Globals>
</VisualStudioProject>
@;

	$template_resource = q@
		<Filter
			Name="Resource Files"
			Filter="ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe"
			>
%%resources%%
		</Filter>
@;

	$template_template = q@
		<Filter
			Name="Template Files"
			Filter="template"
			>
%%templates%%
		</Filter>
@;

	$mocHeader = q@
				<FileConfiguration
					Name="Debug|Win32"
					>
					<Tool
						Name="VCCustomBuildTool"
						Description="moc $(InputName)"
						CommandLine="..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\moc -i $(InputPath) -o $(TargetDir)$(InputName).moc"
						Outputs="$(TargetDir)$(InputName).moc"
					/>
				</FileConfiguration>
				<FileConfiguration
					Name="Optimized|Win32"
					>
					<Tool
						Name="VCCustomBuildTool"
						Description="moc $(InputName)"
						CommandLine="..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\moc -i $(InputPath) -o $(TargetDir)$(InputName).moc"
						Outputs="$(TargetDir)$(InputName).moc"
					/>
				</FileConfiguration>
				<FileConfiguration
					Name="Release|Win32"
					>
					<Tool
						Name="VCCustomBuildTool"
						Description="moc $(InputName)"
						CommandLine="..\..\..\..\..\..\external\3rd\library\qt\%%qt_version%%\bin\moc -i $(InputPath) -o $(TargetDir)$(InputName).moc"
						Outputs="$(TargetDir)$(InputName).moc"
					/>
				</FileConfiguration>
@;

	$excludeFromBuild = q@				
				<FileConfiguration
					Name="Debug|Win32"
					ExcludedFromBuild="TRUE"
					>
					<Tool
						Name="VCCustomBuildTool"
					/>
				</FileConfiguration>
				<FileConfiguration
					Name="Optimized|Win32"
					ExcludedFromBuild="TRUE"
					>
					<Tool
						Name="VCCustomBuildTool"
					/>
				</FileConfiguration>
				<FileConfiguration
					Name="Release|Win32"
					ExcludedFromBuild="TRUE"
					>
					<Tool
						Name="VCCustomBuildTool"
					/>
				</FileConfiguration>
@;

	$createPrecompiledHeader = q@				
				<FileConfiguration
					Name="Debug|Win32"
					>
					<Tool
						Name="VCCLCompilerTool"
						UsePrecompiledHeader="1"
					/>
				</FileConfiguration>
				<FileConfiguration
					Name="Optimized|Win32"
					>
					<Tool
						Name="VCCLCompilerTool"
						UsePrecompiledHeader="1"
					/>
				</FileConfiguration>
				<FileConfiguration
					Name="Release|Win32"
					>
					<Tool
						Name="VCCLCompilerTool"
						UsePrecompiledHeader="1"
					/>
				</FileConfiguration>
@;

# ---------------------------------------------------------------------

}
