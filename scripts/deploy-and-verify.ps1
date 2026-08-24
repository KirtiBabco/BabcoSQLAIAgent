$ErrorActionPreference = 'Stop'

$repoRoot = $env:GITHUB_WORKSPACE
$resourceGroup = $env:AZURE_RESOURCE_GROUP
$webApp = $env:WEB_APP
$loginUrl = $env:LOGIN_URL
$defaultUrl = $env:DEFAULT_URL
$easyAuthUrl = $env:EASY_AUTH_URL
$status = [ordered]@{}
$status.SOURCE_COMMIT = $env:GITHUB_SHA
$status.PACKAGE = 'failure'
$status.OIDC = 'success'
$status.SETTINGS = 'failure'
$status.DEPLOY = 'failure'
$status.BACKEND = 'failure'
$status.VERIFY = 'failure'

function Set-Status([string]$Name, [object]$Value) {
    $script:status[$Name] = if ($null -eq $Value) { '' } else { [string]$Value }
}

function Safe-OneLine([object]$Value) {
    if ($null -eq $Value) { return '' }
    return ([string]$Value) -replace '[\r\n]+', ' '
}

function Normalize-SqlConnectionString([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $v = $Value.Trim()

    # Sometimes a shared/global setting is copied as ConnectionString=<actual string>.
    # System.Data.SqlClient treats ConnectionString as an invalid connection keyword,
    # so remove only that outer wrapper. Do not log the value.
    if ($v -match '(?is)^\s*ConnectionString\s*=\s*(.+)$') {
        $v = $Matches[1].Trim()
    }
    if ($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[$v.Length - 1] -eq '"') -or ($v[0] -eq "'" -and $v[$v.Length - 1] -eq "'"))) {
        $v = $v.Substring(1, $v.Length - 2).Trim()
    }

    $v = [regex]::Replace($v, '(?i)\bConnectTimeout\s*=', 'Connect Timeout=')
    $v = [regex]::Replace($v, '(?i)\bConnectionTimeout\s*=', 'Connection Timeout=')
    return $v.Trim()
}

function Publish-Status {
    try {
        Set-Status 'CHECKED_UTC' ([DateTime]::UtcNow.ToString('o'))
        $dir = Join-Path $env:RUNNER_TEMP 'deployment-status-publish'
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $lines = foreach ($entry in $status.GetEnumerator()) {
            '{0}={1}' -f $entry.Key, (Safe-OneLine $entry.Value)
        }
        $lines | Set-Content (Join-Path $dir 'status.txt') -Encoding ascii

        if (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) {
            Push-Location $dir
            git init | Out-Null
            git checkout -b deployment-status | Out-Null
            git config user.name 'github-actions[bot]'
            git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
            git add status.txt
            git commit -m 'Publish SQL Agent deployment status' | Out-Null
            git remote add origin "https://x-access-token:$env:GH_TOKEN@github.com/$env:GITHUB_REPOSITORY.git"
            git push --force origin deployment-status | Out-Null
            Pop-Location
        }
    } catch {
        Write-Warning ('Could not publish deployment status: ' + $_.Exception.Message)
    }
}

try {
    # 1) Reconstruct the complete supplied application package.
    $parts = Get-ChildItem (Join-Path $repoRoot 'source-package') -Filter 'part*.b64' | Sort-Object Name
    Set-Status 'PACKAGE_PARTS' $parts.Count
    if ($parts.Count -lt 1) { throw 'No source package parts found.' }

    $b64 = ($parts | ForEach-Object { (Get-Content $_.FullName -Raw).Trim() }) -join ''
    $sourceZip = Join-Path $env:RUNNER_TEMP 'source.zip'
    [IO.File]::WriteAllBytes($sourceZip, [Convert]::FromBase64String($b64))
    Set-Status 'PACKAGE_SHA256' ((Get-FileHash $sourceZip -Algorithm SHA256).Hash.ToLowerInvariant())

    $extract = Join-Path $env:RUNNER_TEMP 'source'
    if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
    Expand-Archive $sourceZip $extract -Force
    $site = Join-Path $extract 'SQL_AI_Agent'
    if (-not (Test-Path $site)) { throw 'SQL_AI_Agent source folder is missing.' }

    # 2) Production-only overrides preserve the supplied UI/modules while replacing auth/config.
    $overrides = Join-Path $repoRoot 'deploy-overrides'
    if (-not (Test-Path $overrides)) { throw 'deploy-overrides folder is missing.' }
    Get-ChildItem $overrides -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($overrides.Length).TrimStart([char[]]@('\','/'))
        $destination = Join-Path $site $relative
        $parent = Split-Path $destination -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item $_.FullName $destination -Force
    }
    Set-Status 'OVERRIDES_APPLIED' 'true'

    foreach ($name in @('Login.aspx','Login.aspx.cs','Default.aspx','Default.aspx.cs','Web.config','AuthComplete.aspx.cs','Logout.aspx.cs','App_Code\AppConfig.cs','App_Code\AuthService.cs','App_Code\SqlTool.cs','App_Code\AgentService.cs','App_Code\TelemetryStore.cs')) {
        if (-not (Test-Path (Join-Path $site $name))) { throw "Missing runtime source file: $name" }
    }

    $loginSource = Get-Content (Join-Path $site 'Login.aspx') -Raw
    $loginCode = Get-Content (Join-Path $site 'Login.aspx.cs') -Raw
    $authSource = Get-Content (Join-Path $site 'App_Code\AuthService.cs') -Raw
    $cfgSource = Get-Content (Join-Path $site 'App_Code\AppConfig.cs') -Raw
    $webSource = Get-Content (Join-Path $site 'Web.config') -Raw
    $runtimeSource = $loginSource + $loginCode + $authSource + $cfgSource + $webSource

    if ($runtimeSource -match 'Local Test Admin Login|Continue Without Microsoft|btnLocalTest|LOCAL-ADMIN|LocalTestAdminLogin|CanUseLocalTestLogin') { throw 'Local/temporary login bypass is still present.' }
    if ($runtimeSource -match 'ENTRA_CLIENT_SECRET|EntraClientSecret') { throw 'Custom Entra client-secret logic is still present.' }
    if ($authSource -notmatch '/\.auth/login/aad') { throw 'Azure Easy Auth endpoint is missing from AuthService.' }
    if ($loginSource -notmatch 'Sign in with Microsoft Entra ID') { throw 'Microsoft Entra login button is missing.' }
    if ($cfgSource -notmatch 'BAP_SUPPORT_CONNECTION_STRING') { throw 'Global Babco SQL setting is missing from AppConfig.' }
    if ($cfgSource -match 'Password\s*=|User Id\s*=|Server=tcp:') { throw 'A SQL connection value appears embedded in source.' }
    Set-Status 'SOURCE_LOCAL_ADMIN_REMOVED' 'true'
    Set-Status 'SOURCE_EASY_AUTH' 'true'
    Set-Status 'SOURCE_GLOBAL_SQL' 'true'

    $deployZip = Join-Path $env:RUNNER_TEMP 'site.zip'
    if (Test-Path $deployZip) { Remove-Item $deployZip -Force }
    Compress-Archive -Path (Join-Path $site '*') -DestinationPath $deployZip -Force
    Set-Status 'PACKAGE' 'success'
    Set-Status 'PACKAGE_VALID' 'true'

    # 3) Check server-side settings without printing their values.
    $settings = az webapp config appsettings list -g $resourceGroup -n $webApp | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read Azure App Service settings.' }
    $sqlItem = @($settings | Where-Object { $_.name -eq 'BAP_SUPPORT_CONNECTION_STRING' })
    $openAiItem = @($settings | Where-Object { $_.name -eq 'OPENAI_API_KEY_DEVELOPMENT' })
    $sqlPresent = $sqlItem.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$sqlItem[0].value)
    $openAiPresent = $openAiItem.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$openAiItem[0].value)
    Set-Status 'SQL_SETTING_PRESENT' $sqlPresent.ToString().ToLowerInvariant()
    Set-Status 'OPENAI_SETTING_PRESENT' $openAiPresent.ToString().ToLowerInvariant()
    if (-not $sqlPresent) { throw 'BAP_SUPPORT_CONNECTION_STRING is missing on Azure App Service.' }
    if (-not $openAiPresent) { throw 'OPENAI_API_KEY_DEVELOPMENT is missing on Azure App Service.' }

    $rawSql = [string]$sqlItem[0].value
    $rawKey = [string]$openAiItem[0].value
    Write-Output "::add-mask::$rawSql"
    Write-Output "::add-mask::$rawKey"
    $normalizedSql = Normalize-SqlConnectionString $rawSql
    Write-Output "::add-mask::$normalizedSql"
    Set-Status 'SQL_OUTER_WRAPPER_NORMALIZED' (($normalizedSql -ne $rawSql).ToString().ToLowerInvariant())
    Set-Status 'SETTINGS' 'success'

    # 4) Deploy the updated complete site.
    az webapp start -g $resourceGroup -n $webApp | Out-Null
    az webapp deploy -g $resourceGroup -n $webApp --src-path $deployZip --type zip --clean true --restart true | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Azure ZIP deployment failed.' }
    az webapp restart -g $resourceGroup -n $webApp | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Azure App Service restart failed.' }
    Set-Status 'DEPLOY' 'success'

    # 5) Test SQL and OpenAI inside the actual App Service process environment.
    Start-Sleep -Seconds 20
    $managementToken = az account get-access-token --resource https://management.azure.com/ --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($managementToken)) { throw 'Unable to acquire Azure management token for Kudu diagnostics.' }
    Write-Output "::add-mask::$managementToken"

    $backendScript = @'
$ErrorActionPreference='Continue'
function OutSafe([string]$k,[object]$v){Write-Output ($k+'='+[string]$v)}
function NormalizeSql([string]$v){
  if([string]::IsNullOrWhiteSpace($v)){return ''}
  $v=$v.Trim()
  if($v -match '(?is)^\s*ConnectionString\s*=\s*(.+)$'){$v=$Matches[1].Trim()}
  if($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[$v.Length-1] -eq '"') -or ($v[0] -eq "'" -and $v[$v.Length-1] -eq "'"))){$v=$v.Substring(1,$v.Length-2).Trim()}
  $v=[regex]::Replace($v,'(?i)\bConnectTimeout\s*=','Connect Timeout=')
  $v=[regex]::Replace($v,'(?i)\bConnectionTimeout\s*=','Connection Timeout=')
  return $v.Trim()
}
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

$cs=[Environment]::GetEnvironmentVariable('BAP_SUPPORT_CONNECTION_STRING')
OutSafe 'SQL_SETTING_RUNTIME_PRESENT' (-not [string]::IsNullOrWhiteSpace($cs))
try{
  Add-Type -AssemblyName System.Data
  $cs=NormalizeSql $cs
  $builder=New-Object System.Data.SqlClient.SqlConnectionStringBuilder
  $builder.ConnectionString=$cs
  $builder.ConnectTimeout=10
  $sw=[Diagnostics.Stopwatch]::StartNew()
  $connection=New-Object System.Data.SqlClient.SqlConnection($builder.ConnectionString)
  $connection.Open()
  $command=$connection.CreateCommand();$command.CommandTimeout=10;$command.CommandText='SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES'
  $tables=$command.ExecuteScalar();$connection.Close();$sw.Stop()
  OutSafe 'SQL_OK' 'true';OutSafe 'SQL_TABLE_COUNT' $tables;OutSafe 'SQL_MS' $sw.ElapsedMilliseconds
}catch{
  OutSafe 'SQL_OK' 'false';OutSafe 'SQL_ERROR_TYPE' $_.Exception.GetType().Name;OutSafe 'SQL_ERROR' ($_.Exception.Message -replace '[\r\n]+',' ')
}

$key=[Environment]::GetEnvironmentVariable('OPENAI_API_KEY_DEVELOPMENT')
if([string]::IsNullOrWhiteSpace($key)){$key=[Environment]::GetEnvironmentVariable('OPENAI_API_KEY')}
OutSafe 'OPENAI_KEY_RUNTIME_PRESENT' (-not [string]::IsNullOrWhiteSpace($key))
$model=[Environment]::GetEnvironmentVariable('OPENAI_MODEL');if([string]::IsNullOrWhiteSpace($model)){$model='gpt-5-mini'}
OutSafe 'OPENAI_MODEL_TESTED' $model
if(-not [string]::IsNullOrWhiteSpace($key)){
  try{
    $payload=@{model=$model;input='Reply only OK'}|ConvertTo-Json -Compress
    $sw=[Diagnostics.Stopwatch]::StartNew()
    $response=Invoke-WebRequest -Method Post -Uri 'https://api.openai.com/v1/responses' -Headers @{Authorization=('Bearer '+$key)} -ContentType 'application/json' -Body $payload -UseBasicParsing -TimeoutSec 30
    $sw.Stop();OutSafe 'OPENAI_OK' ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 300);OutSafe 'OPENAI_HTTP' ([int]$response.StatusCode);OutSafe 'OPENAI_MS' $sw.ElapsedMilliseconds
  }catch{
    $http='';$responseBody=''
    try{$http=[int]$_.Exception.Response.StatusCode}catch{}
    try{$stream=$_.Exception.Response.GetResponseStream();if($stream){$reader=New-Object IO.StreamReader($stream);$responseBody=$reader.ReadToEnd();$reader.Dispose()}}catch{}
    $code='';$message='';try{$json=$responseBody|ConvertFrom-Json;$code=[string]$json.error.code;$message=[string]$json.error.message}catch{}
    if($message.Length -gt 500){$message=$message.Substring(0,500)}
    OutSafe 'OPENAI_OK' 'false';OutSafe 'OPENAI_HTTP' $http;OutSafe 'OPENAI_ERROR_CODE' $code;OutSafe 'OPENAI_ERROR_MESSAGE' ($message -replace '[\r\n]+',' ')
  }
}else{OutSafe 'OPENAI_OK' 'false';OutSafe 'OPENAI_ERROR_MESSAGE' 'No server-side OpenAI API key configured.'}
'@

    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($backendScript))
    $kuduBody = @{ command = "powershell -NoProfile -EncodedCommand $encoded"; dir = 'site\wwwroot' } | ConvertTo-Json -Compress
    $kuduUri = "https://$webApp.scm.azurewebsites.net/api/command"
    $kuduResult = $null
    $lastKuduError = $null
    for ($attempt = 1; $attempt -le 12; $attempt++) {
        try {
            $kuduResult = Invoke-RestMethod -Method Post -Uri $kuduUri -Headers @{ Authorization = "Bearer $managementToken" } -ContentType 'application/json' -Body $kuduBody -TimeoutSec 120
            break
        } catch {
            $lastKuduError = $_
            Start-Sleep -Seconds 5
        }
    }
    if ($null -eq $kuduResult) { throw ('Kudu diagnostics failed after retries: ' + (Safe-OneLine $lastKuduError.Exception.Message)) }

    $backendText = ([string]$kuduResult.Output) + "`n" + ([string]$kuduResult.Error)
    $safeLines = $backendText -split "`r?`n" | Where-Object { $_ -match '^(SQL_|OPENAI_)' }
    foreach ($line in $safeLines) {
        Write-Output $line
        $pos = $line.IndexOf('=')
        if ($pos -gt 0) { Set-Status $line.Substring(0,$pos) $line.Substring($pos+1) }
    }
    if ($status.SQL_OK -ne 'true') { throw ('SQL runtime smoke test failed: ' + $status.SQL_ERROR) }
    if ($status.OPENAI_OK -ne 'True' -and $status.OPENAI_OK -ne 'true') { throw ('OpenAI runtime smoke test failed: HTTP ' + $status.OPENAI_HTTP + ' ' + $status.OPENAI_ERROR_MESSAGE) }
    Set-Status 'BACKEND' 'success'

    # 6) Verify Entra-only browser entry points.
    $loginResponse = $null
    for ($i = 1; $i -le 24; $i++) {
        try {
            $loginResponse = Invoke-WebRequest $loginUrl -UseBasicParsing -TimeoutSec 30
            if ([int]$loginResponse.StatusCode -eq 200 -and $loginResponse.Content -match 'Sign in with Microsoft Entra ID') { break }
        } catch {}
        Start-Sleep -Seconds 5
    }
    if ($null -eq $loginResponse -or [int]$loginResponse.StatusCode -ne 200) { throw 'Login.aspx is not healthy.' }
    if ($loginResponse.Content -match 'Local Test Admin Login|Continue Without Microsoft|LOCAL-ADMIN') { throw 'Local/temporary login bypass is live.' }
    Set-Status 'LOGIN_HTTP' '200'
    Set-Status 'LOCAL_ADMIN_REMOVED' 'true'

    $easyStatus = 0
    try { $r = Invoke-WebRequest $easyAuthUrl -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 30; $easyStatus = [int]$r.StatusCode }
    catch { if ($_.Exception.Response) { $easyStatus = [int]$_.Exception.Response.StatusCode } }
    if ($easyStatus -lt 300 -or $easyStatus -ge 400) { throw "Easy Auth returned HTTP $easyStatus instead of a Microsoft redirect." }
    Set-Status 'EASY_AUTH_HTTP' $easyStatus

    $defaultStatus = 0
    try { $d = Invoke-WebRequest $defaultUrl -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 30; $defaultStatus = [int]$d.StatusCode }
    catch { if ($_.Exception.Response) { $defaultStatus = [int]$_.Exception.Response.StatusCode } }
    if ($defaultStatus -lt 300 -or $defaultStatus -ge 400) { throw "Unauthenticated Default.aspx returned HTTP $defaultStatus instead of redirect." }
    Set-Status 'DEFAULT_UNAUTH_HTTP' $defaultStatus
    Set-Status 'VERIFY' 'success'
    Set-Status 'VERIFIED_LIVE' 'true'
    Set-Status 'LOGIN_URL' $loginUrl

    Publish-Status

    if ($status.PACKAGE -ne 'success' -or $status.SETTINGS -ne 'success' -or $status.DEPLOY -ne 'success' -or $status.BACKEND -ne 'success' -or $status.VERIFY -ne 'success') {
        throw 'Full live health gate did not pass.'
    }
    Write-Output 'FULL_LIVE_HEALTH=success'
}
catch {
    Set-Status 'FATAL_ERROR' (Safe-OneLine $_.Exception.Message)
    Publish-Status
    throw
}
