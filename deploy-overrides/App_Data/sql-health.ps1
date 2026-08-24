$ErrorActionPreference='Continue'
function OutSafe([string]$k,[object]$v){ Write-Output ($k+'='+[string]$v) }
function GetKeyNames([string]$v){
  if([string]::IsNullOrWhiteSpace($v)){return ''}
  $names=New-Object System.Collections.Generic.List[string]
  foreach($part in ($v -split ';')){
    $p=$part.IndexOf('=')
    if($p -gt 0){$name=$part.Substring(0,$p).Trim().Trim('"').Trim("'");if($name -and -not $names.Contains($name)){$names.Add($name)}}
  }
  return ($names -join ',')
}
function SafeMessage([string]$v){
  if([string]::IsNullOrWhiteSpace($v)){return ''}
  $v=($v -replace '[\r\n]+',' ').Trim()
  if($v.Length -gt 300){$v=$v.Substring(0,300)}
  return $v
}
function NormalizeSql([string]$v){
  if([string]::IsNullOrWhiteSpace($v)){return ''}
  $v=$v.Trim()
  if($v -match '(?is)^\s*BAP_SUPPORT_CONNECTION_STRING\s*=\s*(.+)$'){$v=$Matches[1].Trim()}
  if($v -match '(?is)^\s*ConnectionString\s*=\s*(.+)$'){$v=$Matches[1].Trim()}
  if($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[$v.Length-1] -eq '"') -or ($v[0] -eq "'" -and $v[$v.Length-1] -eq "'"))){$v=$v.Substring(1,$v.Length-2).Trim()}
  $v=[regex]::Replace($v,'(?i)\bConnectTimeout\s*=','Connect Timeout=')
  $v=[regex]::Replace($v,'(?i)\bConnectionTimeout\s*=','Connection Timeout=')
  $v=[regex]::Replace($v,'(?i)(^|;)\s*Timeout\s*=','$1Connect Timeout=')
  return $v.Trim()
}
function Classify([Exception]$ex){
  if($ex -is [System.Data.SqlClient.SqlException]){
    switch($ex.Number){
      -2 {return 'CONNECT_TIMEOUT'}
      18456 {return 'AUTHENTICATION_FAILED'}
      4060 {return 'DATABASE_ACCESS_FAILED'}
      53 {return 'NETWORK_OR_DNS'}
      10060 {return 'NETWORK_TIMEOUT'}
      11001 {return 'DNS_LOOKUP_FAILED'}
      default {return ('SQL_ERROR_'+$ex.Number)}
    }
  }
  if($ex -is [ArgumentException]){return 'CONNECTION_STRING_FORMAT'}
  return $ex.GetType().Name.ToUpperInvariant()
}
try{
  Add-Type -AssemblyName System.Data
  $raw=[Environment]::GetEnvironmentVariable('BAP_SUPPORT_CONNECTION_STRING')
  OutSafe 'SQL_RUNTIME_SETTING_PRESENT' (-not [string]::IsNullOrWhiteSpace($raw))
  OutSafe 'SQL_RUNTIME_RAW_KEY_NAMES' (GetKeyNames $raw)
  $cs=NormalizeSql $raw
  OutSafe 'SQL_RUNTIME_NORMALIZED_KEY_NAMES' (GetKeyNames $cs)
  $builder=New-Object System.Data.SqlClient.SqlConnectionStringBuilder $cs
  $builder['Connect Timeout']=10
  $hostName=([string]$builder.DataSource).Trim().ToLowerInvariant()
  if($hostName.StartsWith('tcp:')){$hostName=$hostName.Substring(4)}
  if($hostName.Contains(',')){$hostName=$hostName.Split(',')[0]}
  OutSafe 'SQL_SERVER_KIND' ($(if($hostName.EndsWith('.database.windows.net')){'AZURE_SQL'}else{'SQL_SERVER'}))
  OutSafe 'SQL_DATABASE_PRESENT' (-not [string]::IsNullOrWhiteSpace([string]$builder.InitialCatalog))
  $sw=[Diagnostics.Stopwatch]::StartNew()
  $connection=New-Object System.Data.SqlClient.SqlConnection $builder.ConnectionString
  $connection.Open()
  $command=$connection.CreateCommand();$command.CommandTimeout=10;$command.CommandText='SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES'
  $tables=$command.ExecuteScalar();$connection.Close();$sw.Stop()
  OutSafe 'SQL_OK' 'true';OutSafe 'SQL_TABLE_COUNT' $tables;OutSafe 'SQL_MS' $sw.ElapsedMilliseconds;OutSafe 'SQL_ERROR_CLASSIFICATION' 'OK';OutSafe 'SQL_ERROR_NUMBER' '';OutSafe 'SQL_ERROR_MESSAGE' ''
}catch{
  $e=$_.Exception
  OutSafe 'SQL_OK' 'false';OutSafe 'SQL_ERROR_TYPE' $e.GetType().Name;OutSafe 'SQL_ERROR_CLASSIFICATION' (Classify $e);OutSafe 'SQL_ERROR_MESSAGE' (SafeMessage $e.Message)
  if($e -is [System.Data.SqlClient.SqlException]){OutSafe 'SQL_ERROR_NUMBER' $e.Number}else{OutSafe 'SQL_ERROR_NUMBER' ''}
}
