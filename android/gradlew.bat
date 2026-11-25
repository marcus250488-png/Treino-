@echo off
where gradle >nul 2>nul
if errorlevel 1 (
  echo Gradle 8.11.1 nao encontrado. Instale o Gradle e tente novamente.
  exit /b 1
)
gradle %*
