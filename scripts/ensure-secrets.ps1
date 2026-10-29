<#
.SYNOPSIS
  Carrega as credenciais da Machine Identity do Infisical na sessão atual, nesta ordem:
  1. TF_VAR_infisical_client_id/secret já definidos no ambiente;
  2. .env na raiz do repo, gerado por `make cluster-env` a partir da pasta /infisical
     do Infisical prod (INFISICAL_CLIENT_ID e INFISICAL_CLIENT_SECRET);
  3. scripts/secrets.local.ps1;
  4. pergunta o Client ID/Secret no terminal e cria o scripts/secrets.local.ps1.
  Também detecta o IP público atual da máquina e define
  TF_VAR_authorized_ip_cidr com ele, já que o control plane do GKE só aceita
  conexões do IP autorizado no momento do apply (muda a cada rede/máquina).

.EXAMPLE
  . ./scripts/ensure-secrets.ps1
#>
$ErrorActionPreference = "Stop"

$secretsPath = Join-Path $PSScriptRoot "secrets.local.ps1"
$envPath = Join-Path (Split-Path $PSScriptRoot -Parent) ".env"

function Import-DotEnv([string]$Path) {
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            $value = $Matches[2].Trim()
            if ($value.Length -ge 2 -and (($value.StartsWith("'") -and $value.EndsWith("'")) -or ($value.StartsWith('"') -and $value.EndsWith('"')))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            [Environment]::SetEnvironmentVariable($Matches[1], $value, "Process")
        }
    }
}

$hasTerraformCredentials = $env:TF_VAR_infisical_client_id -and $env:TF_VAR_infisical_client_secret

if (-not $hasTerraformCredentials -and (Test-Path -LiteralPath $envPath)) {
    Import-DotEnv $envPath
    if ($env:INFISICAL_CLIENT_ID -and $env:INFISICAL_CLIENT_SECRET) {
        $env:TF_VAR_infisical_client_id = $env:INFISICAL_CLIENT_ID
        $env:TF_VAR_infisical_client_secret = $env:INFISICAL_CLIENT_SECRET
        $hasTerraformCredentials = $true
        Write-Host "Credenciais do Infisical carregadas do .env (geradas por make cluster-env)." -ForegroundColor Cyan
    }
}

if (-not $hasTerraformCredentials -and -not (Test-Path $secretsPath)) {
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

if (-not $hasTerraformCredentials) {
    . $secretsPath
}

try {
    $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5).Trim()
    $env:TF_VAR_authorized_ip_cidr = "$publicIp/32"
    Write-Host "IP publico detectado: $publicIp/32 (autorizado no control plane do GKE)." -ForegroundColor Cyan
} catch {
    Write-Host "Nao foi possivel detectar o IP publico automaticamente - usando o default de variables.tf, que pode estar desatualizado." -ForegroundColor Yellow
}
