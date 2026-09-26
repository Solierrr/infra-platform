<#
.SYNOPSIS
  Garante que scripts/secrets.local.ps1 existe e carrega ele na sessão atual.
  Se o arquivo ainda não existir, pede o Client ID/Secret da Machine Identity
  gke-sync do Infisical via terminal e cria o arquivo antes de carregar.
  Também detecta o IP público atual da máquina e define
  TF_VAR_authorized_ip_cidr com ele, já que o control plane do GKE só aceita
  conexões do IP autorizado no momento do apply (muda a cada rede/máquina).

.EXAMPLE
  . ./scripts/ensure-secrets.ps1
#>
$ErrorActionPreference = "Stop"

$secretsPath = Join-Path $PSScriptRoot "secrets.local.ps1"

if (-not (Test-Path $secretsPath)) {
    Write-Host "scripts/secrets.local.ps1 nao encontrado - preencha a Machine Identity gke-sync (dashboard do Infisical -> Project Settings -> Identities -> gke-sync)." -ForegroundColor Yellow

    $clientId = Read-Host "Client ID"
    $clientSecretSecure = Read-Host "Client Secret" -AsSecureString
    $clientSecret = [System.Net.NetworkCredential]::new("", $clientSecretSecure).Password

    if ([string]::IsNullOrWhiteSpace($clientId) -or [string]::IsNullOrWhiteSpace($clientSecret)) {
        throw "Client ID/Secret nao podem ficar em branco."
    }

    $escapedClientId = $clientId -replace "'", "''"
    $escapedClientSecret = $clientSecret -replace "'", "''"

    $content = @"
`$env:TF_VAR_infisical_client_id = '$escapedClientId'
`$env:TF_VAR_infisical_client_secret = '$escapedClientSecret'
"@

    [System.IO.File]::WriteAllText($secretsPath, $content + "`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "scripts/secrets.local.ps1 criado. Para trocar as credenciais depois, apague o arquivo e rode de novo." -ForegroundColor Green
}

. $secretsPath

try {
    $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5).Trim()
    $env:TF_VAR_authorized_ip_cidr = "$publicIp/32"
    Write-Host "IP publico detectado: $publicIp/32 (autorizado no control plane do GKE)." -ForegroundColor Cyan
} catch {
    Write-Host "Nao foi possivel detectar o IP publico automaticamente - usando o default de variables.tf, que pode estar desatualizado." -ForegroundColor Yellow
}
