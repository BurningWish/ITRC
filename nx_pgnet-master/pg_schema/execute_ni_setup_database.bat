@echo off 

REM - count arguments
set argcount=0
for %%x in (%*) do Set /A argcount+=1

REM - check argument count for missing arguments
IF %argcount% == 1 (
	REM - execute setup database script
	call ni_setup_database.bat "localhost" "postgres" "C:\Program Files (x86)\PostgreSQL\9.0\bin\" %1
) else (
	echo "Input argument missing. Parameter 1 = database name. e.g. execute_ni_setup_database.bat 'database_name'
	GOTO :eof
)

pause
