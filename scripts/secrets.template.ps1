# Copie este arquivo para scripts/secrets.local.ps1 (já está no .gitignore) e
# preencha os valores reais. Depois, antes de rodar terraform apply, execute
# (a partir da raiz do repo):
#   . .\scripts\secrets.local.ps1
# (o ponto no início carrega as variáveis na sessão atual do PowerShell)
#
# Desde a migração de secrets.tf para o provider Infisical (data
# "infisical_secrets" por pasta, ver docs-warehouse/architecture), o
# Terraform não lê mais um TF_VAR_* por credencial de serviço - ele busca
# tudo direto do Infisical (env prod) usando a Machine Identity abaixo. Só
# seguem manuais aqui os valores que não vêm do Infisical.

# IP público autorizado a acessar o control plane do GKE (opcional - já tem
# default no variables.tf, só precisa definir se sua rede/IP mudou)
# $env:TF_VAR_authorized_ip_cidr = "seu.ip.publico.aqui/32"

# Client ID/Secret da Machine Identity gke-sync do Infisical (Universal
# Auth) - dashboard do Infisical -> Project -> Identities -> gke-sync
$env:TF_VAR_infisical_client_id = '<client-id-aqui>'
$env:TF_VAR_infisical_client_secret = '<client-secret-aqui>'

# Hash bcrypt da senha fixa do admin do ArgoCD (gere com bcrypt, nunca a senha em texto puro)
$env:TF_VAR_argocd_admin_password_hash = '<hash-bcrypt-aqui>'

# Token da API do Cloudflare (permissão Zone:DNS:Edit na zona do domínio),
# usado pelo cert-manager no desafio DNS-01
$env:TF_VAR_cloudflare_api_token = '<token-aqui>'

# E-mail usado para registrar a conta ACME no Let's Encrypt
$env:TF_VAR_acme_email = '<email-aqui>'
