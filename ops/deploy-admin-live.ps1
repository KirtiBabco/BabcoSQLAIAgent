param(
    [Parameter(Mandatory=$true)][string]$Commit
)

$ErrorActionPreference = 'Stop'
$root = 'D:\home\site\wwwroot'
if (-not (Test-Path $root)) { $root = 'C:\home\site\wwwroot' }
if (-not (Test-Path $root)) { throw 'Live wwwroot not found.' }

function FileHashOrMissing([string]$Path) {
    if (Test-Path $Path) { return (Get-FileHash $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
    return 'missing'
}

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
foreach ($rel in $protected) { $before[$rel] = FileHashOrMissing (Join-Path $root $rel) }

$defaultPath = Join-Path $root 'Default.aspx'
if (-not (Test-Path $defaultPath)) { throw 'Live Default.aspx missing.' }
$default = Get-Content $defaultPath -Raw
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
    else {
        throw 'Unknown Default.aspx layout; refusing broad replacement.'
    }
}

$rawBase = 'https://raw.githubusercontent.com/KirtiBabco/BabcoSQLAIAgent/' + $Commit + '/deploy-overrides/'
$tempRoot = Join-Path $env:TEMP ('admin-costing-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $tempAdmin = Join-Path $tempRoot 'Admin.aspx'
    $tempAdminCs = Join-Path $tempRoot 'Admin.aspx.cs'
    Invoke-WebRequest -Uri ($rawBase + 'Admin.aspx') -OutFile $tempAdmin -UseBasicParsing -TimeoutSec 60
    Invoke-WebRequest -Uri ($rawBase + 'Admin.aspx.cs') -OutFile $tempAdminCs -UseBasicParsing -TimeoutSec 60

    $adminText = Get-Content $tempAdmin -Raw
    $adminCsText = Get-Content $tempAdminCs -Raw
    if (-not $adminText.Contains('Admin Console') -or -not $adminText.Contains('Costing')) { throw 'Downloaded Admin UI validation failed.' }
    if ($adminCsText.Contains('AuthService')) { throw 'Downloaded Admin code references AuthService.' }
    if (-not $adminCsText.Contains('X-MS-CLIENT-PRINCIPAL-NAME')) { throw 'Downloaded Admin code does not use Easy Auth headers.' }
    if (-not $adminCsText.Contains('kirti@babcofoods.com')) { throw 'Downloaded Admin authorization rule missing.' }

    Copy-Item $tempAdmin (Join-Path $root 'Admin.aspx') -Force
    Copy-Item $tempAdminCs (Join-Path $root 'Admin.aspx.cs') -Force
    if ($patched -ne $default) {
        [IO.File]::WriteAllText($defaultPath, $patched, (New-Object Text.UTF8Encoding($false)))
    }
}
finally {
    Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$unchanged = $true
foreach ($rel in $protected) {
    $after = FileHashOrMissing (Join-Path $root $rel)
    if ($before[$rel] -ne $after) {
        $unchanged = $false
        Write-Output ('PROTECTED_CHANGED=' + $rel)
    }
}
Write-Output ('PROTECTED_FILES_UNCHANGED=' + $unchanged.ToString().ToLowerInvariant())
Write-Output ('DEFAULT_LINK_PATCH=' + $patchType)

$liveAdminPath = Join-Path $root 'Admin.aspx'
$liveAdminCsPath = Join-Path $root 'Admin.aspx.cs'
$liveAdmin = Get-Content $liveAdminPath -Raw
$liveAdminCs = Get-Content $liveAdminCsPath -Raw
$liveDefault = Get-Content $defaultPath -Raw
Write-Output ('ADMIN_FILE=' + $liveAdmin.Contains('Admin Console').ToString().ToLowerInvariant())
Write-Output ('ADMIN_COSTING=' + $liveAdmin.Contains('Costing').ToString().ToLowerInvariant())
Write-Output ('ADMIN_CODEBEHIND=' + (Test-Path $liveAdminCsPath).ToString().ToLowerInvariant())
Write-Output ('ADMIN_AUTHSERVICE_LIVE=' + $liveAdminCs.Contains('AuthService').ToString().ToLowerInvariant())
Write-Output ('DEFAULT_ADMIN_LINK=' + $liveDefault.Contains('Costing / Admin').ToString().ToLowerInvariant())

if (-not $unchanged) { throw 'Protected files changed unexpectedly.' }
if (-not $liveAdmin.Contains('Admin Console')) { throw 'Admin.aspx verification failed.' }
if (-not (Test-Path $liveAdminCsPath)) { throw 'Admin.aspx.cs verification failed.' }
if ($liveAdminCs.Contains('AuthService')) { throw 'Live Admin code unexpectedly references AuthService.' }
if (-not $liveDefault.Contains('Costing / Admin')) { throw 'Default Admin link verification failed.' }
