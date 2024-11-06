@ECHO ON

setlocal ENABLEEXTENSIONS
setlocal ENABLEDELAYEDEXPANSION

call "C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\vcvarsall.bat" x86

Set BaseDir=C:\Build\admin\
Set Build=%BaseDir%Build
Set PubDir=%BaseDir%Distributions
Set RNDir=%BaseDir%ReleaseNotes\
Set RelDir=%BaseDir%bin\Release\

PUSHD "%Build%"

ConsoleUtil.exe fv "%RelDir%Central.exe">ver.txt
for /f %%i in (ver.txt) do (
	set ver=%%i
	del ver.txt
	)
Set /p relNo=Enter Publication Version Enter for default(!ver!):

if not defined relNO set relNo=!ver!

echo File Version:%relNo%
echo File Version:%relNo% >Version.txt

ConsoleUtil.exe av "%RelDir%admin.exe">ver.txt
for /f %%i in (ver.txt) do (
	set ver=%%i
	del ver.txt
	)
echo Assembly Version:!ver!
echo Version:!ver! >>Version.txt
echo Supporting Assembly Versions:>>Version.txt

set central=%PubDir%\admin
set centralVerDir=%central%\Application Files\Central.%relNo%
set newCentralVerDir=%centralVerDir:.=_%
set newCentralVer=%newCentralVerDir:~-20%



robocopy "%central%\Application Files" "%PubDir%\pubArchive" /E /MOVE

RD "%central%\Application Files" /s /q

PushD %BaseDir%

if %errorlevel% equ 1 GOTO X

msbuild admin.csproj /target:publish ^
"/property:Configuration=Release;^
PlatformTarget=x86;^
PublishDir=%BaseDir%Distributions\Central\;^
PublishUrl=%BaseDir%Distributions\Central\;^
SolutionDir=%BaseDir%;^
ApplicationVersion=%relNo%;^
ApplicationRevision=%relNo:~-4%;^
PostBuildEvent=VersionTool.exe -vf%BaseDir%GlobalAssemblyInfo.cs;^
DefineConstants=x"

if %errorlevel% equ 1 GOTO X
PopD
robocopy "%basedir%\Plugins\bin\Release" "%PubDir%" *.dll
robocopy "%basedir%\RefDll\CefGlueBinaries" "%PubDir%" *.* /E
DEL %PubDir%\*.deploy
REN %PubDir%\*.dll *.dll.deploy
REN %PubDir%\*.pak *.pak.deploy
REN %PubDir%\*.dat *.dat.deploy

robocopy "%PubDir%" "%newCentralVerDir%" *.deploy

for /r "%BaseDir%Distributions\Central" %%f in (*.dll.deploy) do (
	set file=%%f
	ConsoleUtil.exe av "!file!">ver.txt
	for /f %%i in (ver.txt) do (
		set ver=%%i
		del ver.txt
		)
	echo. ^(!ver!^)  %%~nf>>Version.txt
	set reqDLL=!reqDLL!  %%~nf^(!ver!^)
)

set outDir=\\data\fs01\Private\Sec-Dev\Development Drops\admin v.%relNo%
set clickOnceDir=\\data\FS01\General\DevDocs\CentralDist\DropInstall\ClickOnce

robocopy "%PubDir%" "%outDir%" /E /XD pubArchive prevArchive /xf *.bat *.vbs
robocopy "%outDir%\Q2 Central\Application Files" "%clickOnceDir%" /s

ECHO %newCentralVer%

C:\Build\ConsoleUtil\BuildManifest.exe "%clickOnceDir%\%newCentralVer%\admin.exe.deploy"
powershell.exe -noprofile -executionpolicy Bypass -file C:\Build\Central\AddVersionToXml.ps1 -path %clickOnceDir%\launch.application -backofficeFolder %newCentralVer%

REN Version.txt %relNo%_Version.txt

set htmBody=^<table bgcolor=lightgreen bordercolor=darkgreen border=1^>
set htmBody=!htmBody!^<tr^>^<td colspan=2^>admin^</td^>^</tr^>
set htmBody=!htmBody!^<tr^>^<td^>Product Version ^</td^>^<td^>%SIGVers%^</td^>^</tr^>
set htmBody=!htmBody!^<tr^>^<td^>Host Data Objects Version^</td^>^<td^>%HDOVers%^</td^>^</tr^>
set htmBody=!htmBody!^<tr^>^<td colspan=2^>^&nbsp;^</td^>^</tr^>
set htmBody=!htmBody!^<tr^>^<td colspan=2^>Production Distribution:^<u^>%outDir%\Q2 Central^</u^>^</td^>^</tr^>
set htmBody=!htmBody!^<tr^>^<td colspan=2^>Release Notes:^<a href=http://dev-vm/docs/ReleaseNotes.asp?prod=17^&version=%relNO%^>Follow This Link^</a^>^</td^>^</tr^>
set htmBody=!htmBody!^</table^>

if %errorlevel% equ 1 DO(
ConsoleUtil.exe -de -to:andrea.huetson@gmail.com ^
-Sub:"New Central Release v.%relNo%" -rn:%RNDir%ReleaseNote.xml -rnt:%RNDir%ReleaseNote.xsl ^
-rnout:%relNo%_ReleaseNotes.html -vi:%relNo% -svn:C:\Build\admin -svnmsg:%relNo%_Version.txt ^
-Body:"%htmBody%" ^
-vi:%relNo% -svn:C:\Build\admin ^
-vii:" Supporting Dlls: %reqDLL%" ^
-rnsql:"EXEC dbo.addReleaseNoteCentral 'Product', '{0}'" -usebugzilla

robocopy "." "%outDir%" %relNo%_Version.txt %relNo%_ReleaseNotes.html
POPD
