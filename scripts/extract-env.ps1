<#
.SYNOPSIS
  Extrai secrets do Infisical (projeto Solaria) para um arquivo .env local,
  a partir das pastas por categoria que o serviço informado consome.

.DESCRIPTION
  Implementa a etapa de "Bootstrap local" descrita em
  docs-warehouse/architecture/2026-09-03-secrets-and-envs-design.md: em vez
  de copiar scripts/secrets.template.ps1 e preencher valores na mão, este
  script chama `infisical export` uma vez por pasta relevante (as secrets
  são organizadas por categoria/tecnologia no Infisical - ex: /database,
  /redis - não por serviço, porque várias credenciais são compartilhadas
  entre serviços) e concatena tudo num único .env.

.PARAMETER Service
  Nome do serviço (ex: api-core, api-auth, ai-assistant). Usado só pra
  escolher quais pastas do Infisical puxar - ver $ServiceFolderMap logo
  abaixo, que precisa ficar em sincronia com infra-platform/secrets.tf
  (a mesma combinação pasta->serviço usada lá pro ambiente prod).

.PARAMETER Environment
  Ambiente a extrair. Os slugs reais no Infisical são local/qa/prod
  (NÃO "dev" - apesar do nome do arquivo docs-warehouse/templates/infisical/
  infisical.env.example.dev, o slug confirmado é "local").

.PARAMETER OutputPath
  Caminho do .env gerado. Default: ".env" na pasta atual (rode o script
  de dentro do repo do serviço, ou passe um caminho explícito).

.EXAMPLE
  ./scripts/extract-env.ps1 -Service api-core -Environment local

.EXAMPLE
  ./scripts/extract-env.ps1 -Service ai-assistant -Environment qa -OutputPath ../ai-assistant/.env
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Service,

    [Parameter(Mandatory = $true)]
    [ValidateSet("local", "qa", "prod")]
    [string]$Environment,

    [string]$OutputPath = ".env"
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Mapa serviço -> pastas do Infisical que ele consome. Espelha exatamente
# os `data "infisical_secrets"` referenciados por cada `kubernetes_secret`
# em infra-platform/secrets.tf (fonte de verdade pra prod) - qualquer
# serviço novo, ou pasta nova consumida por um serviço existente, precisa
# ser adicionado aqui e lá ao mesmo tempo.
#
# web-app é caso especial: não tem kubernetes_secret em secrets.tf (as
# VITE_* são embutidas no build, não lidas em runtime), mas ainda precisa
# de .env local pra rodar `npm run dev`, por isso está mapeado aqui mesmo
# sem estar em secrets.tf.
# ---------------------------------------------------------------------------
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
    Write-Error "Servico '$Service' nao mapeado em `$ServiceFolderMap (topo deste script). Adicione a lista de pastas do Infisical que ele consome antes de rodar."
    exit 1
}

# ---------------------------------------------------------------------------
# Pre-checagem: Infisical CLI precisa estar instalado e logado. `infisical
# login` e feito uma vez por dev (fica salvo localmente, não é por sessao
# de terminal) - ver decisão de auth no design doc (Machine Identity é só
# pra CI/Render/GKE, dev usa login pessoal).
# ---------------------------------------------------------------------------
if (-not (Get-Command infisical -ErrorAction SilentlyContinue)) {
    Write-Error "Infisical CLI nao encontrado no PATH. Instale em https://infisical.com/docs/cli/overview e rode 'infisical login' antes de usar este script."
    exit 1
}

# ---------------------------------------------------------------------------
# Extracao: uma chamada `infisical export` por pasta mapeada, no formato
# dotenv, concatenando a saida num unico arquivo. Se duas pastas tiverem a
# mesma chave (nao deveria acontecer - cada pasta cobre um dominio
# distinto), a ultima pasta da lista vence.
# ---------------------------------------------------------------------------
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Gerado por scripts/extract-env.ps1 - Service=$Service Environment=$Environment - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")

foreach ($folder in $ServiceFolderMap[$Service]) {
    Write-Host "Extraindo $folder (env=$Environment)..." -ForegroundColor Cyan
    $output = & infisical export --env=$Environment --path=$folder --format=dotenv 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Falha ao extrair '$folder': $output"
        exit 1
    }
    $lines.Add("")
    $lines.Add("# --- $folder ---")
    $lines.AddRange([string[]]$output)
}

# ---------------------------------------------------------------------------
# Escreve o .env final em UTF-8 sem BOM (mesmo padrao de encoding usado no
# resto da org - ver toggle-nodes.ps1).
# ---------------------------------------------------------------------------
[System.IO.File]::WriteAllLines($OutputPath, $lines, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "OK: '$OutputPath' gerado com $($ServiceFolderMap[$Service].Count) pasta(s) do Infisical para '$Service' (env=$Environment)." -ForegroundColor Green
