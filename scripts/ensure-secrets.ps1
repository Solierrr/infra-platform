<#
.SYNOPSIS
  Garante que scripts/secrets.local.ps1 existe e carrega ele na sessão atual.
  Se o arquivo ainda não existir, pede o Client ID/Secret da Machine Identity
  gke-sync do Infisical via terminal e cria o arquivo antes de carregar.

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
