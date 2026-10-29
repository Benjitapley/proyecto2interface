@echo off
setlocal
cd /d "%~dp0"
echo  Iniciando Servidor Flask (API REST + Matplotlib + DB)
echo  Panel Web: http://127.0.0.1:7070
.\.venv\Scripts\python.exe -m servidor.app
pause
