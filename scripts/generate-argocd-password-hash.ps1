<#
.SYNOPSIS
  Gera o hash bcrypt de uma senha pra chave ARGOCD_ADMIN_PASSWORD_HASH na
  pasta /terraform do Infisical (usado como senha fixa do admin do
  ArgoCD). Nunca salve a senha em texto puro em lugar nenhum - só o hash
  gerado aqui.

.EXAMPLE
  ./scripts/generate-argocd-password-hash.ps1 -Password "minha-senha-aqui"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Password
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Error "Python não encontrado no PATH. Instale Python ou rode 'pip install bcrypt' manualmente e gere o hash com bcrypt.hashpw."
    exit 1
}

$script = @"
import bcrypt
import sys
print(bcrypt.hashpw(sys.argv[1].encode(), bcrypt.gensalt(rounds=10)).decode())
"@

$hash = python -c $script $Password

if (-not $hash) {
    Write-Error "Falha ao gerar o hash. Confirme que o pacote 'bcrypt' está instalado (pip install bcrypt)."
    exit 1
}

Write-Host "Hash bcrypt (salve em ARGOCD_ADMIN_PASSWORD_HASH na pasta /terraform do Infisical):" -ForegroundColor Cyan
Write-Output $hash
