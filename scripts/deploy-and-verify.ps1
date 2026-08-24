$ErrorActionPreference = 'Stop'

$repoRoot = $env:GITHUB_WORKSPACE
$resourceGroup = $env:AZURE_RESOURCE_GROUP
$webApp = $env:WEB_APP
$loginUrl = $env:LOGIN_URL
$defaultUrl = $env:DEFAULT_URL
$easyAuthUrl = $env:EASY_AUTH_URL
$status = [ordered]@{
    SOURCE_COMMIT = $env:GITHUB_SHA
    PACKAGE = 'failure'
    OIDC = 'success'
    SETTINGS = 'failure'
    DEPLOY = 'failure'
    BACKEND = 'failure'
    VERIFY = 'failure'
}

function Set-Status([string]$Name, [object]$Value) {
    $script:status[$Name] = if ($null -eq $Value) { '' } else { [string]$Value }
}

function One-Line([object]$Value) {
    if ($null -eq $Value) { return '' }
    return ([string]$Value) -replace '[\r\n]+', ' '
}

function Get-KeyNames([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($part in ($Value -split ';')) {
        $p = $part.IndexOf('=')
        if ($p -gt 0) {
            $name = $part.Substring(0, $p).Trim().Trim('"').Trim("'")
            if ($name -and -not $names.Contains($name)) { $names.Add($name) }
        }
    }
    return ($names -join ',')
}

function Normalize-Sql([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $v = $Value.Trim()
    if ($v -match '(?is)^\s*BAP_SUPPORT_CONNECTION_STRING\s*=\s*(.+)$') { $v = $Matches[1].Trim() }
    if ($v.StartsWith('{')) {
        try {
            $j = $v | ConvertFrom-Json
            if ($j.ConnectionString) { $v = [string]$j.ConnectionString }
            elseif ($j.connectionString) { $v = [string]$j.connectionString }
        } catch { }
    }
    if ($v -match '(?is)<add\b.*?\bconnectionString\s*=\s*"([^"]+)"') {
        $v = [System.Net.WebUtility]::HtmlDecode($Matches[1]).Trim()
    }
    elseif ($v -match "(?is)<add\b.*?\bconnectionString\s*=\s*'([^']+)'") {
        $v = [System.Net.WebUtility]::HtmlDecode($Matches[1]).Trim()
    }
    elseif ($v -match '(?is)^\s*(?:Name\s*=\s*[^;]+\s*;\s*)?ConnectionString\s*=\s*(.+)$') {
        $v = $Matches[1].Trim()
    }
    if ($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[$v.Length - 1] -eq '"') -or ($v[0] -eq "'" -and $v[$v.Length - 1] -eq "'"))) {
        $v = $v.Substring(1, $v.Length - 2).Trim()
    }
    $v = [regex]::Replace($v, '(?i)\bConnectTimeout\s*=', 'Connect Timeout=')
    $v = [regex]::Replace($v, '(?i)\bConnectionTimeout\s*=', 'Connection Timeout=')
    $v = [regex]::Replace($v, '(?i)(^|;)\s*Timeout\s*=', '$1Connect Timeout=')
    return $v.Trim()
}

function Publish-Status {
    try {
        Set-Status 'CHECKED_UTC' ([DateTime]::UtcNow.ToString('o'))
        $dir = Join-Path $env:RUNNER_TEMP 'deployment-status-publish'
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        @($status.GetEnumerator() | ForEach-Object { "$($_.Key)=$(One-Line $_.Value)" }) | Set-Content (Join-Path $dir 'status.txt') -Encoding ascii
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
        Write-Warning ('Status publish failed: ' + $_.Exception.Message)
    }
}

function Invoke-KuduSqlProbe {
    param([string]$ManagementToken)

    $kuduUri = "https://$webApp.scm.azurewebsites.net/api/command"
    $body = @{
        command = 'powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File D:\home\site\wwwroot\App_Data\sql-health.ps1'
        dir = 'site\wwwroot'
    } | ConvertTo-Json -Compress

    $headers = @{ Authorization = "Bearer $ManagementToken" }
    $result = $null
    $lastError = $null

    for ($attempt = 1; $attempt -le 8; $attempt++) {
        try {
            $result = Invoke-RestMethod -Method Post -Uri $kuduUri -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 120
            break
        } catch {
            $lastError = $_
            Start-Sleep -Seconds 5
        }
    }

    if ($null -eq $result) {
        # Fallback to SCM publishing credentials if bearer auth is unavailable.
        try {
            $profiles = az webapp deployment list-publishing-profiles -g $resourceGroup -n $webApp --output json | ConvertFrom-Json
            $profile = @($profiles | Where-Object { $_.publishMethod -eq 'MSDeploy' -or $_.publishMethod -eq 'ZipDeploy' } | Select-Object -First 1)
            if ($profile.Count -gt 0) {
                $user = [string]$profile[0].userName
                $pass = [string]$profile[0].userPWD
                if (-not [string]::IsNullOrWhiteSpace($user) -and -not [string]::IsNullOrWhiteSpace($pass)) {
                    Write-Output "::add-mask::$user"
                    Write-Output "::add-mask::$pass"
                    $basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($user + ':' + $pass))
                    $result = Invoke-RestMethod -Method Post -Uri $kuduUri -Headers @{ Authorization = "Basic $basic" } -ContentType 'application/json' -Body $body -TimeoutSec 120
                }
            }
        } catch {
            $lastError = $_
        }
    }

    if ($null -eq $result) {
        throw ('Kudu SQL probe failed: ' + (One-Line $lastError.Exception.Message))
    }

    $text = ([string]$result.Output) + "`n" + ([string]$result.Error)
    $probe = [ordered]@{}
    foreach ($line in ($text -split "`r?`n" | Where-Object { $_ -match '^SQL_' })) {
        $pos = $line.IndexOf('=')
        if ($pos -gt 0) { $probe[$line.Substring(0, $pos)] = $line.Substring($pos + 1) }
    }
    return $probe
}

function Copy-ProbeToStatus($Probe) {
    foreach ($entry in $Probe.GetEnumerator()) {
        Set-Status $entry.Key $entry.Value
        Write-Output ($entry.Key + '=' + $entry.Value)
    }
}

function Try-AzureSqlFirewallRepair {
    param(
        [System.Data.SqlClient.SqlConnectionStringBuilder]$Builder,
        [string]$Classification,
        [string]$ManagementToken
    )

    Set-Status 'SQL_FIREWALL_AUTOFIX' 'not_applicable'
    if ($Classification -notin @('CONNECT_TIMEOUT','NETWORK_OR_DNS','NETWORK_TIMEOUT','DNS_LOOKUP_FAILED')) { return $null }

    $hostName = ([string]$Builder.DataSource).Trim().ToLowerInvariant()
    if ($hostName.StartsWith('tcp:')) { $hostName = $hostName.Substring(4) }
    if ($hostName.Contains(',')) { $hostName = $hostName.Split(',')[0] }
    if (-not $hostName.EndsWith('.database.windows.net')) { return $null }

    $servers = az sql server list --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { Set-Status 'SQL_FIREWALL_AUTOFIX' 'server_lookup_failed'; return $null }
    $server = @($servers | Where-Object {
        ([string]$_.fullyQualifiedDomainName).ToLowerInvariant() -eq $hostName -or (([string]$_.name).ToLowerInvariant() + '.database.windows.net') -eq $hostName
    } | Select-Object -First 1)
    if ($server.Count -eq 0) { Set-Status 'SQL_FIREWALL_AUTOFIX' 'server_not_in_subscription'; return $null }

    $publicAccess = [string]$server[0].publicNetworkAccess
    if ([string]::Equals($publicAccess, 'Disabled', [StringComparison]::OrdinalIgnoreCase)) {
        Set-Status 'SQL_FIREWALL_AUTOFIX' 'skipped_public_network_disabled'
        return $null
    }

    $serverName = [string]$server[0].name
    $serverRg = [string]$server[0].resourceGroup
    $ipsText = az webapp show -g $resourceGroup -n $webApp --query possibleOutboundIpAddresses -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ipsText)) {
        Set-Status 'SQL_FIREWALL_AUTOFIX' 'outbound_ips_unavailable'
        return $null
    }

    $ips = @($ipsText.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' } | Select-Object -Unique)
    if ($ips.Count -eq 0) { Set-Status 'SQL_FIREWALL_AUTOFIX' 'outbound_ips_unavailable'; return $null }

    Set-Status 'SQL_FIREWALL_RULES_ATTEMPTED' $ips.Count
    $success = 0
    foreach ($ip in $ips) {
        $suffix = ($ip -replace '\.', '-')
        $ruleName = ('BabcoSqlAgent-' + $suffix)
        az sql server firewall-rule create -g $serverRg -s $serverName -n $ruleName --start-ip-address $ip --end-ip-address $ip --output none 2>$null
        if ($LASTEXITCODE -eq 0) { $success++ }
    }
    Set-Status 'SQL_FIREWALL_RULES_APPLIED' $success
    if ($success -eq $ips.Count) { Set-Status 'SQL_FIREWALL_AUTOFIX' 'applied' }
    elseif ($success -gt 0) { Set-Status 'SQL_FIREWALL_AUTOFIX' 'partially_applied' }
    else { Set-Status 'SQL_FIREWALL_AUTOFIX' 'failed' }

    if ($success -gt 0) {
        Start-Sleep -Seconds 12
        return (Invoke-KuduSqlProbe -ManagementToken $ManagementToken)
    }
    return $null
}

function Test-OpenAI {
    param([string]$ApiKey, [string]$Model)
    $result = [ordered]@{}
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $payload = @{ model = $Model; input = 'Reply only OK' } | ConvertTo-Json -Compress
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Method Post -Uri 'https://api.openai.com/v1/responses' -Headers @{ Authorization = ('Bearer ' + $ApiKey) } -ContentType 'application/json' -Body $payload -UseBasicParsing -TimeoutSec 30
        $sw.Stop()
        $result.OPENAI_OK = (([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 300).ToString().ToLowerInvariant())
        $result.OPENAI_HTTP = [int]$response.StatusCode
        $result.OPENAI_MS = $sw.ElapsedMilliseconds
        $result.OPENAI_MODEL_TESTED = $Model
    } catch {
        $http = 0
        try { $http = [int]$_.Exception.Response.StatusCode } catch { }
        $code = ''
        $message = ''
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            if ($stream) {
                $reader = New-Object IO.StreamReader($stream)
                $body = $reader.ReadToEnd(); $reader.Dispose()
                $json = $body | ConvertFrom-Json
                $code = [string]$json.error.code
                $message = [string]$json.error.message
            }
        } catch { }
        if ([string]::IsNullOrWhiteSpace($message)) { $message = $_.Exception.Message }
        if ($message.Length -gt 500) { $message = $message.Substring(0, 500) }
        $result.OPENAI_OK = 'false'
        $result.OPENAI_HTTP = $http
        $result.OPENAI_ERROR_CODE = $code
        $result.OPENAI_ERROR_MESSAGE = One-Line $message
        $result.OPENAI_MODEL_TESTED = $Model
    }
    return $result
}

try {
    # 1) Reconstruct complete supplied source and apply production overrides.
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
    if (-not (Test-Path $site)) { throw 'SQL_AI_Agent source folder missing.' }

    $overrides = Join-Path $repoRoot 'deploy-overrides'
    Get-ChildItem $overrides -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($overrides.Length).TrimStart([char[]]@('\','/'))
        $dest = Join-Path $site $rel
        $parent = Split-Path $dest -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item $_.FullName $dest -Force
    }
    Set-Status 'OVERRIDES_APPLIED' 'true'

    foreach ($f in @('Login.aspx','Login.aspx.cs','Default.aspx','Web.config','App_Data\sql-health.ps1','App_Code\AppConfig.cs','App_Code\AuthService.cs','App_Code\SqlTool.cs','App_Code\AgentService.cs','App_Code\OpenAIClient.cs')) {
        if (-not (Test-Path (Join-Path $site $f))) { throw "Missing runtime source file: $f" }
    }
    $runtime = (Get-Content (Join-Path $site 'Login.aspx') -Raw) + (Get-Content (Join-Path $site 'Login.aspx.cs') -Raw) + (Get-Content (Join-Path $site 'App_Code\AuthService.cs') -Raw)
    if ($runtime -match 'Local Test Admin Login|Continue Without Microsoft|LOCAL-ADMIN|LocalTestAdminLogin|CanUseLocalTestLogin|btnTemporary|btnLocalTest|ENTRA_CLIENT_SECRET') {
        throw 'Forbidden local auth/custom Entra secret logic present.'
    }
    Set-Status 'SOURCE_LOCAL_ADMIN_REMOVED' 'true'
    Set-Status 'SOURCE_EASY_AUTH' 'true'
    Set-Status 'SOURCE_GLOBAL_SQL' 'true'

    $zip = Join-Path $env:RUNNER_TEMP 'site.zip'
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $site '*') -DestinationPath $zip -Force
    Set-Status 'PACKAGE' 'success'
    Set-Status 'PACKAGE_VALID' 'true'

    # 2) Read and validate server-side settings without exposing values.
    $settings = az webapp config appsettings list -g $resourceGroup -n $webApp --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read App Service settings.' }
    $sqlItem = @($settings | Where-Object { $_.name -eq 'BAP_SUPPORT_CONNECTION_STRING' })
    $keyItem = @($settings | Where-Object { $_.name -eq 'OPENAI_API_KEY_DEVELOPMENT' })
    $modelItem = @($settings | Where-Object { $_.name -eq 'OPENAI_MODEL' })
    $sqlPresent = $sqlItem.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$sqlItem[0].value)
    $keyPresent = $keyItem.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$keyItem[0].value)
    Set-Status 'SQL_SETTING_PRESENT' $sqlPresent.ToString().ToLowerInvariant()
    Set-Status 'OPENAI_SETTING_PRESENT' $keyPresent.ToString().ToLowerInvariant()
    if (-not $sqlPresent) { throw 'BAP_SUPPORT_CONNECTION_STRING missing.' }
    if (-not $keyPresent) { throw 'OPENAI_API_KEY_DEVELOPMENT missing.' }

    $rawSql = [string]$sqlItem[0].value
    $rawKey = [string]$keyItem[0].value
    Write-Output "::add-mask::$rawSql"
    Write-Output "::add-mask::$rawKey"
    Set-Status 'SQL_RAW_KEY_NAMES' (Get-KeyNames $rawSql)
    $sql = Normalize-Sql $rawSql
    Write-Output "::add-mask::$sql"
    Set-Status 'SQL_NORMALIZED_KEY_NAMES' (Get-KeyNames $sql)

    Add-Type -AssemblyName System.Data
    try {
        $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new([string]$sql)
        Set-Status 'SQL_PARSE_OK' 'true'
    } catch {
        Set-Status 'SQL_PARSE_OK' 'false'
        Set-Status 'SQL_PARSE_ERROR' $_.Exception.Message
        throw
    }

    if ($sql -ne $rawSql) {
        az webapp config appsettings set -g $resourceGroup -n $webApp --settings "BAP_SUPPORT_CONNECTION_STRING=$sql" --output none
        if ($LASTEXITCODE -ne 0) { throw 'Failed to canonicalize SQL setting.' }
        Set-Status 'SQL_SETTING_CANONICALIZED' 'true'
    } else {
        Set-Status 'SQL_SETTING_CANONICALIZED' 'false'
    }
    Set-Status 'SETTINGS' 'success'

    # 3) Deploy stable application and restart.
    az webapp start -g $resourceGroup -n $webApp | Out-Null
    az webapp deploy -g $resourceGroup -n $webApp --src-path $zip --type zip --clean true --restart true | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Azure ZIP deployment failed.' }
    az webapp restart -g $resourceGroup -n $webApp | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Azure App Service restart failed.' }
    Set-Status 'DEPLOY' 'success'
    Start-Sleep -Seconds 20

    # 4) SQL smoke test from the App Service/Kudu sandbox.
    $managementToken = az account get-access-token --resource https://management.azure.com/ --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($managementToken)) { throw 'Unable to acquire Azure management token for Kudu SQL probe.' }
    Write-Output "::add-mask::$managementToken"

    $sqlProbe = Invoke-KuduSqlProbe -ManagementToken $managementToken
    Copy-ProbeToStatus $sqlProbe

    if (([string]$sqlProbe.SQL_OK).ToLowerInvariant() -ne 'true') {
        $classification = [string]$sqlProbe.SQL_ERROR_CLASSIFICATION
        $retryProbe = Try-AzureSqlFirewallRepair -Builder $builder -Classification $classification -ManagementToken $managementToken
        if ($null -ne $retryProbe) {
            $sqlProbe = $retryProbe
            Copy-ProbeToStatus $sqlProbe
        }
    }

    if (([string]$sqlProbe.SQL_OK).ToLowerInvariant() -ne 'true') {
        throw ("SQL runtime smoke test failed: classification=$($sqlProbe.SQL_ERROR_CLASSIFICATION) number=$($sqlProbe.SQL_ERROR_NUMBER) type=$($sqlProbe.SQL_ERROR_TYPE)")
    }

    # 5) OpenAI API smoke test independently from SQL.
    $model = if ($modelItem.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$modelItem[0].value)) { ([string]$modelItem[0].value).Trim() } else { 'gpt-5-mini' }
    $openAi = Test-OpenAI -ApiKey $rawKey -Model $model
    foreach ($entry in $openAi.GetEnumerator()) {
        Set-Status $entry.Key $entry.Value
        if ($entry.Key -notmatch 'ERROR_MESSAGE') { Write-Output ($entry.Key + '=' + $entry.Value) }
    }
    if (([string]$openAi.OPENAI_OK).ToLowerInvariant() -ne 'true') {
        throw ("OpenAI runtime smoke test failed: HTTP=$($openAi.OPENAI_HTTP) code=$($openAi.OPENAI_ERROR_CODE)")
    }
    Set-Status 'BACKEND' 'success'

    # 6) Live Entra and application routing verification.
    $login = $null
    for ($i = 1; $i -le 24; $i++) {
        try {
            $login = Invoke-WebRequest $loginUrl -UseBasicParsing -TimeoutSec 30
            if ([int]$login.StatusCode -eq 200) { break }
        } catch { }
        Start-Sleep -Seconds 5
    }
    if ($null -eq $login -or [int]$login.StatusCode -ne 200) { throw 'Login.aspx unhealthy.' }
    if ($login.Content -match 'Local Test Admin Login|Continue Without Microsoft') { throw 'Local/temporary login is visible on live site.' }
    if ($login.Content -notmatch 'Sign in with Microsoft Entra ID') { throw 'Microsoft Entra login button is missing on live site.' }
    Set-Status 'LOGIN_HTTP' 200
    Set-Status 'LOCAL_ADMIN_REMOVED' 'true'

    $easy = 0
    try { $r = Invoke-WebRequest $easyAuthUrl -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 30; $easy = [int]$r.StatusCode }
    catch { if ($_.Exception.Response) { $easy = [int]$_.Exception.Response.StatusCode } }
    if ($easy -lt 300 -or $easy -ge 400) { throw "Easy Auth HTTP $easy instead of Microsoft redirect." }
    Set-Status 'EASY_AUTH_HTTP' $easy

    $def = 0
    try { $r = Invoke-WebRequest $defaultUrl -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 30; $def = [int]$r.StatusCode }
    catch { if ($_.Exception.Response) { $def = [int]$_.Exception.Response.StatusCode } }
    if ($def -lt 300 -or $def -ge 400) { throw "Default unauth HTTP $def instead of redirect." }
    Set-Status 'DEFAULT_UNAUTH_HTTP' $def

    Set-Status 'VERIFY' 'success'
    Set-Status 'VERIFIED_LIVE' 'true'
    Set-Status 'LOGIN_URL' $loginUrl
    Publish-Status
    Write-Output 'FULL_LIVE_HEALTH=success'
}
catch {
    Set-Status 'FATAL_ERROR' (One-Line $_.Exception.Message)
    Publish-Status
    throw
}
