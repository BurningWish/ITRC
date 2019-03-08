@echo off 
REM - pre-defined .bat script to execute ni_setup_trigger_functions.bat
REM - edit the four parameter values here to suit custom settings.
call ni_setup_trigger_functions.bat "localhost" "postgres" "C:\Program Files (x86)\PostgreSQL\9.0\bin\" "empty"
pause
