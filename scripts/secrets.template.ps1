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

# --- api-core ---------------------------------------------------------

$env:TF_VAR_api_core_db_url = '<jdbc:postgresql://host:5432/dbname>'
$env:TF_VAR_api_core_db_username = '<usuario>'
$env:TF_VAR_api_core_db_password = '<senha>'
$env:TF_VAR_api_core_redis_url = '<redis://host:6379>'
$env:TF_VAR_api_core_cloudinary_cloud_name = '<cloud-name>'
$env:TF_VAR_api_core_cloudinary_api_key = '<api-key>'
$env:TF_VAR_api_core_cloudinary_api_secret = '<api-secret>'
$env:TF_VAR_api_core_google_translate_api_key = '<api-key>'

# --- api-auth ----------------------------------------------------------

$env:TF_VAR_api_auth_db_url = '<jdbc:postgresql://host:5432/dbname>'
$env:TF_VAR_api_auth_db_username = '<usuario>'
$env:TF_VAR_api_auth_db_password = '<senha>'
$env:TF_VAR_api_auth_redis_host = '<host-do-redis>'
# porta já tem default 6379 no variables.tf, só defina se for diferente
# $env:TF_VAR_api_auth_redis_port = "6379"
$env:TF_VAR_api_auth_jwt_keystore_password = '<senha-do-keystore>'
$env:TF_VAR_api_auth_jwt_active_kid = '<kid-ativo>'

# Caminho local do arquivo keystore.p12 do JWT - o script converte pra base64
# sozinho, você só precisa apontar pro arquivo
$jwtKeystorePath = '<caminho\para\seu\keystore.p12>'
if (Test-Path $jwtKeystorePath) {
    $env:TF_VAR_api_auth_jwt_keystore_base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($jwtKeystorePath))
} else {
    Write-Warning "jwtKeystorePath nao encontrado ('$jwtKeystorePath') - edite a variavel acima antes de rodar terraform apply"
}
