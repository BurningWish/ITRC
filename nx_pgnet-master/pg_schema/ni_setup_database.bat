@echo off
REM - script to install the database schema

REM - %1 - host
REM - %2 - user
REM - %3 - bin folder location
REM - %4 - database to change

REM - execute example - ni_setup_database.bat "localhost" "postgres" "C:\Program Files (x86)\PostgreSQL\9.0\bin\" "empty"

REM - count arguments
set argcount=0
for %%x in (%*) do Set /A argcount+=1

REM - check argument count
IF NOT %argcount% == 4 (
	echo "Input argument missing. Parameter 1 = host, Parameter 2 = user, Parameter 3 = postgres bin folder, Parameter 4 = database name. e.g. ni_setup_database.bat 'localhost' 'postgres' 'C:\Program Files (x86)\PostgreSQL\9.0\bin\' 'empty'
	GOTO :eof
)

REM - install the processing functions (1)
CD %~dp0functions\processing\
call %~dp0functions\processing\ni_setup_processing_functions.bat %1 %2 %3 %4 %~dp0
CD..
CD..

REM - install the trigger functions (1)
CD %~dp0functions\trigger\
call %~dp0functions\trigger\ni_setup_trigger_functions.bat %1 %2 %3 %4 %~dp0
CD..
CD..

REM - install the tables (1)
CD %~dp0tables\
call %~dp0tables\ni_setup_tables.bat %1 %2 %3 %4 %~dp0
CD..
CD..

REM - install the generic functions (1)
CD %~dp0functions\generic\
call %~dp0functions\generic\ni_setup_generic_functions.bat %1 %2 %3 %4 %~dp0
CD..
CD..

REM - return to executing directory
CD %~dp0

pause

