# Rodando o Projeto Localmente

Este repositório é Terraform (IaC). Não há "servidor de desenvolvimento" — rodar localmente significa validar/planejar mudanças de infraestrutura antes de aplicá-las no Google Cloud. O fluxo local é autenticar no GCP e no Infisical, rodar `make plan` para revisar o diff, e só então `make apply`. Por causa do conceito de **cluster efêmero** adotado neste repositório, também é comum usar `make toggle-nodes` para zerar ou restaurar o node pool do GKE quando o cluster não está em uso, em vez de destruir e recriar toda a infraestrutura.

<p>
  <a href="https://github.com/syvixor/skills-icons">
    <img src="https://skills.syvixor.com/api/icons?i=terraform,gcp,github,powershell" height="48" alt="Rodando o Projeto — Terraform">
  </a>
</p>

## Possíveis Impedimentos

- **Terraform CLI instalado**, na versão travada em `.terraform.lock.hcl` (`>= 1.16.0`) — versões diferentes podem gerar diffs de provider inesperados.
- **Acesso ao Google Cloud (`gcloud auth application-default login`)**, o provider Google do Terraform usa Application Default Credentials — sem isso, `terraform plan` falha na autenticação.
- **Permissão de owner/editor no projeto GCP (`solaria-authenticator`)**, criar/alterar recursos de cluster (GKE, VPC, IAM) exige permissões elevadas, normalmente restritas a poucas pessoas na organização.
- **Infisical CLI autenticado** (`make login`) e acesso pessoal de leitura à pasta `/infisical` no environment `prod`. O Make injeta `INFISICAL_CLIENT_ID` e `INFISICAL_CLIENT_SECRET` somente nos processos Terraform; esses valores autenticam a Machine Identity `gke-sync`, que também precisa de acesso de leitura às pastas usadas pelo Terraform no environment `prod`. `make toggle-nodes ... APPLY=1` usa o mesmo fluxo.
- **`gh` (GitHub CLI) autenticado**, necessário apenas para quem for usar `make toggle-nodes`, já que o script abre e faz merge de Pull Requests automaticamente.
- **`terraform apply` é uma ação real e cobrada**, ao contrário de rodar uma aplicação localmente, aplicar este Terraform sobe recursos de verdade no Google Cloud (cluster GKE, nodes, IP público) — nunca rode `apply` sem antes revisar o `plan` com atenção.

## Atalhos via Makefile

<p>
  <a href="https://github.com/syvixor/skills-icons">
    <img src="https://skills.syvixor.com/api/icons?i=make" height="48" alt="Makefile">
  </a>
</p>

O `Makefile` na raiz embrulha os comandos mais usados deste repositório - nenhum deles substitui os passos abaixo, é só conveniência.

```Comandos do Makefile
make install-tools                        # instala terraform, gcloud sdk, gh, infisical e kubectl via winget
make login                                # infisical login
make init                                 # terraform init
make plan                                 # terraform plan
make apply                                # terraform apply
make doctor                               # verifica git, terraform e o status do Infisical CLI e da sessão
make destroy                              # terraform destroy
make install                              # terraform init -backend=false (só providers, para validar)
make ci                                   # terraform fmt -check e terraform validate (rode make install antes)
make toggle-nodes NODES=0                 # zera o node pool (pausa o cluster), abre e mergeia a PR
make toggle-nodes NODES=2 APPLY=1         # restaura o node pool e já aplica
```

`make install`, `make lint`, `make build` e `make ci` seguem o Makefile padrão da organização (`docs-warehouse/templates/make/`) e não precisam de credenciais do GCP. `make plan`, `make apply`, `make destroy` e `make toggle-nodes ... APPLY=1` usam `infisical run` para buscar as duas credenciais de bootstrap em `/infisical` (`prod`) e passá-las aos processos que executam Terraform. No toggle com apply, o script cria um plano temporário e verifica que a única mudança é o `node_count` do node pool para o valor pedido; depois da PR chegar a `main`, aplica exatamente esse plano. O plano temporário pode conter valores sensíveis, fica fora do repositório e é removido ao final do script. `scripts/ensure-secrets.ps1` mapeia as variáveis para `TF_VAR_*` e detecta o IP público atual; nenhum arquivo local de credenciais é criado. `toggle-nodes` sem apply e `check-environments` não precisam das credenciais de bootstrap.

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

### Autenticando no Infisical

<p>
  <a href="https://github.com/syvixor/skills-icons">
    <img src="https://skills.syvixor.com/api/icons?i=powershell" height="48" alt="Secrets">
  </a>
</p>

Autentique o CLI uma vez:

```Comando de autenticação
make login
```

Depois, rode `make plan`, `make apply`, `make destroy` ou `make toggle-nodes NODES=2 APPLY=1`. O Make lê `INFISICAL_CLIENT_ID` e `INFISICAL_CLIENT_SECRET` de `/infisical` (`prod`) e os disponibiliza somente nos processos que executam Terraform. A Machine Identity `gke-sync` precisa ter permissão de leitura no environment `prod`. Comandos `terraform plan`/`apply`/`destroy` executados diretamente precisam receber `TF_VAR_infisical_client_id` e `TF_VAR_infisical_client_secret` por outro meio.

### Validando e aplicando as mudanças

<p>
  <a href="https://github.com/syvixor/skills-icons">
    <img src="https://skills.syvixor.com/api/icons?i=terraform" height="48" alt="Frameworks">
  </a>
</p>

`make init` baixa os providers e configura o backend remoto do state — rode sempre que clonar o repositório ou trocar de branch com mudanças no backend.

```Comandos para validar e aplicar mudanças
make init
make plan
make apply
```

### Ligando e desligando o cluster (custo)

<p>
  <a href="https://github.com/syvixor/skills-icons">
    <img src="https://skills.syvixor.com/api/icons?i=powershell,github" height="48" alt="Toggle de Nodes">
  </a>
</p>

Para pausar o cluster (zerar o node pool sem destruir o control plane nem o IP do Kong) ou retomá-lo depois, use `make toggle-nodes` em vez de editar `main.tf` na mão — o script já cuida de branch, commit, PR e (opcionalmente) do `terraform apply`.

```Exemplos de uso do script de toggle
# Zera o node pool (pausa o cluster) e abre/mergeia a PR, sem aplicar
make toggle-nodes NODES=0

# Restaura o node pool para 2 nodes e já aplica no Google Cloud
make toggle-nodes NODES=2 APPLY=1
```
