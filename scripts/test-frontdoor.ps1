. "$PSScriptRoot/common.ps1"
Import-DemoConfig
$outputs = Get-DemoOutputs

foreach ($name in 'FD_APP_URL', 'FD_AKS_URL') {
  if ($outputs.ContainsKey($name)) {
    Write-Host "$name -> $($outputs[$name])"
    Invoke-RestMethod "$($outputs[$name])/" | ConvertTo-Json
  }
}
