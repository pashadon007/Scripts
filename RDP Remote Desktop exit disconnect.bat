@echo off
setlocal enabledelayedexpansion

REM Loop through session IDs from 1 to 5
for /L %%A in (1,1,5) do (
    echo Attempting to connect to session ID %%A...
    
    REM Run 'tscon' with the current session ID
    tscon %%A /dest:console

    REM Check the error level to determine if the connection was successful
    if !errorlevel! equ 0 (
        echo Successfully connected to session ID %%A.
        exit /b 0
    ) else (
        echo Connection to session ID %%A failed.
    )
)

echo Failed to connect to any session IDs.
exit /b 1
