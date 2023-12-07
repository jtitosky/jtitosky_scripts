@echo off
rem Instance which represents final desired state.
set "ServerIP=<N-CENTRAL SERVER IP/HOSTNAME>"

rem Event Viewer/Logging Variables.
set DEBUG=1
set TESTING=1
set LOGT=APPLICATION
set "SO=Insight - NCentral Replace"

rem Insight Installer variables
set "INSTALLERFOLDER=D:"
set "INSTALLER=<INSTALLER>.exe"
set "INSTALLERFULL=%INSTALLERFOLDER%\%INSTALLER%"
set "INSTALLCMD=%INSTALLERFULL% -ai"



CALL :CHECK_ADMIN IS_ADMIN
if %TESTING% NEQ 1 (
	if %IS_ADMIN% NEQ 1 goto END
)

CALL :LOG %IS_ADMIN% INFORMATION,100,"Script starting conversion to '%ServerIP%' instance."
SET	"PROGRAMFILES=%SYSTEMDRIVE%\Program Files"
SET "REGSOFTWARE=HKLM\SOFTWARE"
if %PROCESSOR_ARCHITECTURE% EQU  AMD64 ( 
	SET "PROGRAMFILES=%PROGRAMFILES% (x86)"
	SET "REGSOFTWARE=%REGSOFTWARE%\WOW6432Node"
) 

set "NABLEREG=%REGSOFTWARE%\N-able Technologies\Windows Agent"

CALL :LOG %IS_ADMIN% INFORMATION,100,"Querying '%NABLEREG%' to see if N-Central is installed."

reg query "%NABLEREG%" > nul 2> nul
if %ERRORLEVEL% EQU 0 goto INSTALLED
goto NOTINSTALLED


:INSTALLED
CALL :LOG %IS_ADMIN% INFORMATION,100,"Reg key found. N-Central appears to be installed." 

set "SERVERCONFIG=%PROGRAMFILES%\N-able Technologies\Windows Agent\config\ServerConfig.xml"


if not exist "%SERVERCONFIG%" (
	CALL :LOG %IS_ADMIN% ERROR,101,"N-Central appears to be installed, but the config file '%SERVERCONFIG%' doesn't exist. Can't check if it's ours."
	goto END
)

CALL :LOG %IS_ADMIN% INFORMATION,100,"Checking config file located at '%SERVERCONFIG%'."

find /c "%ServerIP%" "%SERVERCONFIG%" >NUL
if %errorlevel% EQU 1 goto INSTALLEDINCUMBENT

CALL :LOG %IS_ADMIN% INFORMATION,100,"The string %ServerIP% is present in the file '%SERVERCONFIG%'. It appears that the Insight N-Central agent is already installed"

goto END


:INSTALLEDINCUMBENT
CALL :LOG %IS_ADMIN% INFORMATION,100,"The string '%ServerIP%' is present in the file '%SERVERCONFIG%'. It appears that the Insight N-Central agent is already installed"

set "UNINSTALLREG=%REGSOFTWARE%\N-able Technologies\Windows Agent"

CALL :LOG %IS_ADMIN% INFORMATION,100,"Retrieving uninstall string from '%UNINSTALLREG%'."

FOR /F "usebackq tokens=2,* skip=2" %%L IN (
    `reg query "%UNINSTALLREG%" /v DotNetAgentUninstallCmd`
) DO "SET UNINSTALLCMD=%%M"

CALL :LOG %IS_ADMIN% INFORMATION,100,"Uninstall command found to be '%UNINSTALLCMD%'"
CALL :LOG %IS_ADMIN% INFORMATION,100,"Running '%UNINSTALLCMD%'"
%UNINSTALLCMD%
if %ERRORLEVEL% EQU 0 (
	CALL :LOG %IS_ADMIN% INFORMATION,100,"Uninstall of incumbent's N-Central was successful."
) else (
	CALL :LOG %IS_ADMIN% ERROR,100,"Uninstall of incumbent's N-Central FAILED."
)

goto INSTALLONSTART
goto END


:NOTINSTALLED
CALL :LOG %IS_ADMIN% INFORMATION,100,"Reg key not found. N-Central appears to NOT be installed." 
goto INSTALLNOW

goto END


:INSTALLONSTART
CALL :LOG %IS_ADMIN% INFORMATION,100,"Attempting to setup install on next start."
CALL :INSTALLEREXISTANCE EXISTS
if %EXISTS% EQU 0 GOTO END
set "RUNONCE=HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunOnce"
set "RUNONCEVALUE=!Install Insight N-Central"

CALL :LOG %IS_ADMIN% INFORMATION,100,"Creating Run Once CMD 'Key: %RUNONCE%', 'Value: %RUNONCEVALUE%', 'Data: %INSTALLCMD%'"
REG ADD %RUNONCE% /v "%RUNONCEVALUE%" /d "%INSTALLCMD%"
if %ERRORLEVEL% EQU 0 (
	CALL :LOG %IS_ADMIN% INFORMATION,100,"Successfully added RunOnce Key."
) else (
	CALL :LOG %IS_ADMIN% ERROR,101,"FAILED to add RunOnce Key."
)

goto END

:INSTALLNOW
CALL :LOG %IS_ADMIN% INFORMATION,100,"Attempting to install via %INSTALLCMD%"
CALL :INSTALLEREXISTANCE EXISTS
if %EXISTS% EQU 0 GOTO END

%INSTALLCMD%
if %ERRORLEVEL% EQU 0 (
	CALL :LOG %IS_ADMIN% INFORMATION,100,"Successfully installed."
) else (
	CALL :LOG %IS_ADMIN% ERROR,101,"FAILED to install. Errorlevel: '%ERRORLEVEL%'."
)

goto END


rem Callable functions that return.
:INSTALLEREXISTANCE
CALL :LOG %IS_ADMIN% INFORMATION,100,"Checking if installer exists at '%INSTALLERFULL%'"
if exist "%INSTALLERFULL%" (
	CALL :LOG %IS_ADMIN% INFORMATION,100,"Installer '%INSTALLERFULL%' exists"
	set %~1=1
) else (
	CALL :LOG %IS_ADMIN% ERROR,100,"Installer '%INSTALLERFULL%' does NOT exists"
	set %~1=0
)

EXIT /B 0
goto END


:CHECK_ADMIN
    CALL :LOG %IS_ADMIN% INFORMATION,100,"Administrative permissions required. Detecting permissions."

    net session >nul 2>&1
    if %errorLevel% == 0 (
        CALL :LOG %IS_ADMIN% INFORMATION,100,"Administrative permissions confirmed."
		set %~1=1
    ) else (
        CALL :LOG %IS_ADMIN% ERROR,101,"Current permissions inadequate."
		set %~1=0
    )
EXIT /B 0
goto END

:LOG 
set IS_ADMIN=%~1
set TYPE=%~2
set ID=%~3
set DESCRIPTION=%~4


rem !! Uncomment to write to event log
if %IS_ADMIN% EQU 1 ( 
	EVENTCREATE /T %TYPE% /L %LOGT% /SO "%SO%" /ID %ID% /D "%DESCRIPTION%" > nul 2> nul
)
if %DEBUG%==1 ECHO %DATE% - %TIME% :: %TYPE% :: %DESCRIPTION%

set "TYPE="
set "ID="
set "DESCRIPTION="


EXIT /B 0
goto END

:END
