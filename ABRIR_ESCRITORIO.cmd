@echo off
setlocal
cd /d "%~dp0"

if not exist "%~dp0lazarus\datalogger.exe" (
    echo No se encontro lazarus\datalogger.exe.
    echo Compila el proyecto con este comando desde la carpeta principal:
    echo powershell -NoProfile -ExecutionPolicy Bypass -File .\lazarus\compilar.ps1
    pause
    exit /b 1
)

rem Abre la aplicacion de escritorio creada en Lazarus.
start "" "%~dp0lazarus\datalogger.exe"
