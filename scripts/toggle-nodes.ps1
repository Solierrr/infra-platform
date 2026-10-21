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

    [switch]$Apply,

    [string]$InfisicalEnvironment = "prod",

    [string]$InfisicalPath = "/infisical",

    [string]$InfisicalProjectId = "2296d19c-5f3b-41e1-afa3-fcde39966a71"
)

$ErrorActionPreference = "Stop"

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [switch]$CaptureOutput
    )

    $output = & $Command @Arguments 2>&1

    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "$Command $($Arguments -join ' ') falhou com codigo $exitCode."
    }

    if ($CaptureOutput) {
        return (($output -join [Environment]::NewLine).Trim())
    }

    return $output
}

$workingTree = Invoke-NativeCommand -Command "git" -Arguments @("status", "--porcelain") -CaptureOutput
if (-not [string]::IsNullOrWhiteSpace($workingTree)) {
    throw "Working tree has uncommitted changes. Commit or stash them first."
}

Invoke-NativeCommand -Command "git" -Arguments @("checkout", "main")
Invoke-NativeCommand -Command "git" -Arguments @("pull", "origin", "main")

if ($Apply) {
    $infisical = Get-Command "infisical.exe" -ErrorAction Stop
}

$action = if ($NodeCount -eq 0) { "pause" } else { "resume" }
$branch = "chore/scale-nodes-to-$NodeCount-$(Get-Date -Format 'yyyyMMddHHmmss')"
Invoke-NativeCommand -Command "git" -Arguments @("checkout", "-b", $branch)

$mainTfPath = (Resolve-Path main.tf).Path
$content = (Get-Content $mainTfPath -Raw) -replace 'node_count = \d+', "node_count = $NodeCount"
[System.IO.File]::WriteAllText($mainTfPath, $content, (New-Object System.Text.UTF8Encoding($false)))

if ([string]::IsNullOrWhiteSpace((Invoke-NativeCommand -Command "git" -Arguments @("status", "--porcelain") -CaptureOutput))) {
    Write-Host "node_count já está em $NodeCount - nada pra commitar, sem PR." -ForegroundColor Yellow
    Invoke-NativeCommand -Command "git" -Arguments @("checkout", "main")
    Invoke-NativeCommand -Command "git" -Arguments @("branch", "-D", $branch)
    exit 0
}

$planFile = $null
try {
    if ($Apply) {
        # Terraform plan files can contain sensitive values. Keep this one in the OS temp directory
        # and remove it in finally after applying the exact plan that was checked below.
        $planFile = Join-Path ([System.IO.Path]::GetTempPath()) "infra-platform-toggle-$([guid]::NewGuid().ToString('N')).tfplan"
        $terraformScript = Join-Path $PSScriptRoot "terraform-toggle.ps1"
        $planArgs = @(
            "run",
            "--env=$InfisicalEnvironment",
            "--path=$InfisicalPath",
            "--projectId=$InfisicalProjectId",
            "--",
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $terraformScript,
            "-Mode",
            "Plan",
            "-NodeCount",
            "$NodeCount",
            "-PlanFile",
            $planFile
        )

        & $infisical.Source @planArgs
        if ($LASTEXITCODE -ne 0) {
            throw "O plano Terraform falhou ou inclui mudancas fora do node_count; nenhuma PR foi criada ou mesclada. A branch local '$branch' contem a alteracao pendente."
        }
    }

    Invoke-NativeCommand -Command "git" -Arguments @("add", "main.tf")
    Invoke-NativeCommand -Command "git" -Arguments @("commit", "-m", "chore: $action node pool (node_count = $NodeCount)")
    $branchCommit = Invoke-NativeCommand -Command "git" -Arguments @("rev-parse", "HEAD") -CaptureOutput
    Invoke-NativeCommand -Command "git" -Arguments @("push", "-u", "origin", $branch)

    $title = "`[AUTO]` chore: scale node pool to $NodeCount"
    $body = @"
## Objetivo

$(if ($NodeCount -eq 0) { "Pausar o cluster entre sessões de estudo - zera custo de node/disco sem derrubar o control plane nem o IP do Kong." } else { "Retomar o cluster para uma sessão de estudo." })

## Alterações

- ``node_count`` do node pool: ``$NodeCount``

## Recursos impactados

Cluster GKE ``solaria-gke`` - essa PR sozinha não aplica nada na nuvem, precisa de ``terraform apply`` depois (feito automaticamente se o script rodou com ``-Apply``).

## Rollback

Rodar o script de novo com o valor anterior de ``node_count``.

## Como validar

``kubectl get nodes`` mostra $NodeCount node(s) depois do apply.

Closes #
"@

    $prOutput = Invoke-NativeCommand -Command "gh" -Arguments @("pr", "create", "--title", $title, "--body", $body) -CaptureOutput
    $prUrlMatch = [regex]::Match($prOutput, 'https://\S+/pull/\d+')
    if (-not $prUrlMatch.Success) {
        throw "gh pr create nao retornou uma URL de PR valida: $prOutput"
    }
    $prUrl = $prUrlMatch.Value
    $prNumber = ($prUrl -split '/')[-1]
    Invoke-NativeCommand -Command "gh" -Arguments @("pr", "merge", $prNumber, "--merge", "--admin")

    Invoke-NativeCommand -Command "git" -Arguments @("checkout", "main")
    Invoke-NativeCommand -Command "git" -Arguments @("pull", "origin", "main")
    Invoke-NativeCommand -Command "git" -Arguments @("merge-base", "--is-ancestor", $branchCommit, "main")

    if ($Apply) {
        $applyArgs = @(
            "run",
            "--env=$InfisicalEnvironment",
            "--path=$InfisicalPath",
            "--projectId=$InfisicalProjectId",
            "--",
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $terraformScript,
            "-Mode",
            "Apply",
            "-PlanFile",
            $planFile
        )

        & $infisical.Source @applyArgs
        if ($LASTEXITCODE -ne 0) {
            throw "terraform apply do plano validado falhou depois do merge da PR $prUrl."
        }
    }

    Write-Host ""
    Write-Host "PR: $prUrl" -ForegroundColor Cyan
    if (-not $Apply) {
        Write-Host "Merged. Run 'make apply' to actually apply it." -ForegroundColor Yellow
    }
}
finally {
    if ($planFile -and (Test-Path -LiteralPath $planFile)) {
        try {
            Remove-Item -LiteralPath $planFile -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Nao foi possivel remover o plano Terraform temporario: $planFile"
        }
    }
}
