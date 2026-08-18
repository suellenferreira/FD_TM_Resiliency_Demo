. "$PSScriptRoot/common.ps1"
Import-DemoConfig
$outputs = Get-DemoOutputs

if ($outputs.ContainsKey('TM_APP_FQDN')) {
  Write-Host "TM_APP_FQDN DNS result:"
  $appDnsResult = Resolve-DnsName $outputs.TM_APP_FQDN
  $appDnsResult | Format-Table -AutoSize
  Write-Host "Traffic Manager selected the App Service origin above. The generated trafficmanager.net hostname is not bound to this multi-tenant App Service, so a direct HTTP request intentionally returns 404 without a custom domain."
  Write-Host 'Verify the selected App Service workload through its native hostname:'
  $selectedAppHost = ($appDnsResult | Where-Object { $_.Type -eq 'CNAME' } | Select-Object -First 1).NameHost
  Invoke-RestMethod "https://$selectedAppHost/" | ConvertTo-Json
}

if ($outputs.ContainsKey('TM_AKS_FQDN')) {
  Write-Host "TM_AKS_FQDN DNS result:"
  Resolve-DnsName $outputs.TM_AKS_FQDN -Type A | Format-Table -AutoSize
  Write-Host 'HTTP response:'
  Invoke-RestMethod "http://$($outputs.TM_AKS_FQDN)/" | ConvertTo-Json
}
