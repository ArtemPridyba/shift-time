@echo off
rem 1. Look for godot in PATH
where godot >nul 2>nul
if not errorlevel 1 (
    set "GODOT=godot"
) else if not defined GODOT (
    rem 2. Not in PATH: use the default location
    set "GODOT=C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
)

rem 3. If it is not the PATH command, check that the exe exists
if /i not "%GODOT%"=="godot" if not exist "%GODOT%" (
    echo Godot not found: %GODOT%
    echo Add godot to PATH or set the GODOT variable to the full path of the exe.
    pause
    exit /b 1
)

rem 4. Import first: after a fresh clone or a new class_name the tests fail without it
echo === Import ===
"%GODOT%" --headless --path "%~dp0game" --import >nul 2>&1

rem 5. Rule tests: only failures and the total. Green is "N tests, 0 failed"
echo === Rule tests ===
"%GODOT%" --headless --path "%~dp0game" --script res://tests/test_runner.gd 2>&1 | findstr /C:"FAIL" /C:"SCRIPT ERROR" /C:"tests,"

rem 6. UI smoke test. Green is "UI smoke test: 0 failed"
echo === UI smoke test ===
"%GODOT%" --headless --path "%~dp0game" --script res://tests/ui_smoke_test.gd 2>&1 | findstr /C:"FAIL" /C:"SCRIPT ERROR" /C:"failed"

rem 7. An agent runs "run_tests.bat nopause": pause would wait for a key forever
if /i not "%~1"=="nopause" pause
