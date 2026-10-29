@echo off
setlocal
cd /d "%~dp0"
echo  Iniciando Simulador Serial (PMS7003ST hacia COM2)
echo  Recuerda haber iniciado VSPE con el Connector COM2.
.\.venv\Scripts\python.exe simulador.py --puerto COM2
pause
