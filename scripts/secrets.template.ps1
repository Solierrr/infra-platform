# Copie este arquivo para scripts/secrets.local.ps1 (já está no .gitignore) e
# preencha os valores reais. Depois, antes de rodar terraform apply, execute
# (a partir da raiz do repo):
#   . .\scripts\secrets.local.ps1
# (o ponto no início carrega as variáveis na sessão atual do PowerShell)

# IP público autorizado a acessar o control plane do GKE (opcional - já tem
# default no variables.tf, só precisa definir se sua rede/IP mudou)
# $env:TF_VAR_authorized_ip_cidr = "seu.ip.publico.aqui/32"

# Hash bcrypt da senha fixa do admin do ArgoCD (gere com bcrypt, nunca a senha em texto puro)
$env:TF_VAR_argocd_admin_password_hash = '<hash-bcrypt-aqui>'

# Token da API do Cloudflare (permissão Zone:DNS:Edit na zona do domínio),
# usado pelo cert-manager no desafio DNS-01
$env:TF_VAR_cloudflare_api_token = '<token-aqui>'

# E-mail usado para registrar a conta ACME no Let's Encrypt
$env:TF_VAR_acme_email = '<email-aqui>'

# Connection string do MongoDB usado pelo api-messenger
$env:TF_VAR_api_messenger_mongo_uri = '<connection-string-aqui>'
