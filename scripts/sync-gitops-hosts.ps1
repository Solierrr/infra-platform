<#
.SYNOPSIS
  Atualiza os hosts *.sslip.io dos Ingress em infra-gitops/services/*/
  para o IP atual do Kong (google_compute_address.kong_ip) e abre uma PR
  com a mudança. sslip.io resolve o host pro IP embutido no próprio nome
  (ex: api-core.1.2.3.4.sslip.io -> 1.2.3.4), então esses hosts ficam
  quebrados toda vez que o cluster é recriado e o Kong recebe um IP novo -
  diferente do web-app, que usa o domínio real via wildcard do Cloudflare
  (já atualizado automaticamente pelo próprio Terraform). A PR não é
  mergeada automaticamente - revise e mergeie manualmente.

.EXAMPLE
  ./scripts/sync-gitops-hosts.ps1
#>
$ErrorActionPreference = "Stop"

$kongIp = terraform output -raw kong_ip
if ([string]::IsNullOrWhiteSpace($kongIp)) {
    throw "Nao foi possivel ler o output kong_ip do Terraform - rode terraform apply antes."
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "infra-gitops-sync-$(Get-Date -Format 'yyyyMMddHHmmss')"

try {
    git clone --depth 1 https://github.com/Solierrr/infra-gitops.git $tempDir
    Push-Location $tempDir

    $ingressFiles = Get-ChildItem -Path "services" -Filter "ingress.yaml" -Recurse
    $changed = $false

    foreach ($file in $ingressFiles) {
        $content = Get-Content $file.FullName -Raw
        $updated = $content -replace '(host:\s*[\w-]+\.)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(\.sslip\.io)', "`${1}$kongIp`$2"

        if ($updated -ne $content) {
            [System.IO.File]::WriteAllText($file.FullName, $updated, (New-Object System.Text.UTF8Encoding($false)))
            $changed = $true
        }
    }

    if (-not $changed) {
        Write-Host "Hosts sslip.io ja apontam para $kongIp - nada pra atualizar." -ForegroundColor Yellow
    } else {
        $branch = "chore/sync-kong-ip-$(Get-Date -Format 'yyyyMMddHHmmss')"
        git checkout -b $branch
        git add services
        git commit -m "chore: sync sslip.io hosts to current kong ip"
        git push -u origin $branch

        $title = "chore: sync sslip.io hosts to current kong ip"
        $body = "Atualiza os hosts sslip.io dos serviços internos pro IP atual do Kong ($kongIp) - gerado automaticamente depois do cluster solaria-gke subir. Revisar e mergear manualmente."
        $prUrl = gh pr create --title $title --body $body

        Write-Host "PR aberta, revise e mergeie manualmente: $prUrl" -ForegroundColor Green
    }
} finally {
    Pop-Location -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
}
