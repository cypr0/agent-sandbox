@echo off
rem Wrapper for sandbox.ps1 (bypasses the execution policy for this call only)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sandbox.ps1" %*
