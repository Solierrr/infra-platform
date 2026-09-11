<#
.SYNOPSIS
  Extrai secrets do Infisical para um arquivo .env local,
  a partir das pastas por categoria que o serviço informado consome.

.PARAMETER Service
  -s: Nome do serviço.

.PARAMETER Environment
  -e: Ambiente do Infisical.

.PARAMETER OutputPath
  -o: Caminho do .env gerado [Opcional].

.EXAMPLE
  ./scripts/extract-env.ps1 -s api-core -e local

.EXAMPLE
  ./scripts/extract-env.ps1 -s ai-assistant -e qa -o ../ai-assistant/.env

.EXAMPLE
  ./scripts/extract-env.ps1 -s api-auth -e prod -o .env.prod
#>

param(
    [Parameter(Mandatory = $true)]
    [Alias("s")]
    [string]$Service,

    [Parameter(Mandatory = $true)]
    [Alias("e")]
    [ValidateSet("local", "qa", "prod")]
    [string]$Environment,
  
    [Parameter(Mandatory = $false)]
    [Alias("o")]
    [string]$OutputPath = ".env"
)

$ErrorActionPreference = "Stop"
$InfisicalProjectId = "2296d19c-5f3b-41e1-afa3-fcde39966a71"

$ServiceFolderMap = @{
    "api-core"           = @("/database", "/redis", "/cloudinary", "/google", "/otel")
    "api-auth"           = @("/database", "/redis", "/auth", "/outbox")
    "api-messenger"      = @("/database", "/auth")
    "api-recommendation" = @("/database", "/recommendation")
    "api-mcp"            = @("/database", "/mcp")
    "ai-assistant"       = @("/database", "/redis", "/llm", "/agent-queue")
    "ai-validation"      = @("/llm")
    "web-app"            = @("/vite", "/service-urls")
    "google-registry"    = @("/google")
    "databricks-sync"    = @("/database", "/databricks")
}

if (-not $ServiceFolderMap.ContainsKey($Service)) {
    Write-Error "Servico '$Service' não mapeado em `$ServiceFolderMap (topo deste script). Adicione a lista de pastas do Infisical que ele consome antes de rodar."
    exit 1
}

if (-not (Get-Command infisical -ErrorAction SilentlyContinue)) {
    Write-Error "Infisical.CLI não configurado. Rode 'winget install infisical' e 'infisical login' antes de usar este script."
    exit 1
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Gerado por scripts/extract-env.ps1 - Service=$Service Environment=$Environment - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")

foreach ($folder in $ServiceFolderMap[$Service]) {
    Write-Host "Extraindo $folder (env=$Environment)..." -ForegroundColor Cyan
    $output = @(& infisical export --env=$Environment --path=$folder --format=dotenv --projectId=$InfisicalProjectId 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Falha ao extrair '$folder': $output"
        exit 1
    }
    $lines.Add("")
    $lines.Add("# --- $folder ---")
    if ($output.Count -eq 0) {
        Write-Host "  (nenhum secret encontrado em '$folder' para env=$Environment)" -ForegroundColor Yellow
    }
    $lines.AddRange([string[]]$output)
}

[System.IO.File]::WriteAllLines($OutputPath, $lines, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "OK: '$OutputPath' gerado com $($ServiceFolderMap[$Service].Count) pasta(s) do Infisical para '$Service' (env=$Environment)." -ForegroundColor Green
