$ErrorActionPreference='Continue'
function OutSafe([string]$k,[object]$v){ Write-Output ($k+'='+[string]$v) }
function NormalizeSql([string]$v){
  if([string]::IsNullOrWhiteSpace($v)){ return '' }
  $v=$v.Trim()

  # Strip accidental environment-variable assignment wrapper.
  if($v -match '(?is)^\s*BAP_SUPPORT_CONNECTION_STRING\s*=\s*(.+)$'){ $v=$Matches[1].Trim() }

  # Unwrap JSON such as {"ConnectionString":"Server=..."} without logging values.
  if($v.StartsWith('{')){
    try{
      $j=$v|ConvertFrom-Json
      if($j.ConnectionString){ $v=[string]$j.ConnectionString }
      elseif($j.connectionString){ $v=[string]$j.connectionString }
    }catch{}
  }

  # Unwrap XML/appSettings-style connectionString="...".
  if($v -match '(?is)connectionString\s*=\s*["'']([^"'']+)["'']'){ $v=$Matches[1].Trim() }
  # Unwrap plain ConnectionString=<actual SQL connection string> near the start.
  elseif($v -match '(?is)^\s*(?:Name\s*=\s*[^;]+\s*;\s*)?ConnectionString\s*=\s*(.+)$'){ $v=$Matches[1].Trim() }

  if($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[$v.Length-1] -eq '"') -or ($v[0] -eq "'" -and $v[$v.Length-1] -eq "'"))){ $v=$v.Substring(1,$v.Length-2).Trim() }

  $v=[regex]::Replace($v,'(?i)\bConnectTimeout\s*=','Connect Timeout=')
  $v=[regex]::Replace($v,'(?i)\bConnectionTimeout\s*=','Connection Timeout=')
  return $v.Trim()
}
function GetKeyNames([string]$v){
  if([string]::IsNullOrWhiteSpace($v)){ return '' }
  $names=New-Object System.Collections.Generic.List[string]
  foreach($part in ($v -split ';')){
    $p=$part.IndexOf('=')
    if($p -gt 0){
      $name=$part.Substring(0,$p).Trim().Trim('"').Trim("'")
      if($name -and -not $names.Contains($name)){ $names.Add($name) }
    }
  }
  return ($names -join ',')
}

[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$raw=[Environment]::GetEnvironmentVariable('BAP_SUPPORT_CONNECTION_STRING')
OutSafe 'SQL_SETTING_RUNTIME_PRESENT' (-not [string]::IsNullOrWhiteSpace($raw))
OutSafe 'SQL_RAW_KEY_NAMES' (GetKeyNames $raw)
$cs=NormalizeSql $raw
OutSafe 'SQL_NORMALIZED_KEY_NAMES' (GetKeyNames $cs)
try{
  Add-Type -AssemblyName System.Data
  $builder=New-Object System.Data.SqlClient.SqlConnectionStringBuilder
  $builder.ConnectionString=$cs
  $builder.ConnectTimeout=10
  $sw=[Diagnostics.Stopwatch]::StartNew()
  $connection=New-Object System.Data.SqlClient.SqlConnection($builder.ConnectionString)
  $connection.Open()
  $command=$connection.CreateCommand()
  $command.CommandTimeout=10
  $command.CommandText='SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES'
  $tables=$command.ExecuteScalar()
  $connection.Close();$sw.Stop()
  OutSafe 'SQL_OK' 'true'
  OutSafe 'SQL_TABLE_COUNT' $tables
  OutSafe 'SQL_MS' $sw.ElapsedMilliseconds
}catch{
  OutSafe 'SQL_OK' 'false'
  OutSafe 'SQL_ERROR_TYPE' $_.Exception.GetType().Name
  OutSafe 'SQL_ERROR' ($_.Exception.Message -replace '[\r\n]+',' ')
}

$key=[Environment]::GetEnvironmentVariable('OPENAI_API_KEY_DEVELOPMENT')
if([string]::IsNullOrWhiteSpace($key)){ $key=[Environment]::GetEnvironmentVariable('OPENAI_API_KEY') }
OutSafe 'OPENAI_KEY_RUNTIME_PRESENT' (-not [string]::IsNullOrWhiteSpace($key))
$model=[Environment]::GetEnvironmentVariable('OPENAI_MODEL')
if([string]::IsNullOrWhiteSpace($model)){ $model='gpt-5-mini' }
OutSafe 'OPENAI_MODEL_TESTED' $model
if(-not [string]::IsNullOrWhiteSpace($key)){
  try{
    $payload=@{model=$model;input='Reply only OK'}|ConvertTo-Json -Compress
    $sw=[Diagnostics.Stopwatch]::StartNew()
    $response=Invoke-WebRequest -Method Post -Uri 'https://api.openai.com/v1/responses' -Headers @{Authorization=('Bearer '+$key)} -ContentType 'application/json' -Body $payload -UseBasicParsing -TimeoutSec 30
    $sw.Stop()
    OutSafe 'OPENAI_OK' ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 300)
    OutSafe 'OPENAI_HTTP' ([int]$response.StatusCode)
    OutSafe 'OPENAI_MS' $sw.ElapsedMilliseconds
  }catch{
    $http='';try{$http=[int]$_.Exception.Response.StatusCode}catch{}
    OutSafe 'OPENAI_OK' 'false'
    OutSafe 'OPENAI_HTTP' $http
    OutSafe 'OPENAI_ERROR' ($_.Exception.Message -replace '[\r\n]+',' ')
  }
}else{
  OutSafe 'OPENAI_OK' 'false'
  OutSafe 'OPENAI_ERROR' 'No server-side OpenAI API key configured.'
}
