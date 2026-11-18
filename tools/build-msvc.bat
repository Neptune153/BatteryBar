@echo off
rem Local build for this machine: MSVC 2022 + Windows SDK 10.0.22621.0.
rem Everything this script produces stays inside the repository (build\, temp\); nothing goes to %TEMP%.
rem Run it from anywhere:  temp\rebuild.bat
setlocal
call "D:\MIcrosoft Visual Studio2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul || goto :fail
cd /d "%~dp0.."
if not exist build\msvc mkdir build\msvc

rem Every lang\*.txt becomes one resource, each introduced by "@file <name>".
( for %%f in (lang\*.txt) do ( echo @file %%~nf& type "%%f"& echo. ) ) > build\languages.txt
rc /nologo /fo build\msvc\app_res.res /I res /I build res\app.rc || goto :fail

set SDKINC=/I "D:\Windows Kits\10\Include\10.0.22621.0\um" /I "D:\Windows Kits\10\Include\10.0.22621.0\shared" /I "D:\Windows Kits\10\Include\10.0.22621.0\ucrt" /I "D:\Windows Kits\10\Include\10.0.22621.0\winrt"
set FLAGS=/nologo /c /std:c++17 /EHsc /O1 /MT /W3 /DNOMINMAX /DUNICODE /D_UNICODE /D_WIN32_WINNT=0x0A00 /DWINVER=0x0A00 /D_CRT_SECURE_NO_WARNINGS
set INC=%SDKINC%

del /q build\msvc\*.obj 2>nul
for /r "src" %%f in (*.cpp) do (
    cl %FLAGS% %INC% /Fo:build\msvc\ /Tp "%%f" || goto :fail
)

link /nologo /SUBSYSTEM:WINDOWS /ENTRY:wWinMainCRTStartup /OUT:build\msvc\BatteryBar.exe ^
    build\msvc\*.obj build\msvc\app_res.res ^
    user32.lib gdi32.lib advapi32.lib ole32.lib oleaut32.lib comctl32.lib hid.lib setupapi.lib ^
    cfgmgr32.lib runtimeobject.lib ws2_32.lib shell32.lib comdlg32.lib uuid.lib windowsapp.lib || goto :fail

echo BUILT build\msvc\BatteryBar.exe
exit /b 0

:fail
echo FAILED
exit /b 1
