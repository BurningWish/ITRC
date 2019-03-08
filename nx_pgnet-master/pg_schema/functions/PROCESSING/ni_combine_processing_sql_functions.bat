@echo off
REM - runs to combine all files with .sql extension into a single file for execution i.e. ni_processing_functions.sql
copy /A *.sql ni_processing_functions.sql /B /Y
pause