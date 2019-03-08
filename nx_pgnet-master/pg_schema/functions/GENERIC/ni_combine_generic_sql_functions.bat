@echo off
REM - runs to combine all files with .sql extension into a single file for execution i.e. ni_generic_functions.sql
copy /A *.sql ni_generic_functions.sql /B /Y
pause