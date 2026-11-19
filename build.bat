@echo off
rem Builds BatteryBar.exe with MinGW-w64 (g++ and windres must be on PATH).
rem Every .cpp under src\ is compiled on its own and the objects are linked at the end,
rem because one g++ call with all sources is longer than the command line cmd.exe accepts.
rem A file is only recompiled when its .cpp is newer than its .o, so a relink is quick.
rem Delete the build\obj folder to force a full rebuild.
setlocal enabledelayedexpansion
cd /d "%~dp0"
if not exist build mkdir build
if not exist build\obj mkdir build\obj
rem Every lang\*.txt is a built-in UI language: joined into one resource, each after an "@file <name>" line.
(for %%f in (lang\*.txt) do (echo @file %%~nf& type "%%f"& echo.)) > build\languages.txt
windres -i res\app.rc -o build\app_res.o --include-dir res --include-dir build || exit /b 1
set FLAGS=-std=c++17 -Os -Wall -Wno-missing-field-initializers -ffunction-sections -fdata-sections -D_WIN32_WINNT=0x0A00 -DWINVER=0x0A00
set OBJECTS=
for /f "delims=" %%f in ('dir /s /b "src\*.cpp"') do (
    set "FILE=%%f"
    set "NAME=!FILE:%~dp0src\=!"
    set "NAME=!NAME:\=_!"
    set "OBJECT=build\obj\!NAME:.cpp=.o!"
    set "BUILDIT=1"
    if exist "!OBJECT!" (
        for %%s in ("!FILE!") do set "SRCSTAMP=%%~ts"
        for %%o in ("!OBJECT!") do set "OBJSTAMP=%%~to"
        if "!OBJSTAMP!" GTR "!SRCSTAMP!" set "BUILDIT="
    )
    if defined BUILDIT (
        echo Compiling !NAME!
        g++ %FLAGS% -c "!FILE!" -o "!OBJECT!" || exit /b 1
    )
    set OBJECTS=!OBJECTS! "!OBJECT!"
)
echo Linking build\BatteryBar.exe
rem The previous exe has to go first: Windows keeps it locked for a moment after it has been run.
if exist build\BatteryBar.exe del /q build\BatteryBar.exe 2>nul
if exist build\BatteryBar.exe (
    echo Cannot replace build\BatteryBar.exe - it is still in use. Close the program and run this again.
    exit /b 1
)
g++ -municode -mwindows -static -s -Wl,--gc-sections ^
    !OBJECTS! ^
    build\app_res.o -o build\BatteryBar.exe ^
    -lhid -lsetupapi -lcfgmgr32 -lole32 -loleaut32 -lcomctl32 -lgdi32 -lruntimeobject -lws2_32 -luser32 -lshell32 -lcomdlg32 -luuid || exit /b 1
echo Built build\BatteryBar.exe