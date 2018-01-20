@echo off

rem ***
rem * recursively look backwards for a project.lnt directory
rem ***
set project_dir=%@full[.]
do while %@len[%project_dir] gt 3
	if exist %project_dir\project.lnt goto found_project
	set project_dir=%@truename[%project_dir\..]		
enddo

echo no project.lnt file found
quit 1

:found_project

cd %project_dir

rem ***
rem * recursively look backwards for a tools directory
rem ***
set tools_dir=%project_dir
do while %@len[%tools_dir] gt 3
	if exist %tools_dir\tools goto found_tools
	set tools_dir=%@truename[%tools_dir\..]		
enddo

echo no tools directory found
quit 1

:found_tools
set tools_dir=%tools_dir\tools

lint-nt -u -i%LINT_HOME -i%tools_dir\lint project.lnt %$
