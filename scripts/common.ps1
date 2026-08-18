function Import-DemoConfig {
  $configPath = Join-Path $PSScriptRoot '..\config\demo.env'
  if (-not (Test-Path $configPath)) {
    throw "Configuration not found: $configPath. Copy config/demo.env.example to config/demo.env first."
  }

  foreach ($line in Get-Content $configPath) {
    if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split '=', 2
    if ($parts.Count -eq 2) {
      Set-Item -Path "Env:$($parts[0].Trim())" -Value $parts[1].Trim()
    }
  }

  foreach ($name in 'AZURE_TENANT_ID', 'AZURE_SUBSCRIPTION_ID', 'AZURE_RESOURCE_GROUP', 'AZURE_LOCATION_PRIMARY', 'AZURE_LOCATION_SECONDARY', 'DEMO_PREFIX', 'DEMO_APP_NAME', 'DEPLOY_AKS') {
    if ([string]::IsNullOrWhiteSpace((Get-Item "Env:$name" -ErrorAction SilentlyContinue).Value) -or (Get-Item "Env:$name" -ErrorAction SilentlyContinue).Value -match '^<.+>$') {
      throw "Set $name in config/demo.env."
    }
  }

  if ($env:DEMO_PREFIX -cne $env:DEMO_PREFIX.ToLowerInvariant() -or $env:DEMO_PREFIX -notmatch '^[a-z0-9-]{3,10}$') {
    throw 'DEMO_PREFIX must be 3-10 characters, lowercase, and contain only letters, numbers, or hyphens.'
  }
  if ($env:DEMO_APP_NAME -notmatch '^[a-z0-9-]{1,40}$') {
    throw 'DEMO_APP_NAME must contain only lowercase letters, numbers, or hyphens.'
  }
  if ($env:DEPLOY_AKS.ToLowerInvariant() -notin 'true', 'false') {
    throw 'DEPLOY_AKS must be true or false.'
  }
}

function Assert-AzureContext {
  $context = az account show --query '{tenantId:tenantId,subscriptionId:id}' -o json | ConvertFrom-Json
  Assert-LastExitCode 'Reading Azure context'
  if ($context.tenantId -ne $env:AZURE_TENANT_ID) {
    throw "Authenticated tenant '$($context.tenantId)' does not match AZURE_TENANT_ID."
  }
  if ($context.subscriptionId -ne $env:AZURE_SUBSCRIPTION_ID) {
    throw "Selected subscription '$($context.subscriptionId)' does not match AZURE_SUBSCRIPTION_ID."
  }
}

function Get-DemoName {
  param([Parameter(Mandatory)][string]$Workload, [Parameter(Mandatory)][string]$Region)
  $prefix = $env:DEMO_PREFIX.ToLower() -replace '-', ''
  if ($Workload -eq 'app') { return "app-$prefix-$Region" }
  if ($Workload -eq 'aks') { return "aks-$prefix-$Region" }
  throw "Unsupported workload: $Workload"
}

function Get-DemoWorkloadName {
  return $env:DEMO_APP_NAME.ToLower()
}

function Get-DemoOutputs {
  $path = Join-Path $PSScriptRoot '..\outputs\demo-endpoints.env'
  if (-not (Test-Path $path)) { throw 'Deployment outputs were not found. Run scripts/deploy.ps1 first.' }
  $result = @{}
  foreach ($line in Get-Content $path) {
    $parts = $line -split '=', 2
    if ($parts.Count -eq 2) { $result[$parts[0]] = $parts[1] }
  }
  return $result
}

function Assert-LastExitCode {
  param([Parameter(Mandatory)][string]$Operation)

  if ($LASTEXITCODE -ne 0) {
    throw "$Operation failed with exit code $LASTEXITCODE."
  }
}
