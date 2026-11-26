@echo off
setlocal
set "GRADLE_VERSION=9.3.1"
set "GRADLE_HOME_DIR=%USERPROFILE%\.gradle\wrapper\dists\tokokita\gradle-%GRADLE_VERSION%"
set "GRADLE_BIN=%GRADLE_HOME_DIR%\gradle-%GRADLE_VERSION%\bin\gradle.bat"
set "ZIP_FILE=%GRADLE_HOME_DIR%\gradle-%GRADLE_VERSION%-bin.zip"
set "GRADLE_URL=https://services.gradle.org/distributions/gradle-%GRADLE_VERSION%-bin.zip"

if not exist "%GRADLE_BIN%" (
  echo Gradle %GRADLE_VERSION% belum tersedia. Mengunduh distribusi Gradle...
  if not exist "%GRADLE_HOME_DIR%" mkdir "%GRADLE_HOME_DIR%"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Invoke-WebRequest -Uri '%GRADLE_URL%' -OutFile '%ZIP_FILE%'; Expand-Archive -LiteralPath '%ZIP_FILE%' -DestinationPath '%GRADLE_HOME_DIR%' -Force"
  if errorlevel 1 exit /b 1
)

call "%GRADLE_BIN%" %*
exit /b %ERRORLEVEL%
