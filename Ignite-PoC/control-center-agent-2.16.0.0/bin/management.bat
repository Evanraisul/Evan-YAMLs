::
:: Copyright (C) GridGain Systems. All Rights Reserved.
:: _________        _____ __________________        _____
:: __  ____/___________(_)______  /__  ____/______ ____(_)_______
:: _  / __  __  ___/__  / _  __  / _  / __  _  __ `/__  / __  __ \
:: / /_/ /  _  /    _  /  / /_/ /  / /_/ /  / /_/ / _  /  _  / / /
:: \____/   /_/     /_/   \_,__/   \____/   \__,_/  /_/   /_/ /_/
::
::
:: GridGain Control Center agent configuration utility.
::

@echo off
Setlocal EnableDelayedExpansion

if "%OS%" == "Windows_NT"  setlocal

:: Check JAVA_HOME.
if defined JAVA_HOME  goto checkJdk
    echo %0, ERROR:
    echo JAVA_HOME environment variable is not found.
    echo Please point JAVA_HOME variable to location of JDK 1.8 or later.
    echo You can also download latest JDK at http://java.com/download.
goto error_finish

:checkJdk
:: Check that JDK is where it should be.
if exist "%JAVA_HOME%\bin\java.exe" goto checkJdkVersion
    echo %0, ERROR:
    echo JAVA is not found in JAVA_HOME=%JAVA_HOME%.
    echo Please point JAVA_HOME variable to installation of JDK 1.8 or later.
    echo You can also download latest JDK at http://java.com/download.
goto error_finish

:checkJdkVersion
set cmd="%JAVA_HOME%\bin\java.exe"
for /f "tokens=* USEBACKQ" %%f in (`%cmd% -version 2^>^&1`) do (
    set var=%%f
    goto :LoopEscape
)
:LoopEscape

for /f "tokens=1-3  delims= " %%a in ("%var%") do set JAVA_VER_STR=%%c
set JAVA_VER_STR=%JAVA_VER_STR:"=%

for /f "tokens=1,2 delims=." %%a in ("%JAVA_VER_STR%.x") do set MAJOR_JAVA_VER=%%a& set MINOR_JAVA_VER=%%b
if %MAJOR_JAVA_VER% == 1 set MAJOR_JAVA_VER=%MINOR_JAVA_VER%

if %MAJOR_JAVA_VER% LSS 8 (
    echo %0, ERROR:
    echo The version of JAVA installed in %JAVA_HOME% is incorrect.
    echo Please point JAVA_HOME variable to installation of JDK 1.8 or later.
    echo You can also download latest JDK at http://java.com/download.
    goto error_finish
)

:: Check IGNITE_HOME.
:checkIgniteHome1
if defined IGNITE_HOME goto checkIgniteHome2
    pushd "%~dp0"/..
    set IGNITE_HOME=%CD%
    popd

:checkIgniteHome2
:: Strip double quotes from IGNITE_HOME
set IGNITE_HOME=%IGNITE_HOME:"=%

:: remove all trailing slashes from IGNITE_HOME.
if %IGNITE_HOME:~-1,1% == \ goto removeTrailingSlash
if %IGNITE_HOME:~-1,1% == / goto removeTrailingSlash
goto checkIgniteHome3

:removeTrailingSlash
set IGNITE_HOME=%IGNITE_HOME:~0,-1%
goto checkIgniteHome2

:checkIgniteHome3
if exist "%IGNITE_HOME%\config" goto checkIgniteHome4
    echo %0, ERROR: Ignite installation folder is not found or IGNITE_HOME environment variable is not valid.
    echo Please create IGNITE_HOME environment variable pointing to location of
    echo Ignite installation folder.
    goto error_finish

:checkIgniteHome4

::
:: Set SCRIPTS_HOME - base path to scripts.
::
set SCRIPTS_HOME=%IGNITE_HOME%\bin

:: Remove trailing spaces
for /l %%a in (1,1,31) do if /i "%SCRIPTS_HOME:~-1%" == " " set SCRIPTS_HOME=%SCRIPTS_HOME:~0,-1%

if /i "%SCRIPTS_HOME%\" == "%~dp0" goto setProgName
    echo %0, WARN: IGNITE_HOME environment variable may be pointing to wrong folder: %IGNITE_HOME%

:setProgName
::
:: Set program name.
::
set PROG_NAME=ignite.bat
if "%OS%" == "Windows_NT" set PROG_NAME=%~nx0%

:run

::
:: Set IGNITE_LIBS
::
call "%SCRIPTS_HOME%\include\setenv.bat"
set CP=%IGNITE_LIBS%;%IGNITE_HOME%\libs\optional\ignite-zookeeper\*;%IGNITE_HOME%\libs\optional\control-center-agent\*

::
:: Process 'restart'.
::
set RANDOM_NUMBER_COMMAND="!JAVA_HOME!\bin\java.exe" -cp %CP% org.apache.ignite.startup.cmdline.CommandLineRandomNumberGenerator
for /f "usebackq tokens=*" %%i in (`!RANDOM_NUMBER_COMMAND!`) do set RANDOM_NUMBER=%%i

set RESTART_SUCCESS_FILE="%IGNITE_HOME%\work\ignite_success_%RANDOM_NUMBER%"
set RESTART_SUCCESS_OPT=-DIGNITE_SUCCESS_FILE=%RESTART_SUCCESS_FILE%

::
:: JVM options. See http://java.sun.com/javase/technologies/hotspot/vmoptions.jsp for more details.
::
:: ADD YOUR/CHANGE ADDITIONAL OPTIONS HERE
::
"%JAVA_HOME%\bin\java.exe" -version 2>&1 | findstr "1\.[7]\." > nul
if %ERRORLEVEL% equ 0 (
    if "%MANAGEMENT_JVM_OPTS%" == "" set MANAGEMENT_JVM_OPTS=-Xms256m -Xmx1g
) else (
    if "%MANAGEMENT_JVM_OPTS%" == "" set MANAGEMENT_JVM_OPTS=-Xms256m -Xmx1g
)

::
:: Uncomment to enable experimental commands [--wal]
::
:: set MANAGEMENT_JVM_OPTS=%MANAGEMENT_JVM_OPTS% -DIGNITE_ENABLE_EXPERIMENTAL_COMMAND=true

::
:: Uncomment the following GC settings if you see spikes in your throughput due to Garbage Collection.
::
:: set MANAGEMENT_JVM_OPTS=%MANAGEMENT_JVM_OPTS% -XX:+UseG1GC

::
:: Uncomment if you get StackOverflowError.
:: On 64 bit systems this value can be larger, e.g. -Xss16m
::
:: set MANAGEMENT_JVM_OPTS=%MANAGEMENT_JVM_OPTS% -Xss4m

::
:: Uncomment to set preference to IPv4 stack.
::
:: set MANAGEMENT_JVM_OPTS=%MANAGEMENT_JVM_OPTS% -Djava.net.preferIPv4Stack=true

::
:: Assertions are disabled by default since version 3.5.
:: If you want to enable them - set 'ENABLE_ASSERTIONS' flag to '1'.
::
set ENABLE_ASSERTIONS=0

::
:: Set '-ea' options if assertions are enabled.
::
if %ENABLE_ASSERTIONS% == 1 set MANAGEMENT_JVM_OPTS=%MANAGEMENT_JVM_OPTS% -ea

:run_java

::
:: Set main class to start service (grid node by default).
::

if "%MAIN_CLASS%" == "" set MAIN_CLASS=org.gridgain.control.agent.commandline.ManagementCommandHandler

::
:: Remote debugging (JPDA).
:: Uncomment and change if remote debugging is required.
:: set MANAGEMENT_JVM_OPTS=-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8787 %MANAGEMENT_JVM_OPTS%
::

::
:: Final MANAGEMENT_JVM_OPTS for Java 9+ compatibility
::
if %MAJOR_JAVA_VER% == 8 (
    set MANAGEMENT_JVM_OPTS= ^
    -XX:+AggressiveOpts ^
    %MANAGEMENT_JVM_OPTS%
)

if %MAJOR_JAVA_VER% GEQ 9 if %MAJOR_JAVA_VER% LSS 11 (
    set MANAGEMENT_JVM_OPTS= ^
    -XX:+AggressiveOpts ^
    --add-exports=java.base/jdk.internal.misc=ALL-UNNAMED ^
    --add-exports=java.base/sun.nio.ch=ALL-UNNAMED ^
    --add-exports=java.management/com.sun.jmx.mbeanserver=ALL-UNNAMED ^
    --add-exports=jdk.internal.jvmstat/sun.jvmstat.monitor=ALL-UNNAMED ^
    --add-exports=java.base/sun.reflect.generics.reflectiveObjects=ALL-UNNAMED ^
    --add-modules=java.xml.bind ^
    %MANAGEMENT_JVM_OPTS%
)

if %MAJOR_JAVA_VER% GEQ 11 (
    set MANAGEMENT_JVM_OPTS= ^
    --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED ^
    --add-opens=java.base/sun.nio.ch=ALL-UNNAMED ^
    --add-opens=java.management/com.sun.jmx.mbeanserver=ALL-UNNAMED ^
    --add-opens=jdk.internal.jvmstat/sun.jvmstat.monitor=ALL-UNNAMED ^
    --add-opens=java.base/sun.reflect.generics.reflectiveObjects=ALL-UNNAMED ^
    --add-opens=java.base/java.nio=ALL-UNNAMED ^
    --add-opens=jdk.management/com.sun.management.internal=ALL-UNNAMED ^
    --add-opens=java.base/java.io=ALL-UNNAMED ^
    --add-opens=java.base/java.util=ALL-UNNAMED ^
    --add-opens=java.base/java.util.concurrent=ALL-UNNAMED ^
    --add-opens=java.base/java.util.concurrent.locks=ALL-UNNAMED ^
    --add-opens=java.base/java.lang=ALL-UNNAMED ^
    --add-opens=java.base/java.time=ALL-UNNAMED ^
    %MANAGEMENT_JVM_OPTS%
)

if %MAJOR_JAVA_VER% GEQ 9 if %MAJOR_JAVA_VER% LSS 17 (
    set MANAGEMENT_JVM_OPTS= ^
    --illegal-access=permit ^
    %MANAGEMENT_JVM_OPTS%
)

if "%INTERACTIVE%" == "1" (
    "%JAVA_HOME%\bin\java.exe" %MANAGEMENT_JVM_OPTS% %QUIET% %RESTART_SUCCESS_OPT% ^
    -DIGNITE_UPDATE_NOTIFIER=false -DIGNITE_HOME="%IGNITE_HOME%" -DIGNITE_PROG_NAME="%PROG_NAME%" %JVM_XOPTS% ^
    -cp "%CP%" %MAIN_CLASS% %*
) else (
    "%JAVA_HOME%\bin\java.exe" %MANAGEMENT_JVM_OPTS% %QUIET% %RESTART_SUCCESS_OPT% ^
    -DIGNITE_UPDATE_NOTIFIER=false -DIGNITE_HOME="%IGNITE_HOME%" -DIGNITE_PROG_NAME="%PROG_NAME%" %JVM_XOPTS% ^
    -cp "%CP%" %MAIN_CLASS% %*
)

set JAVA_ERRORLEVEL=%ERRORLEVEL%

:: errorlevel 130 if aborted with Ctrl+c
if %JAVA_ERRORLEVEL%==130 goto finish

:: Exit if first run unsuccessful (Loader must create file).
if not exist %RESTART_SUCCESS_FILE% goto error_finish
del %RESTART_SUCCESS_FILE%

goto run_java

:finish
if not exist %RESTART_SUCCESS_FILE% goto error_finish
del %RESTART_SUCCESS_FILE%

:error_finish

if not "%NO_PAUSE%" == "1" pause

goto :eof
