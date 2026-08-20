@echo off
setlocal
if "%DEPLOYMENT_TARGET%"=="" set DEPLOYMENT_TARGET=%HOME%\site\wwwroot
echo Deploying temporary SQL AI Agent login patch to %DEPLOYMENT_TARGET%
copy /Y "%DEPLOYMENT_SOURCE%\Login.aspx" "%DEPLOYMENT_TARGET%\Login.aspx"
if errorlevel 1 exit /b 1
copy /Y "%DEPLOYMENT_SOURCE%\Login.aspx.cs" "%DEPLOYMENT_TARGET%\Login.aspx.cs"
if errorlevel 1 exit /b 1
echo Temporary login patch deployed.
exit /b 0
