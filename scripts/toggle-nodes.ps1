<#
.SYNOPSIS
  Aumenta ou reduz a escala do pool de nós do GKE alterando o `node_count` no `main.tf`
  e propaga essa alteração via git (branch, commit, PR, merge), de modo que
  o estado do Terraform nunca divirja do que está efetivamente aplicado.

.EXAMPLE
  ./scripts/toggle-nodes.ps1 -NodeCount 0

.EXAMPLE
  ./scripts/toggle-nodes.ps1 -NodeCount 2 -Apply
#>
param(
    [Parameter(Mandatory = $true)]
    [int]$NodeCount,

    [switch]$Apply
)

$ErrorActionPreference = "Stop"

if (git status --porcelain) {
    Write-Error "Working tree has uncommitted changes. Commit or stash them first."
    exit 1
}

git checkout main
git pull origin main

$action = if ($NodeCount -eq 0) { "pause" } else { "resume" }
$branch = "chore/scale-nodes-to-$NodeCount-$(Get-Date -Format 'yyyyMMddHHmmss')"
git checkout -b $branch

$mainTfPath = (Resolve-Path main.tf).Path
$content = (Get-Content $mainTfPath -Raw) -replace 'node_count = \d+', "node_count = $NodeCount"
[System.IO.File]::WriteAllText($mainTfPath, $content, (New-Object System.Text.UTF8Encoding($false)))

git add main.tf
git commit -m "chore: $action node pool (node_count = $NodeCount)"
git push -u origin $branch

$title = "`[AUTO]` chore: scale node pool to $NodeCount"
$body = @"
## Objetivo

$(if ($NodeCount -eq 0) { "Pausar o cluster entre sessoes de estudo - zera custo de node/disco sem derrubar o control plane nem o IP do Kong." } else { "Retomar o cluster para uma sessao de estudo." })

## Alteracoes

- ``node_count`` do node pool: ``$NodeCount``

## Recursos impactados

Cluster GKE ``solaria-gke`` - essa PR sozinha nao aplica nada na nuvem, precisa de ``terraform apply`` depois (feito automaticamente se o script rodou com ``-Apply``).

## Rollback

Rodar o script de novo com o valor anterior de ``node_count``.

## Como validar

``kubectl get nodes`` mostra $NodeCount node(s) depois do apply.

Closes #
"@

$prUrl = gh pr create --title $title --body $body
$prNumber = ($prUrl -split '/')[-1]
gh pr merge $prNumber --merge --admin

git checkout main
git pull origin main

if ($Apply) {
    terraform apply -auto-approve
}

Write-Host ""
Write-Host "PR: $prUrl" -ForegroundColor Cyan
if (-not $Apply) {
    Write-Host "Merged. Run 'terraform apply' to actually apply it." -ForegroundColor Yellow
}
