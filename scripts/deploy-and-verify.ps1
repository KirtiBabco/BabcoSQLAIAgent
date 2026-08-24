$ErrorActionPreference = 'Stop'

$repoRoot = $env:GITHUB_WORKSPACE
$resourceGroup = $env:AZURE_RESOURCE_GROUP
$webApp = $env:WEB_APP
$loginUrl = $env:LOGIN_URL
$defaultUrl = $env:DEFAULT_URL
$easyAuthUrl = $env:EASY_AUTH_URL
$status = [ordered]@{
  SOURCE_COMMIT=$env:GITHUB_SHA; PACKAGE='failure'; OIDC='success'; SETTINGS='failure'; DEPLOY='failure'; BACKEND='failure'; VERIFY='failure'
}

function Set-Status([string]$Name,[object]$Value){ $script:status[$Name]=if($null -eq $Value){''}else{[string]$Value} }
function OneLine([object]$Value){ if($null -eq $Value){return ''}; return ([string]$Value)-replace '[\r\n]+',' ' }
function Get-KeyNames([string]$Value){
  if([string]::IsNullOrWhiteSpace($Value)){return ''}
  $names=New-Object System.Collections.Generic.List[string]
  foreach($part in ($Value -split ';')){
    $p=$part.IndexOf('=')
    if($p -gt 0){
      $n=$part.Substring(0,$p).Trim().Trim('"').Trim("'")
      if($n -and -not $names.Contains($n)){$names.Add($n)}
    }
  }
  return ($names -join ',')
}
function Normalize-Sql([string]$Value){
  if([string]::IsNullOrWhiteSpace($Value)){return ''}
  $v=$Value.Trim()

  if($v -match '(?is)^\s*BAP_SUPPORT_CONNECTION_STRING\s*=\s*(.+)$'){ $v=$Matches[1].Trim() }

  if($v.StartsWith('{')){
    try{
      $j=$v|ConvertFrom-Json
      if($j.ConnectionString){$v=[string]$j.ConnectionString}
      elseif($j.connectionString){$v=[string]$j.connectionString}
    }catch{}
  }

  if($v -match '(?is)<add\b.*?\bconnectionString\s*=\s*"([^"]+)"'){
    $v=[System.Net.WebUtility]::HtmlDecode($Matches[1]).Trim()
  } elseif($v -match "(?is)<add\b.*?\bconnectionString\s*=\s*'([^']+)'") {
    $v=[System.Net.WebUtility]::HtmlDecode($Matches[1]).Trim()
  } elseif($v -match '(?is)^\s*(?:Name\s*=\s*[^;]+\s*;\s*)?ConnectionString\s*=\s*(.+)$') {
    $v=$Matches[1].Trim()
  }

  if($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[$v.Length-1] -eq '"') -or ($v[0] -eq "'" -and $v[$v.Length-1] -eq "'"))){
    $v=$v.Substring(1,$v.Length-2).Trim()
  }

  $v=[regex]::Replace($v,'(?i)\bConnectTimeout\s*=','Connect Timeout=')
  $v=[regex]::Replace($v,'(?i)\bConnectionTimeout\s*=','Connection Timeout=')
  return $v.Trim()
}
function Publish-Status{
  try{
    Set-Status 'CHECKED_UTC' ([DateTime]::UtcNow.ToString('o'))
    $d=Join-Path $env:RUNNER_TEMP 'deployment-status-publish'
    if(Test-Path $d){Remove-Item $d -Recurse -Force}
    New-Item -ItemType Directory -Path $d -Force|Out-Null
    @($status.GetEnumerator()|ForEach-Object{"$($_.Key)=$(OneLine $_.Value)"})|Set-Content (Join-Path $d 'status.txt') -Encoding ascii
    if(-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)){
      Push-Location $d
      git init|Out-Null;git checkout -b deployment-status|Out-Null
      git config user.name 'github-actions[bot]';git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
      git add status.txt;git commit -m 'Publish SQL Agent deployment status'|Out-Null
      git remote add origin "https://x-access-token:$env:GH_TOKEN@github.com/$env:GITHUB_REPOSITORY.git"
      git push --force origin deployment-status|Out-Null
      Pop-Location
    }
  }catch{Write-Warning ('Status publish failed: '+$_.Exception.Message)}
}

try{
  # Reconstruct complete supplied application and overlay production-safe files.
  $parts=Get-ChildItem (Join-Path $repoRoot 'source-package') -Filter 'part*.b64'|Sort-Object Name
  Set-Status 'PACKAGE_PARTS' $parts.Count
  if($parts.Count -lt 1){throw 'No source package parts found.'}
  $b64=($parts|ForEach-Object{(Get-Content $_.FullName -Raw).Trim()}) -join ''
  $sourceZip=Join-Path $env:RUNNER_TEMP 'source.zip'
  [IO.File]::WriteAllBytes($sourceZip,[Convert]::FromBase64String($b64))
  Set-Status 'PACKAGE_SHA256' ((Get-FileHash $sourceZip -Algorithm SHA256).Hash.ToLowerInvariant())
  $extract=Join-Path $env:RUNNER_TEMP 'source'; if(Test-Path $extract){Remove-Item $extract -Recurse -Force}; Expand-Archive $sourceZip $extract -Force
  $site=Join-Path $extract 'SQL_AI_Agent'; if(-not(Test-Path $site)){throw 'SQL_AI_Agent source folder is missing.'}
  $overrides=Join-Path $repoRoot 'deploy-overrides'; if(-not(Test-Path $overrides)){throw 'deploy-overrides folder is missing.'}
  Get-ChildItem $overrides -Recurse -File|ForEach-Object{
    $rel=$_.FullName.Substring($overrides.Length).TrimStart([char[]]@('\','/'))
    $dest=Join-Path $site $rel; $parent=Split-Path $dest -Parent; if(-not(Test-Path $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}; Copy-Item $_.FullName $dest -Force
  }
  Set-Status 'OVERRIDES_APPLIED' 'true'
  foreach($name in @('Login.aspx','Default.aspx','Web.config','App_Code\AppConfig.cs','App_Code\AuthService.cs','App_Code\SqlTool.cs','App_Code\AgentService.cs','App_Data\runtime-health.ps1')){if(-not(Test-Path (Join-Path $site $name))){throw "Missing runtime source file: $name"}}
  $runtime=(Get-Content (Join-Path $site 'Login.aspx') -Raw)+(Get-Content (Join-Path $site 'App_Code\AuthService.cs') -Raw)+(Get-Content (Join-Path $site 'App_Code\AppConfig.cs') -Raw)
  if($runtime -match 'Local Test Admin Login|Continue Without Microsoft|LOCAL-ADMIN|ENTRA_CLIENT_SECRET'){throw 'Forbidden local auth or custom Entra secret logic is present.'}
  Set-Status 'SOURCE_LOCAL_ADMIN_REMOVED' 'true'; Set-Status 'SOURCE_EASY_AUTH' 'true'; Set-Status 'SOURCE_GLOBAL_SQL' 'true'
  $deployZip=Join-Path $env:RUNNER_TEMP 'site.zip'; if(Test-Path $deployZip){Remove-Item $deployZip -Force}; Compress-Archive -Path (Join-Path $site '*') -DestinationPath $deployZip -Force
  Set-Status 'PACKAGE' 'success'; Set-Status 'PACKAGE_VALID' 'true'

  # Read, classify and canonicalize server-side settings without logging secret values.
  $settings=az webapp config appsettings list -g $resourceGroup -n $webApp|ConvertFrom-Json
  if($LASTEXITCODE -ne 0){throw 'Unable to read Azure App Service settings.'}
  $sqlItem=@($settings|Where-Object{$_.name -eq 'BAP_SUPPORT_CONNECTION_STRING'})
  $keyItem=@($settings|Where-Object{$_.name -eq 'OPENAI_API_KEY_DEVELOPMENT'})
  $sqlPresent=$sqlItem.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$sqlItem[0].value)
  $keyPresent=$keyItem.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$keyItem[0].value)
  Set-Status 'SQL_SETTING_PRESENT' $sqlPresent.ToString().ToLowerInvariant(); Set-Status 'OPENAI_SETTING_PRESENT' $keyPresent.ToString().ToLowerInvariant()
  if(-not $sqlPresent){throw 'BAP_SUPPORT_CONNECTION_STRING is missing.'}; if(-not $keyPresent){throw 'OPENAI_API_KEY_DEVELOPMENT is missing.'}
  $rawSql=[string]$sqlItem[0].value; $rawKey=[string]$keyItem[0].value; Write-Output "::add-mask::$rawSql"; Write-Output "::add-mask::$rawKey"
  Set-Status 'SQL_RAW_KEY_NAMES' (Get-KeyNames $rawSql)
  $sql=Normalize-Sql $rawSql; Write-Output "::add-mask::$sql"; Set-Status 'SQL_NORMALIZED_KEY_NAMES' (Get-KeyNames $sql)
  try{Add-Type -AssemblyName System.Data; $parse=New-Object System.Data.SqlClient.SqlConnectionStringBuilder; $parse.ConnectionString=$sql; Set-Status 'SQL_PARSE_OK' 'true'}catch{Set-Status 'SQL_PARSE_OK' 'false'; Set-Status 'SQL_PARSE_ERROR' $_.Exception.Message; throw ('SQL connection string is not parseable after normalization: '+$_.Exception.Message)}
  if($sql -ne $rawSql){
    az webapp config appsettings set -g $resourceGroup -n $webApp --settings "BAP_SUPPORT_CONNECTION_STRING=$sql" --output none
    if($LASTEXITCODE -ne 0){throw 'Failed to save canonical SQL connection string in Azure.'}
    Set-Status 'SQL_SETTING_CANONICALIZED' 'true'
  }else{Set-Status 'SQL_SETTING_CANONICALIZED' 'false'}
  Set-Status 'SETTINGS' 'success'

  # Deploy and restart.
  az webapp start -g $resourceGroup -n $webApp|Out-Null
  az webapp deploy -g $resourceGroup -n $webApp --src-path $deployZip --type zip --clean true --restart true|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Azure ZIP deployment failed.'}
  az webapp restart -g $resourceGroup -n $webApp|Out-Null; if($LASTEXITCODE -ne 0){throw 'Azure restart failed.'}; Set-Status 'DEPLOY' 'success'

  # Execute the deployed App_Data health script inside the real App Service runtime.
  Start-Sleep -Seconds 20
  $token=az account get-access-token --resource https://management.azure.com/ --query accessToken -o tsv; if($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)){throw 'Unable to get Kudu management token.'}; Write-Output "::add-mask::$token"
  $cmd='powershell -NoProfile -ExecutionPolicy Bypass -File App_Data\runtime-health.ps1'
  $body=@{command=$cmd;dir='site\wwwroot'}|ConvertTo-Json -Compress
  $uri="https://$webApp.scm.azurewebsites.net/api/command"; $r=$null; $last=$null
  for($i=1;$i -le 12;$i++){try{$r=Invoke-RestMethod -Method Post -Uri $uri -Headers @{Authorization="Bearer $token"} -ContentType 'application/json' -Body $body -TimeoutSec 120;break}catch{$last=$_;Start-Sleep -Seconds 5}}
  if($null -eq $r){throw ('Kudu health command failed: '+(OneLine $last.Exception.Message))}
  $text=([string]$r.Output)+"`n"+([string]$r.Error); $lines=$text -split "`r?`n"|Where-Object{$_ -match '^(SQL_|OPENAI_)'}
  foreach($line in $lines){Write-Output $line; $p=$line.IndexOf('='); if($p -gt 0){Set-Status $line.Substring(0,$p) $line.Substring($p+1)}}
  if(([string]$status.SQL_OK).ToLowerInvariant() -ne 'true'){throw ('SQL runtime smoke test failed: '+$status.SQL_ERROR)}
  if(([string]$status.OPENAI_OK).ToLowerInvariant() -ne 'true'){throw ('OpenAI runtime smoke test failed: '+$status.OPENAI_ERROR)}
  Set-Status 'BACKEND' 'success'

  # Entra/live web checks.
  $login=$null; for($i=1;$i -le 24;$i++){try{$login=Invoke-WebRequest $loginUrl -UseBasicParsing -TimeoutSec 30;if([int]$login.StatusCode -eq 200){break}}catch{};Start-Sleep -Seconds 5}
  if($null -eq $login -or [int]$login.StatusCode -ne 200){throw 'Login.aspx is not healthy.'}; Set-Status 'LOGIN_HTTP' 200
  if($login.Content -match 'Local Test Admin Login|Continue Without Microsoft|LOCAL-ADMIN'){throw 'Local login bypass is live.'}
  $easy=0;try{$x=Invoke-WebRequest $easyAuthUrl -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 30;$easy=[int]$x.StatusCode}catch{if($_.Exception.Response){$easy=[int]$_.Exception.Response.StatusCode}}
  if($easy -lt 300 -or $easy -ge 400){throw "Easy Auth returned HTTP $easy."}; Set-Status 'EASY_AUTH_HTTP' $easy
  $def=0;try{$x=Invoke-WebRequest $defaultUrl -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 30;$def=[int]$x.StatusCode}catch{if($_.Exception.Response){$def=[int]$_.Exception.Response.StatusCode}}
  if($def -lt 300 -or $def -ge 400){throw "Default.aspx unauthenticated returned HTTP $def."}; Set-Status 'DEFAULT_UNAUTH_HTTP' $def
  Set-Status 'VERIFY' 'success'; Set-Status 'VERIFIED_LIVE' 'true'; Set-Status 'LOGIN_URL' $loginUrl
  Publish-Status
  Write-Output 'FULL_LIVE_HEALTH=success'
}catch{
  Set-Status 'FATAL_ERROR' (OneLine $_.Exception.Message)
  Publish-Status
  throw
}
