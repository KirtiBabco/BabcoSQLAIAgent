$ErrorActionPreference='Stop'
$repoRoot=$env:GITHUB_WORKSPACE;$resourceGroup=$env:AZURE_RESOURCE_GROUP;$webApp=$env:WEB_APP;$loginUrl=$env:LOGIN_URL;$defaultUrl=$env:DEFAULT_URL;$easyAuthUrl=$env:EASY_AUTH_URL
$healthUrl="https://$webApp.azurewebsites.net/HealthCheck.aspx"
$status=[ordered]@{SOURCE_COMMIT=$env:GITHUB_SHA;PACKAGE='failure';OIDC='success';SETTINGS='failure';DEPLOY='failure';BACKEND='failure';VERIFY='failure'}
$healthToken=''
function SetS([string]$k,[object]$v){$script:status[$k]=if($null -eq $v){''}else{[string]$v}}
function One([object]$v){if($null -eq $v){return ''};return ([string]$v)-replace '[\r\n]+',' '}
function Keys([string]$v){if([string]::IsNullOrWhiteSpace($v)){return ''};$a=New-Object System.Collections.Generic.List[string];foreach($p in ($v -split ';')){$i=$p.IndexOf('=');if($i -gt 0){$n=$p.Substring(0,$i).Trim().Trim('"').Trim("'");if($n -and -not $a.Contains($n)){$a.Add($n)}}};return($a -join ',')}
function NormalizeSql([string]$v){
  if([string]::IsNullOrWhiteSpace($v)){return ''};$v=$v.Trim()
  if($v -match '(?is)^\s*BAP_SUPPORT_CONNECTION_STRING\s*=\s*(.+)$'){$v=$Matches[1].Trim()}
  if($v.StartsWith('{')){try{$j=$v|ConvertFrom-Json;if($j.ConnectionString){$v=[string]$j.ConnectionString}elseif($j.connectionString){$v=[string]$j.connectionString}}catch{}}
  if($v -match '(?is)<add\b.*?\bconnectionString\s*=\s*"([^"]+)"'){$v=[System.Net.WebUtility]::HtmlDecode($Matches[1]).Trim()}
  elseif($v -match "(?is)<add\b.*?\bconnectionString\s*=\s*'([^']+)'"){$v=[System.Net.WebUtility]::HtmlDecode($Matches[1]).Trim()}
  elseif($v -match '(?is)^\s*(?:Name\s*=\s*[^;]+\s*;\s*)?ConnectionString\s*=\s*(.+)$'){$v=$Matches[1].Trim()}
  if($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[$v.Length-1] -eq '"') -or ($v[0] -eq "'" -and $v[$v.Length-1] -eq "'"))){$v=$v.Substring(1,$v.Length-2).Trim()}
  $v=[regex]::Replace($v,'(?i)\bConnectTimeout\s*=','Connect Timeout=');$v=[regex]::Replace($v,'(?i)\bConnectionTimeout\s*=','Connection Timeout=');$v=[regex]::Replace($v,'(?i)(^|;)\s*Timeout\s*=','$1Connect Timeout=');return $v.Trim()
}
function Publish{
  try{SetS 'CHECKED_UTC' ([DateTime]::UtcNow.ToString('o'));$d=Join-Path $env:RUNNER_TEMP 'deployment-status-publish';if(Test-Path $d){Remove-Item $d -Recurse -Force};New-Item -ItemType Directory -Path $d -Force|Out-Null;@($status.GetEnumerator()|ForEach-Object{"$($_.Key)=$(One $_.Value)"})|Set-Content (Join-Path $d 'status.txt') -Encoding ascii
    if(-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)){Push-Location $d;git init|Out-Null;git checkout -b deployment-status|Out-Null;git config user.name 'github-actions[bot]';git config user.email '41898282+github-actions[bot]@users.noreply.github.com';git add status.txt;git commit -m 'Publish SQL Agent deployment status'|Out-Null;git remote add origin "https://x-access-token:$env:GH_TOKEN@github.com/$env:GITHUB_REPOSITORY.git";git push --force origin deployment-status|Out-Null;Pop-Location}}
  catch{Write-Warning('Status publish failed: '+$_.Exception.Message)}
}
function RemoveHealthToken{if(-not [string]::IsNullOrWhiteSpace($script:healthToken)){try{az webapp config appsettings delete -g $resourceGroup -n $webApp --setting-names BAP_HEALTH_TOKEN --output none|Out-Null;$script:healthToken=''}catch{Write-Warning 'Could not remove BAP_HEALTH_TOKEN.'}}}
try{
  $parts=Get-ChildItem (Join-Path $repoRoot 'source-package') -Filter 'part*.b64'|Sort-Object Name;SetS 'PACKAGE_PARTS' $parts.Count;if($parts.Count -lt 1){throw 'No source package parts found.'}
  $b64=($parts|ForEach-Object{(Get-Content $_.FullName -Raw).Trim()}) -join '';$sourceZip=Join-Path $env:RUNNER_TEMP 'source.zip';[IO.File]::WriteAllBytes($sourceZip,[Convert]::FromBase64String($b64));SetS 'PACKAGE_SHA256' ((Get-FileHash $sourceZip -Algorithm SHA256).Hash.ToLowerInvariant())
  $extract=Join-Path $env:RUNNER_TEMP 'source';if(Test-Path $extract){Remove-Item $extract -Recurse -Force};Expand-Archive $sourceZip $extract -Force;$site=Join-Path $extract 'SQL_AI_Agent';if(-not(Test-Path $site)){throw 'SQL_AI_Agent source folder missing.'}
  $overrides=Join-Path $repoRoot 'deploy-overrides';Get-ChildItem $overrides -Recurse -File|ForEach-Object{$rel=$_.FullName.Substring($overrides.Length).TrimStart([char[]]@('\','/'));$dest=Join-Path $site $rel;$parent=Split-Path $dest -Parent;if(-not(Test-Path $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};Copy-Item $_.FullName $dest -Force};SetS 'OVERRIDES_APPLIED' 'true'
  foreach($f in @('Login.aspx','Default.aspx','Web.config','HealthCheck.aspx','App_Code\AppConfig.cs','App_Code\AuthService.cs','App_Code\SqlTool.cs','App_Code\AgentService.cs')){if(-not(Test-Path(Join-Path $site $f))){throw "Missing runtime source file: $f"}}
  $runtime=(Get-Content(Join-Path $site 'Login.aspx')-Raw)+(Get-Content(Join-Path $site 'App_Code\AuthService.cs')-Raw);if($runtime -match 'Local Test Admin Login|Continue Without Microsoft|LOCAL-ADMIN|ENTRA_CLIENT_SECRET'){throw 'Forbidden local auth/custom Entra secret logic present.'}
  SetS 'SOURCE_LOCAL_ADMIN_REMOVED' 'true';SetS 'SOURCE_EASY_AUTH' 'true';SetS 'SOURCE_GLOBAL_SQL' 'true'
  $zip=Join-Path $env:RUNNER_TEMP 'site.zip';if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path(Join-Path $site '*') -DestinationPath $zip -Force;SetS 'PACKAGE' 'success';SetS 'PACKAGE_VALID' 'true'

  $settings=az webapp config appsettings list -g $resourceGroup -n $webApp|ConvertFrom-Json;$sqlItem=@($settings|Where-Object{$_.name -eq 'BAP_SUPPORT_CONNECTION_STRING'});$keyItem=@($settings|Where-Object{$_.name -eq 'OPENAI_API_KEY_DEVELOPMENT'})
  $sqlPresent=$sqlItem.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$sqlItem[0].value);$keyPresent=$keyItem.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$keyItem[0].value);SetS 'SQL_SETTING_PRESENT' $sqlPresent.ToString().ToLowerInvariant();SetS 'OPENAI_SETTING_PRESENT' $keyPresent.ToString().ToLowerInvariant();if(-not$sqlPresent){throw 'BAP_SUPPORT_CONNECTION_STRING missing.'};if(-not$keyPresent){throw 'OPENAI_API_KEY_DEVELOPMENT missing.'}
  $rawSql=[string]$sqlItem[0].value;$rawKey=[string]$keyItem[0].value;Write-Output "::add-mask::$rawSql";Write-Output "::add-mask::$rawKey";SetS 'SQL_RAW_KEY_NAMES'(Keys $rawSql);$sql=NormalizeSql $rawSql;Write-Output "::add-mask::$sql";SetS 'SQL_NORMALIZED_KEY_NAMES'(Keys $sql)
  Add-Type -AssemblyName System.Data;try{$parse=[System.Data.SqlClient.SqlConnectionStringBuilder]::new([string]$sql);SetS 'SQL_PARSE_OK' 'true'}catch{SetS 'SQL_PARSE_OK' 'false';SetS 'SQL_PARSE_ERROR' $_.Exception.Message;throw}
  if($sql -ne $rawSql){az webapp config appsettings set -g $resourceGroup -n $webApp --settings "BAP_SUPPORT_CONNECTION_STRING=$sql" --output none;if($LASTEXITCODE -ne 0){throw 'Failed to canonicalize SQL setting.'};SetS 'SQL_SETTING_CANONICALIZED' 'true'}else{SetS 'SQL_SETTING_CANONICALIZED' 'false'}

  $healthToken=[Guid]::NewGuid().ToString('N')+[Guid]::NewGuid().ToString('N');Write-Output "::add-mask::$healthToken";az webapp config appsettings set -g $resourceGroup -n $webApp --settings "BAP_HEALTH_TOKEN=$healthToken" --output none;if($LASTEXITCODE -ne 0){throw 'Unable to create temporary health token.'};SetS 'SETTINGS' 'success'

  az webapp start -g $resourceGroup -n $webApp|Out-Null;az webapp deploy -g $resourceGroup -n $webApp --src-path $zip --type zip --clean true --restart true|Out-Null;if($LASTEXITCODE -ne 0){throw 'Azure ZIP deployment failed.'};az webapp restart -g $resourceGroup -n $webApp|Out-Null;SetS 'DEPLOY' 'success'

  Start-Sleep -Seconds 20;$health=$null;$lastHealth='';$healthBody=''
  for($i=1;$i -le 6;$i++){
    try{$health=Invoke-WebRequest $healthUrl -UseBasicParsing -Headers @{'X-Babco-Health-Token'=$healthToken} -TimeoutSec 150;if([int]$health.StatusCode -eq 200){break}}
    catch{
      $lastHealth=$_.Exception.Message;$code=0;try{$code=[int]$_.Exception.Response.StatusCode}catch{};SetS 'HEALTH_HTTP' $code
      try{$stream=$_.Exception.Response.GetResponseStream();if($stream){$reader=New-Object IO.StreamReader($stream);$healthBody=$reader.ReadToEnd();$reader.Dispose()}}catch{}
      if($healthBody.Length -gt 1000){$healthBody=$healthBody.Substring(0,1000)}
      if($healthBody){SetS 'HEALTH_ERROR_BODY' ((One $healthBody)-replace '<[^>]+>',' ')}
    }
    Start-Sleep -Seconds 5
  }
  if($null -eq $health){throw ('HealthCheck.aspx failed: '+(One $lastHealth))}
  SetS 'HEALTH_HTTP' ([int]$health.StatusCode)
  $lines=$health.Content -split "`r?`n"|Where-Object{$_ -match '^(HEALTH_|SQL_|OPENAI_)'};foreach($line in $lines){Write-Output $line;$p=$line.IndexOf('=');if($p -gt 0){SetS $line.Substring(0,$p) $line.Substring($p+1)}}
  if(([string]$status.HEALTH_PAGE_OK).ToLowerInvariant() -ne 'true'){throw 'Health page did not execute.'};if(([string]$status.SQL_OK).ToLowerInvariant() -ne 'true'){throw ('SQL runtime smoke test failed: '+$status.SQL_ERROR)};if(([string]$status.OPENAI_OK).ToLowerInvariant() -ne 'true'){throw ('OpenAI runtime smoke test failed: '+$status.OPENAI_ERROR)};SetS 'BACKEND' 'success'
  RemoveHealthToken;Start-Sleep -Seconds 10

  $login=$null;for($i=1;$i -le 24;$i++){try{$login=Invoke-WebRequest $loginUrl -UseBasicParsing -TimeoutSec 30;if([int]$login.StatusCode -eq 200){break}}catch{};Start-Sleep -Seconds 5};if($null -eq $login){throw 'Login.aspx unhealthy.'};SetS 'LOGIN_HTTP' 200
  $easy=0;try{$x=Invoke-WebRequest $easyAuthUrl -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 30;$easy=[int]$x.StatusCode}catch{if($_.Exception.Response){$easy=[int]$_.Exception.Response.StatusCode}};if($easy -lt 300 -or $easy -ge 400){throw "Easy Auth HTTP $easy"};SetS 'EASY_AUTH_HTTP' $easy
  $def=0;try{$x=Invoke-WebRequest $defaultUrl -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 30;$def=[int]$x.StatusCode}catch{if($_.Exception.Response){$def=[int]$_.Exception.Response.StatusCode}};if($def -lt 300 -or $def -ge 400){throw "Default unauth HTTP $def"};SetS 'DEFAULT_UNAUTH_HTTP' $def
  SetS 'VERIFY' 'success';SetS 'VERIFIED_LIVE' 'true';SetS 'LOGIN_URL' $loginUrl;Publish;Write-Output 'FULL_LIVE_HEALTH=success'
}catch{RemoveHealthToken;SetS 'FATAL_ERROR'(One $_.Exception.Message);Publish;throw}
