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
function FindSqlException([Exception]$ex){
  $current=$ex
  for($i=0;$i -lt 8 -and $null -ne $current;$i++){
    if($current -is [System.Data.SqlClient.SqlException]){return $current}
    $current=$current.InnerException
  }
  return $null
}
function Classify([Exception]$ex){
  $sqlEx=FindSqlException $ex
  if($null -ne $sqlEx){
    switch($sqlEx.Number){
      -2 {return 'CONNECT_TIMEOUT'}
      2 {return 'SERVER_NOT_FOUND'}
      26 {return 'INSTANCE_NOT_FOUND'}
      40 {return 'NETWORK_PATH_OR_INSTANCE'}
      53 {return 'NETWORK_OR_DNS'}
      258 {return 'WAIT_TIMEOUT'}
      10060 {return 'NETWORK_TIMEOUT'}
      11001 {return 'DNS_LOOKUP_FAILED'}
      18456 {return 'AUTHENTICATION_FAILED'}
      4060 {return 'DATABASE_ACCESS_FAILED'}
      default {return ('SQL_ERROR_'+$sqlEx.Number)}
    }
  }
  if($ex -is [ArgumentException]){return 'CONNECTION_STRING_FORMAT'}
  return $ex.GetType().Name.ToUpperInvariant()
}
function IsPrivateIp([System.Net.IPAddress]$ip){
  if($ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork){return $false}
  $b=$ip.GetAddressBytes()
  if($b[0] -eq 10){return $true}
  if($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31){return $true}
  if($b[0] -eq 192 -and $b[1] -eq 168){return $true}
  if($b[0] -eq 127){return $true}
  return $false
}
function SafeMessage([Exception]$ex,[string]$serverSpec){
  $target=$ex
  $sqlEx=FindSqlException $ex
  if($null -ne $sqlEx){$target=$sqlEx}
  $v=[string]$target.Message
  if(-not [string]::IsNullOrWhiteSpace($serverSpec)){$v=$v.Replace($serverSpec,'[SQL_SERVER]')}
  $v=($v -replace '[\r\n]+',' ').Trim()
  if($v.Length -gt 400){$v=$v.Substring(0,400)}
  return $v
}
function TestTcp([string]$hostName,[int]$port){
  $client=$null
  try{
    $client=New-Object System.Net.Sockets.TcpClient
    $ar=$client.BeginConnect($hostName,$port,$null,$null)
    if(-not $ar.AsyncWaitHandle.WaitOne(5000,$false)){return $false}
    $client.EndConnect($ar);return $client.Connected
  }catch{return $false}
  finally{if($null -ne $client){$client.Close()}}
}

$serverSpec=''
try{
  Add-Type -AssemblyName System.Data
  $raw=[Environment]::GetEnvironmentVariable('BAP_SUPPORT_CONNECTION_STRING')
  OutSafe 'SQL_RUNTIME_SETTING_PRESENT' (-not [string]::IsNullOrWhiteSpace($raw))
  OutSafe 'SQL_RUNTIME_RAW_KEY_NAMES' (GetKeyNames $raw)
  $cs=NormalizeSql $raw
  OutSafe 'SQL_RUNTIME_NORMALIZED_KEY_NAMES' (GetKeyNames $cs)
  $builder=New-Object System.Data.SqlClient.SqlConnectionStringBuilder $cs
  $builder['Connect Timeout']=10

  $serverSpec=([string]$builder.DataSource).Trim()
  $spec=$serverSpec
  $protocol='AUTO'
  if($spec.StartsWith('tcp:',[StringComparison]::OrdinalIgnoreCase)){$protocol='TCP';$spec=$spec.Substring(4)}
  elseif($spec.StartsWith('np:',[StringComparison]::OrdinalIgnoreCase)){$protocol='NAMED_PIPE';$spec=$spec.Substring(3)}
  OutSafe 'SQL_DATASOURCE_PROTOCOL' $protocol

  $hasInstance=$spec.Contains('\')
  OutSafe 'SQL_NAMED_INSTANCE' $hasInstance.ToString().ToLowerInvariant()
  $hostPart=$spec
  $instanceName=''
  if($hasInstance){$pieces=$spec.Split('\',2);$hostPart=$pieces[0];$instanceName=$pieces[1]}
  $explicitPort=0
  if($hostPart.Contains(',')){
    $hp=$hostPart.Split(',',2);$hostPart=$hp[0];[int]::TryParse($hp[1],[ref]$explicitPort)|Out-Null
  }elseif((-not $hasInstance) -and $spec.Contains(',')){
    $hp=$spec.Split(',',2);$hostPart=$hp[0];[int]::TryParse($hp[1],[ref]$explicitPort)|Out-Null
  }
  $hostPart=$hostPart.Trim()
  OutSafe 'SQL_SERVER_HOST' $hostPart
  if($hasInstance){OutSafe 'SQL_INSTANCE_NAME' $instanceName}else{OutSafe 'SQL_INSTANCE_NAME' ''}
  OutSafe 'SQL_EXPLICIT_PORT' ($(if($explicitPort -gt 0){$explicitPort}else{''}))

  $hostLower=$hostPart.ToLowerInvariant()
  OutSafe 'SQL_SERVER_KIND' ($(if($hostLower.EndsWith('.database.windows.net')){'AZURE_SQL'}else{'SQL_SERVER'}))
  OutSafe 'SQL_DATABASE_PRESENT' (-not [string]::IsNullOrWhiteSpace([string]$builder.InitialCatalog))

  $ipObj=$null
  $isLiteral=[System.Net.IPAddress]::TryParse($hostPart,[ref]$ipObj)
  if($isLiteral){OutSafe 'SQL_SERVER_ADDRESS_TYPE' ($(if(IsPrivateIp $ipObj){'PRIVATE_IP'}else{'PUBLIC_IP'}))}
  else{OutSafe 'SQL_SERVER_ADDRESS_TYPE' 'HOSTNAME'}

  $dnsOk=$false;$resolved=@();$dnsError=''
  try{$resolved=@([System.Net.Dns]::GetHostAddresses($hostPart));$dnsOk=$resolved.Count -gt 0}catch{$dnsError=$_.Exception.GetType().Name}
  OutSafe 'SQL_DNS_OK' $dnsOk.ToString().ToLowerInvariant()
  OutSafe 'SQL_DNS_ERROR_TYPE' $dnsError
  if($dnsOk){
    $safeIps=@($resolved | ForEach-Object {$_.IPAddressToString} | Select-Object -Unique)
    OutSafe 'SQL_RESOLVED_IPS' ($safeIps -join ',')
  }
  if($dnsOk -and -not $isLiteral){
    $hasPrivate=$false;foreach($addr in $resolved){if(IsPrivateIp $addr){$hasPrivate=$true;break}}
    OutSafe 'SQL_DNS_SCOPE' ($(if($hasPrivate){'PRIVATE_OR_MIXED'}else{'PUBLIC'}))
  }

  $testPort=$explicitPort
  if($testPort -le 0 -and -not $hasInstance){$testPort=1433}
  if($testPort -gt 0){OutSafe 'SQL_TCP_TEST_PORT' $testPort;OutSafe 'SQL_TCP_OK' (TestTcp $hostPart $testPort).ToString().ToLowerInvariant()}
  else{OutSafe 'SQL_TCP_TEST_PORT' '';OutSafe 'SQL_TCP_OK' 'not_tested_named_instance_dynamic_port'}

  $sw=[Diagnostics.Stopwatch]::StartNew()
  $connection=New-Object System.Data.SqlClient.SqlConnection $builder.ConnectionString
  $connection.Open()
  $command=$connection.CreateCommand();$command.CommandTimeout=10;$command.CommandText='SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES'
  $tables=$command.ExecuteScalar();$connection.Close();$sw.Stop()
  OutSafe 'SQL_OK' 'true';OutSafe 'SQL_TABLE_COUNT' $tables;OutSafe 'SQL_MS' $sw.ElapsedMilliseconds;OutSafe 'SQL_ERROR_CLASSIFICATION' 'OK';OutSafe 'SQL_ERROR_NUMBER' '';OutSafe 'SQL_ERROR_MESSAGE' ''
}catch{
  $e=$_.Exception;$sqlEx=FindSqlException $e
  OutSafe 'SQL_OK' 'false';OutSafe 'SQL_ERROR_TYPE' $e.GetType().Name;OutSafe 'SQL_ERROR_CLASSIFICATION' (Classify $e);OutSafe 'SQL_ERROR_MESSAGE' (SafeMessage $e $serverSpec)
  if($null -ne $sqlEx){OutSafe 'SQL_ERROR_NUMBER' $sqlEx.Number}else{OutSafe 'SQL_ERROR_NUMBER' ''}
}
