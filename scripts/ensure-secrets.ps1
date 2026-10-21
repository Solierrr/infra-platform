$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:INFISICAL_CLIENT_ID) -or [string]::IsNullOrWhiteSpace($env:INFISICAL_CLIENT_SECRET)) {
    throw "Credenciais ausentes. Rode 'make login' e confirme INFISICAL_CLIENT_ID e INFISICAL_CLIENT_SECRET em /infisical (prod)."
}

$env:TF_VAR_infisical_client_id = $env:INFISICAL_CLIENT_ID
$env:TF_VAR_infisical_client_secret = $env:INFISICAL_CLIENT_SECRET
Remove-Item Env:INFISICAL_CLIENT_ID
Remove-Item Env:INFISICAL_CLIENT_SECRET

try {
    $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5).Trim()
    $env:TF_VAR_authorized_ip_cidr = "$publicIp/32"
    Write-Host "IP publico detectado: $publicIp/32 (autorizado no control plane do GKE)." -ForegroundColor Cyan
} catch {
    Write-Host "Nao foi possivel detectar o IP publico automaticamente - usando o default de variables.tf, que pode estar desatualizado." -ForegroundColor Yellow
}
