$ErrorActionPreference = 'Stop'

$status = Join-Path $env:RUNNER_TEMP 'admin-costing-safe-status.txt'
"SOURCE_COMMIT=$env:GITHUB_SHA" | Set-Content $status -Encoding ascii
@(
    'DEPLOY_METHOD=FTPS',
    'DEPLOY_SCOPE=Admin.aspx,Admin.aspx.cs,Default.aspx-link-only',
    'AUTH_FILES_WRITTEN=false',
    'CONFIG_FILES_WRITTEN=false',
    'APP_SETTINGS_WRITTEN=false',
    'AUTH_SETTINGS_WRITTEN=false',
    'PACKAGE_ADMIN_VALID=true',
    'ADMIN_AUTHSERVICE_DEPENDENCY=false',
    'ADMIN_EASYAUTH_HEADERS=true',
    'FTP_POLICY_API=2025-03-01'
) | Add-Content $status

function HashText([string]$text) {
    if ($null -eq $text) { $text = '' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function CanonicalAppSettings {
    return (az webapp config appsettings list -g $env:RESOURCE_GROUP -n $env:WEB_APP -o json | ConvertFrom-Json | Sort-Object name | ConvertTo-Json -Depth 20 -Compress)
}

$script:policyCollectionUrl = "https://management.azure.com/subscriptions/$env:AZURE_SUBSCRIPTION_ID/resourceGroups/$env:RESOURCE_GROUP/providers/Microsoft.Web/sites/$env:WEB_APP/basicPublishingCredentialsPolicies?api-version=2025-03-01"
$script:policyItemUrl = "https://management.azure.com/subscriptions/$env:AZURE_SUBSCRIPTION_ID/resourceGroups/$env:RESOURCE_GROUP/providers/Microsoft.Web/sites/$env:WEB_APP/basicPublishingCredentialsPolicies/ftp?api-version=2025-03-01"

function GetFtpPolicy {
    $raw = az rest --method get --url $script:policyCollectionUrl -o json
    if ($LASTEXITCODE -ne 0) { throw 'Unable to list Basic Publishing Credentials policies through ARM REST.' }
    $obj = $raw | ConvertFrom-Json
    $ftp = @($obj.value | Where-Object { (([string]$_.name -split '/')[-1]) -ieq 'ftp' } | Select-Object -First 1)
    if ($ftp.Count -eq 0) { throw 'FTP Basic Publishing Credentials policy was not returned by ARM.' }
    return ([bool]$ftp[0].properties.allow).ToString().ToLowerInvariant()
}

function SetFtpPolicy([bool]$allow) {
    $body = @{ properties = @{ allow = $allow } } | ConvertTo-Json -Compress
    az rest --method put --url $script:policyItemUrl --headers 'Content-Type=application/json' --body $body -o none
    if ($LASTEXITCODE -ne 0) { throw "Unable to set FTP Basic Publishing Credentials policy to $allow through ARM REST." }
}

function LoadFtpProfile {
    $profiles = az webapp deployment list-publishing-profiles -g $env:RESOURCE_GROUP -n $env:WEB_APP -o json | ConvertFrom-Json
    $ftp = @($profiles | Where-Object { $_.publishMethod -eq 'FTP' } | Select-Object -First 1)
    if ($ftp.Count -eq 0) { throw 'FTP publishing profile unavailable.' }

    $script:ftpUser = [string]$ftp[0].userName
    $script:ftpPassword = [string]$ftp[0].userPWD
    Write-Output "::add-mask::$script:ftpUser"
    Write-Output "::add-mask::$script:ftpPassword"

    $publishUrl = [string]$ftp[0].publishUrl
    if ([string]::IsNullOrWhiteSpace($publishUrl)) { throw 'FTP publish URL unavailable.' }
    if ($publishUrl -notmatch '^[a-zA-Z]+://') { $publishUrl = 'ftp://' + $publishUrl }
    $ftpUri = [Uri]$publishUrl
    $scheme = if ($ftpUri.Scheme -eq 'ftps') { 'ftps' } else { 'ftp' }
    $script:ftpBase = $scheme + '://' + $ftpUri.Authority + $ftpUri.AbsolutePath.TrimEnd('/')
}

function FtpDownload([string]$relative, [string]$local) {
    $url = $script:ftpBase + '/' + ($relative.Replace('\', '/'))
    & curl.exe --silent --show-error --fail --ssl-reqd --user ($script:ftpUser + ':' + $script:ftpPassword) --output $local $url
    if ($LASTEXITCODE -ne 0) { throw "FTPS download failed for $relative with exit $LASTEXITCODE" }
}

function FtpDownloadRetry([string]$relative, [string]$local) {
    $last = 0
    for ($i = 1; $i -le 8; $i++) {
        $url = $script:ftpBase + '/' + ($relative.Replace('\', '/'))
        & curl.exe --silent --show-error --fail --ssl-reqd --user ($script:ftpUser + ':' + $script:ftpPassword) --output $local $url
        $last = $LASTEXITCODE
        if ($last -eq 0) { return }
        Start-Sleep -Seconds 5
        LoadFtpProfile
    }
    throw "FTPS download failed for $relative after retries with exit $last"
}

function FtpUpload([string]$relative, [string]$local) {
    $url = $script:ftpBase + '/' + ($relative.Replace('\', '/'))
    & curl.exe --silent --show-error --fail --ssl-reqd --ftp-create-dirs --user ($script:ftpUser + ':' + $script:ftpPassword) --upload-file $local $url
    if ($LASTEXITCODE -ne 0) { throw "FTPS upload failed for $relative with exit $LASTEXITCODE" }
}

function VerifyHttp {
    $loginCode = 0
    for ($i = 1; $i -le 15; $i++) {
        try {
            $r = Invoke-WebRequest -Uri $env:LOGIN_URL -UseBasicParsing -MaximumRedirection 5 -TimeoutSec 20
            $loginCode = [int]$r.StatusCode
        }
        catch { $loginCode = 0 }
        if ($loginCode -eq 200) { break }
        Start-Sleep -Seconds 3
    }
    Add-Content $status "LOGIN_HTTP=$loginCode"

    $entraChallenge = $false
    $entraCode = 0
    try {
        $entraUrl = "https://$env:WEB_APP.azurewebsites.net/.auth/login/aad?post_login_redirect_uri=%2FAuthComplete.aspx"
        $r = Invoke-WebRequest -Uri $entraUrl -MaximumRedirection 0 -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
        $entraCode = [int]$r.StatusCode
        if ($entraCode -eq 302 -and $r.Headers.Location) { $entraChallenge = $true }
    }
    catch {
        try {
            $entraCode = [int]$_.Exception.Response.StatusCode
            $loc = [string]$_.Exception.Response.Headers['Location']
            if ($entraCode -eq 302 -and $loc) { $entraChallenge = $true }
        }
        catch { }
    }
    Add-Content $status "ENTRA_HTTP=$entraCode"
    Add-Content $status ('ENTRA_CHALLENGE=' + $entraChallenge.ToString().ToLowerInvariant())

    $adminCode = 0
    try {
        $r2 = Invoke-WebRequest -Uri $env:ADMIN_URL -MaximumRedirection 0 -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
        $adminCode = [int]$r2.StatusCode
    }
    catch {
        try { $adminCode = [int]$_.Exception.Response.StatusCode } catch { }
    }
    Add-Content $status "ADMIN_HTTP_UNAUTH=$adminCode"
    Add-Content $status "CHECKED_UTC=$([DateTime]::UtcNow.ToString('o'))"
}

$adminPath = Join-Path $env:GITHUB_WORKSPACE 'deploy-overrides\Admin.aspx'
$adminCsPath = Join-Path $env:GITHUB_WORKSPACE 'deploy-overrides\Admin.aspx.cs'
$adminText = Get-Content $adminPath -Raw
$adminCsText = Get-Content $adminCsPath -Raw
if (-not $adminText.Contains('Admin Console') -or -not $adminText.Contains('Costing')) { throw 'Admin UI validation failed.' }
if ($adminCsText.Contains('AuthService')) { throw 'Admin code must not depend on AuthService.' }
if (-not $adminCsText.Contains('X-MS-CLIENT-PRINCIPAL-NAME')) { throw 'Easy Auth identity header missing.' }
if (-not $adminCsText.Contains('kirti@babcofoods.com')) { throw 'Admin authorization rule missing.' }

$settingsHashBefore = HashText (CanonicalAppSettings)
$originalFtpPolicy = GetFtpPolicy
Add-Content $status ('FTP_BASIC_ORIGINAL=' + $originalFtpPolicy)
$temporarilyEnabled = $false
$tmp = Join-Path $env:RUNNER_TEMP ('admin-ftps-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
    if ($originalFtpPolicy -ne 'true') {
        SetFtpPolicy $true
        $temporarilyEnabled = $true
        Add-Content $status 'FTP_BASIC_TEMP_ENABLED=true'
        Start-Sleep -Seconds 12
    }
    else {
        Add-Content $status 'FTP_BASIC_TEMP_ENABLED=false'
    }

    $effective = GetFtpPolicy
    Add-Content $status ('FTP_BASIC_DURING=' + $effective)
    if ($effective -ne 'true') { throw 'FTP Basic Publishing Credentials policy did not become enabled.' }

    LoadFtpProfile
    $probe = Join-Path $tmp 'Login.probe.aspx'
    FtpDownloadRetry 'Login.aspx' $probe
    Add-Content $status 'FTP_ACCESS=true'

    $protected = @(
        'Login.aspx',
        'Login.aspx.cs',
        'AuthComplete.aspx',
        'AuthComplete.aspx.cs',
        'App_Code\AuthService.cs',
        'App_Code\AppConfig.cs',
        'Web.config'
    )
    $before = @{}
    foreach ($rel in $protected) {
        $local = Join-Path $tmp (($rel -replace '[\\/]', '_') + '.before')
        if ($rel -eq 'Login.aspx') { Copy-Item $probe $local -Force } else { FtpDownload $rel $local }
        $before[$rel] = (Get-FileHash $local -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    $defaultLocal = Join-Path $tmp 'Default.aspx'
    FtpDownload 'Default.aspx' $defaultLocal
    $default = Get-Content $defaultLocal -Raw
    $patched = $default
    $patchType = 'already-present'
    if (-not $patched.Contains('Costing / Admin')) {
        $old = '    <div class="status">&#9679; AI Agent Ready</div>'
        $new = '    <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;justify-content:flex-end"><a href="Admin.aspx" style="display:inline-block;padding:8px 11px;border-radius:18px;border:1px solid #fde68a;background:#fef3c7;color:#92400e;text-decoration:none;font-size:12px;font-weight:600">Costing / Admin</a><div class="status">&#9679; AI Agent Ready</div></div>'
        if ($patched.Contains($old)) {
            $patched = $patched.Replace($old, $new)
            $patchType = 'base-status-marker'
        }
        elseif ($patched.Contains('<span class="status">')) {
            $patched = $patched.Replace('<span class="status">', '<a class="navbtn adminlink" href="Admin.aspx">Costing / Admin</a><span class="status">')
            $patchType = 'span-status-marker'
        }
        else { throw 'Unknown Default.aspx layout; refusing broad replacement.' }
        [IO.File]::WriteAllText($defaultLocal, $patched, (New-Object Text.UTF8Encoding($false)))
    }

    FtpUpload 'Admin.aspx' $adminPath
    FtpUpload 'Admin.aspx.cs' $adminCsPath
    if ($patched -ne $default) { FtpUpload 'Default.aspx' $defaultLocal }
    Add-Content $status ('DEFAULT_LINK_PATCH=' + $patchType)

    $unchanged = $true
    foreach ($rel in $protected) {
        $local = Join-Path $tmp (($rel -replace '[\\/]', '_') + '.after')
        FtpDownload $rel $local
        $after = (Get-FileHash $local -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($before[$rel] -ne $after) {
            $unchanged = $false
            Add-Content $status ('PROTECTED_CHANGED=' + $rel)
        }
    }
    Add-Content $status ('PROTECTED_FILES_UNCHANGED=' + $unchanged.ToString().ToLowerInvariant())
    if (-not $unchanged) { throw 'Protected live files changed unexpectedly.' }

    $liveAdmin = Join-Path $tmp 'Admin.live.aspx'
    $liveAdminCs = Join-Path $tmp 'Admin.live.aspx.cs'
    $liveDefault = Join-Path $tmp 'Default.live.aspx'
    FtpDownload 'Admin.aspx' $liveAdmin
    FtpDownload 'Admin.aspx.cs' $liveAdminCs
    FtpDownload 'Default.aspx' $liveDefault

    $liveAdminText = Get-Content $liveAdmin -Raw
    $liveAdminCsText = Get-Content $liveAdminCs -Raw
    $liveDefaultText = Get-Content $liveDefault -Raw
    Add-Content $status ('ADMIN_FILE=' + $liveAdminText.Contains('Admin Console').ToString().ToLowerInvariant())
    Add-Content $status ('ADMIN_COSTING=' + $liveAdminText.Contains('Costing').ToString().ToLowerInvariant())
    Add-Content $status ('ADMIN_CODEBEHIND=' + (Test-Path $liveAdminCs).ToString().ToLowerInvariant())
    Add-Content $status ('ADMIN_AUTHSERVICE_LIVE=' + $liveAdminCsText.Contains('AuthService').ToString().ToLowerInvariant())
    Add-Content $status ('DEFAULT_ADMIN_LINK=' + $liveDefaultText.Contains('Costing / Admin').ToString().ToLowerInvariant())

    if (-not $liveAdminText.Contains('Admin Console')) { throw 'Live Admin.aspx verification failed.' }
    if ($liveAdminCsText.Contains('AuthService')) { throw 'Live Admin code unexpectedly references AuthService.' }
    if (-not $liveDefaultText.Contains('Costing / Admin')) { throw 'Live Default Admin link verification failed.' }
}
finally {
    if ($temporarilyEnabled) {
        try {
            SetFtpPolicy $false
            Start-Sleep -Seconds 6
        }
        catch {
            Add-Content $status ('FTP_POLICY_RESTORE_ERROR=' + $_.Exception.Message)
            throw
        }
    }

    $restoredPolicy = GetFtpPolicy
    $policyRestored = ($restoredPolicy -eq $originalFtpPolicy)
    Add-Content $status ('FTP_BASIC_FINAL=' + $restoredPolicy)
    Add-Content $status ('FTP_POLICY_RESTORED=' + $policyRestored.ToString().ToLowerInvariant())
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    if (-not $policyRestored) { throw 'FTP Basic Publishing Credentials policy was not restored.' }
}

$settingsHashAfter = HashText (CanonicalAppSettings)
Add-Content $status ('APPSETTINGS_UNCHANGED=' + ($settingsHashBefore -eq $settingsHashAfter).ToString().ToLowerInvariant())
if ($settingsHashBefore -ne $settingsHashAfter) { throw 'App settings changed unexpectedly.' }

Add-Content $status 'DEPLOY=success'
VerifyHttp
