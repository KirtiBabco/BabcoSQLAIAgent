@echo off
setlocal
if "%DEPLOYMENT_TARGET%"=="" set DEPLOYMENT_TARGET=%HOME%\site\wwwroot

echo Deploying Babco SQL AI Agent Easy Auth update to %DEPLOYMENT_TARGET%

if not exist "%DEPLOYMENT_TARGET%\App_Code" mkdir "%DEPLOYMENT_TARGET%\App_Code"

copy /Y "%DEPLOYMENT_SOURCE%\Login.aspx" "%DEPLOYMENT_TARGET%\Login.aspx"
if errorlevel 1 exit /b 1
copy /Y "%DEPLOYMENT_SOURCE%\Login.aspx.cs" "%DEPLOYMENT_TARGET%\Login.aspx.cs"
if errorlevel 1 exit /b 1
copy /Y "%DEPLOYMENT_SOURCE%\AuthComplete.aspx" "%DEPLOYMENT_TARGET%\AuthComplete.aspx"
if errorlevel 1 exit /b 1
copy /Y "%DEPLOYMENT_SOURCE%\AuthComplete.aspx.cs" "%DEPLOYMENT_TARGET%\AuthComplete.aspx.cs"
if errorlevel 1 exit /b 1
copy /Y "%DEPLOYMENT_SOURCE%\Default.aspx" "%DEPLOYMENT_TARGET%\Default.aspx"
if errorlevel 1 exit /b 1
copy /Y "%DEPLOYMENT_SOURCE%\Default.aspx.cs" "%DEPLOYMENT_TARGET%\Default.aspx.cs"
if errorlevel 1 exit /b 1
copy /Y "%DEPLOYMENT_SOURCE%\App_Code\AuthService.cs" "%DEPLOYMENT_TARGET%\App_Code\AuthService.cs"
if errorlevel 1 exit /b 1
copy /Y "%DEPLOYMENT_SOURCE%\App_Code\AppConfig.cs" "%DEPLOYMENT_TARGET%\App_Code\AppConfig.cs"
if errorlevel 1 exit /b 1

echo Easy Auth update deployed successfully.
exit /b 0
