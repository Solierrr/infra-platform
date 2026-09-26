<#
.SYNOPSIS
  Marca em ephemerality.json se o cluster solaria-gke está ativo ou não,
  propaga isso via git (branch, commit, PR, merge) e dispara o workflow
  de verificação de ambiente (workflow_dispatch) nos repos de aplicação,
  pra Production parar de reportar falha quando o cluster está desligado
  de propósito.

.EXAMPLE
  ./scripts/set-cluster-state.ps1 -Active $true

.EXAMPLE
  ./scripts/set-cluster-state.ps1 -Active $false
#>
param(
    [Parameter(Mandatory = $true)]
    [bool]$Active
)

$ErrorActionPreference = "Stop"

if (git status --porcelain) {
    Write-Error "Working tree has uncommitted changes. Commit or stash them first."
    exit 1
}

git checkout main
git pull origin main

$stateValue = if ($Active) { "true" } else { "false" }
$currentContent = Get-Content ephemerality.json -Raw

if ($currentContent -match '"active"\s*:\s*(true|false)' -and $matches[1] -eq $stateValue) {
    Write-Host "ephemerality.json já está em active: $stateValue - nada pra commitar." -ForegroundColor Yellow
} else {
    $branch = "chore/cluster-$stateValue-$(Get-Date -Format 'yyyyMMddHHmmss')"
    git checkout -b $branch

    $json = "{`n  `"active`": $stateValue`n}`n"
    [System.IO.File]::WriteAllText((Resolve-Path ephemerality.json).Path, $json, (New-Object System.Text.UTF8Encoding($false)))

    git add ephemerality.json
    git commit -m "chore: mark cluster as $stateValue"
    git push -u origin $branch

    $title = "chore: mark cluster as $stateValue"
    $body = @"
## Objetivo

Refletir em ephemerality.json que o cluster solaria-gke está $(if ($Active) { "ativo" } else { "inativo" }) agora, pro check de Production dos repos de aplicação parar de reportar falha quando o cluster está desligado de propósito.

## Alterações

- ``ephemerality.json``: ``active: $stateValue``

Closes #
"@

    $prUrl = gh pr create --title $title --body $body
    $prNumber = ($prUrl -split '/')[-1]
    gh pr merge $prNumber --squash --admin

    git checkout main
    git pull origin main
}

& "$PSScriptRoot/trigger-environment-checks.ps1"
