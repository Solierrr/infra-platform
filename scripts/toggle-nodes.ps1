<#
.SYNOPSIS
  Scales the GKE node pool up or down by changing node_count in main.tf,
  and pushes that change through git (branch, commit, PR, merge) so
  Terraform's state never drifts from what's actually applied.

.EXAMPLE
  ./scripts/toggle-nodes.ps1 -NodeCount 0
  Opens and merges a PR pausing the node pool. Run `terraform apply`
  yourself afterwards - this script never touches the cloud directly.

.EXAMPLE
  ./scripts/toggle-nodes.ps1 -NodeCount 2 -Apply
  Same, but also runs `terraform apply -auto-approve` at the end.
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

(Get-Content main.tf) -replace '  node_count = \d+', "  node_count = $NodeCount" |
    Set-Content main.tf -Encoding utf8NoBOM

git add main.tf
git commit -m "chore: $action node pool (node_count = $NodeCount)"
git push -u origin $branch

$prUrl = gh pr create `
    --title "chore: scale node pool to $NodeCount" `
    --body "Ajuste de node_count para $action o cluster entre sessoes de estudo. Sem mudanca de infra alem da contagem de nodes."
Write-Host "PR: $prUrl"

$prNumber = ($prUrl -split '/')[-1]
gh pr merge $prNumber --merge --admin

git checkout main
git pull origin main

if ($Apply) {
    terraform apply -auto-approve
} else {
    Write-Host ""
    Write-Host "Merged. Run 'terraform apply' to actually apply it." -ForegroundColor Yellow
}
