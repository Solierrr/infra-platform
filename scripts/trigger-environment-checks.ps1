<#
.SYNOPSIS
  Dispara o workflow environment-status.yml (workflow_dispatch) nos repos
  de aplicação, sem mexer em ephemerality.json. Útil pra reconferir o
  status de QA/Production sem uma mudança real de estado do cluster
  (ex.: depois de mergear um fix no workflow reutilizável central).

.EXAMPLE
  ./scripts/trigger-environment-checks.ps1
#>
$ErrorActionPreference = "Stop"

$repos = @(
    "api-auth", "api-core", "api-messenger", "api-recommendation",
    "mcp-database", "ai-assistant", "ai-validation", "ai-accessibility", "web-app"
)

foreach ($repo in $repos) {
    Write-Host "Disparando environment-status em $repo..." -ForegroundColor Cyan
    gh workflow run environment-status.yml --repo "Solierrr/$repo" --ref main
}
