# Rodando o Projeto Localmente

Este repositório é Terraform (IaC). Não há "servidor de desenvolvimento" — rodar localmente significa validar/planejar mudanças de infraestrutura antes de aplicá-las no Google Cloud. O fluxo local é sempre o mesmo: clonar, autenticar no GCP, carregar os segredos necessários na sessão do PowerShell, rodar `terraform plan` para revisar o diff, e só então `terraform apply`. Por causa do conceito de **cluster efêmero** adotado neste repositório, também é comum o fluxo inverso: usar o script `toggle-nodes.ps1` para zerar (ou restaurar) o node pool do GKE quando o cluster não está em uso, em vez de destruir e recriar toda a infraestrutura.

<p>
  <a href="https://github.com/syvixor/skills-icons">
    <img src="https://skills.syvixor.com/api/icons?i=terraform,gcp,github,powershell" height="48" alt="Rodando o Projeto — Terraform">
  </a>
</p>

## Possíveis Impedimentos

- **Terraform CLI instalado**, na versão travada em `.terraform.lock.hcl` (`>= 1.16.0`) — versões diferentes podem gerar diffs de provider inesperados.
- **Acesso ao Google Cloud (`gcloud auth application-default login`)**, o provider Google do Terraform usa Application Default Credentials — sem isso, `terraform plan` falha na autenticação.
- **Permissão de owner/editor no projeto GCP (`solaria-authenticator`)**, criar/alterar recursos de cluster (GKE, VPC, IAM) exige permissões elevadas, normalmente restritas a poucas pessoas na organização.
- **Segredos carregados na sessão antes do `plan`/`apply`**, além do GCP, o Terraform depende de variáveis `TF_VAR_*` (hash do admin do ArgoCD, token do Cloudflare, e-mail do ACME, credenciais do Infisical) — sem elas, o `plan` falha pedindo os valores interativamente.
- **`gh` (GitHub CLI) autenticado**, necessário apenas para quem for usar `scripts/toggle-nodes.ps1`, já que o script abre e faz merge de Pull Requests automaticamente.
- **`terraform apply` é uma ação real e cobrada**, ao contrário de rodar uma aplicação localmente, aplicar este Terraform sobe recursos de verdade no Google Cloud (cluster GKE, nodes, IP público) — nunca rode `apply` sem antes revisar o `plan` com atenção.

## Instalação do Projeto

### Iniciando o repositório com o Github

<p>
  <a href="https://github.com/syvixor/skills-icons">
    <img src="https://skills.syvixor.com/api/icons?i=github,vscode" height="48" alt="Frameworks">
  </a>
</p>

Clone o repositório e abra no VS Code (com a extensão HashiCorp Terraform para syntax highlighting e validação).

```Comandos para clonar o repositório
git clone https://github.com/Solierrr/infra-platform.git
cd ./infra-platform
code . -r
```

### Carregando os segredos locais

<p>
  <a href="https://github.com/syvixor/skills-icons">
    <img src="https://skills.syvixor.com/api/icons?i=powershell" height="48" alt="Secrets">
  </a>
</p>

Copie `scripts/secrets.template.ps1` para `scripts/secrets.local.ps1` (já está no `.gitignore`) e preencha os valores reais — hash bcrypt da senha do ArgoCD, token do Cloudflare, e-mail do ACME e credenciais por serviço. Depois, a partir da raiz do repositório, carregue as variáveis na sessão atual do PowerShell antes de rodar qualquer comando do Terraform:

```Comando para carregar os segredos na sessão
. .\scripts\secrets.local.ps1
```

### Validando e aplicando as mudanças

<p>
  <a href="https://github.com/syvixor/skills-icons">
    <img src="https://skills.syvixor.com/api/icons?i=terraform" height="48" alt="Frameworks">
  </a>
</p>

`terraform init` baixa os providers e configura o backend remoto do state — rode sempre que clonar o repositório ou trocar de branch com mudanças no backend.

```Comandos para validar e aplicar mudanças
terraform init
terraform plan
terraform apply
```

### Ligando e desligando o cluster (custo)

<p>
  <a href="https://github.com/syvixor/skills-icons">
    <img src="https://skills.syvixor.com/api/icons?i=powershell,github" height="48" alt="Toggle de Nodes">
  </a>
</p>

Para pausar o cluster (zerar o node pool sem destruir o control plane nem o IP do Kong) ou retomá-lo depois, use `scripts/toggle-nodes.ps1` em vez de editar `main.tf` na mão — o script já cuida de branch, commit, PR e (opcionalmente) do `terraform apply`.

```Exemplos de uso do script de toggle
# Zera o node pool (pausa o cluster) e abre/mergeia a PR, sem aplicar
./scripts/toggle-nodes.ps1 -NodeCount 0

# Restaura o node pool para 2 nodes e já aplica no Google Cloud
./scripts/toggle-nodes.ps1 -NodeCount 2 -Apply
```
