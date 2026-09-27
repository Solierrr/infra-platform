<#
.SYNOPSIS
  Atualiza os hosts *.sslip.io dos Ingress em infra-gitops/services/*/
  para o IP atual do Kong (google_compute_address.kong_ip), abre a PR e
  mergeia automaticamente com bypass de admin. sslip.io resolve o host pro
  IP embutido no próprio nome (ex: api-core.1.2.3.4.sslip.io -> 1.2.3.4),
  então esses hosts ficam quebrados toda vez que o cluster é recriado e o
  Kong recebe um IP novo - diferente do web-app, que usa o domínio real via
  wildcard do Cloudflare (já atualizado automaticamente pelo próprio
  Terraform). Merge automático de propósito: essa PR é puramente mecânica
  (regex sobre um IP), sem risco de conteúdo, e sem ela os serviços
  internos ficam inacessíveis até alguém mergear manualmente.

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
    # sem --depth 1: gh pr create precisa do historico completo pra
    # resolver a relacao com a main, senao falha com "you must first push
    # the current branch to a remote" mesmo depois de um push bem-sucedido.
    git clone https://github.com/Solierrr/infra-gitops.git $tempDir
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
        if ($LASTEXITCODE -ne 0) { throw "git push falhou (exit $LASTEXITCODE)" }

        $title = "chore: sync sslip.io hosts to current kong ip"
        $body = "Atualiza os hosts sslip.io dos serviços internos pro IP atual do Kong ($kongIp) - gerado e mergeado automaticamente depois do cluster solaria-gke subir."
        $prUrl = gh pr create --title $title --body $body
        if ($LASTEXITCODE -ne 0) { throw "gh pr create falhou (exit $LASTEXITCODE): $prUrl" }

        $prNumber = ($prUrl -split '/')[-1]
        gh pr merge $prNumber --squash --admin
        if ($LASTEXITCODE -ne 0) { throw "gh pr merge falhou (exit $LASTEXITCODE) para $prUrl" }

        Write-Host "Hosts sslip.io atualizados para $kongIp e mergeados: $prUrl" -ForegroundColor Green
    }
} finally {
    Pop-Location -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
}
