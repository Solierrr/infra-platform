# Arquitetura do Repositório

Este repositório segue a arquitetura padrão de um projeto Terraform da organização: um conjunto de arquivos `.tf` na raiz, sem subpastas de módulo, já que o escopo é um único cluster GKE com seus recursos de rede e as instalações Helm/Kubernetes que rodam dentro dele. `main.tf` concentra os recursos de infraestrutura propriamente ditos (rede, cluster, node pool, ArgoCD, Kong, cert-manager e certificados TLS), `secrets.tf` concentra exclusivamente a distribuição de segredos de aplicação lidos do Infisical para dentro do cluster, e `variables.tf`/`versions.tf`/`output.tf` cuidam, respectivamente, de parâmetros de entrada, providers/backends e valores expostos após o apply. Os scripts em `scripts/` são ferramentas PowerShell de apoio específicas da plataforma. `make plan`, `make apply`, `make destroy` e `make toggle-nodes ... APPLY=1` usam `infisical run` para injetar as credenciais de bootstrap do provider; `make vault` continua extraindo segredos de aplicação para um arquivo `.env` quando necessário.

<p>
  <a href="https://github.com/syvixor/skills-icons">
    <img src="https://skills.syvixor.com/api/icons?i=terraform,gcp,kubernetes,helm,powershell" height="48" alt="Arquitetura">
  </a>
</p>

- **Infraestrutura como código monolítica**, sem módulos Terraform separados — todos os recursos vivem nos arquivos `.tf` da raiz, já que o escopo é um único cluster GKE, não uma plataforma multi-ambiente.
- **Cluster efêmero**, o `google_container_node_pool.primary_nodes` é dimensionado sob demanda (inclusive para `node_count = 0`) via `scripts/toggle-nodes.ps1`, em vez de manter nodes ativos (e cobrando) o tempo todo.
- **Segredos centralizados no Infisical**, `secrets.tf` não guarda nenhum valor sensível em texto puro — cada `kubernetes_secret` é montado a partir de `data.infisical_secrets` lidos do vault, por pasta/tecnologia, e distribuído para o serviço correspondente dentro do cluster.
- **Bootstrap de plataforma via Helm/kubectl**, o Terraform não só sobe o cluster, como também instala nele o ArgoCD (GitOps), o Kong (gateway/ingress) e o cert-manager (certificados TLS via Let's Encrypt), preparando o cluster para receber as demais aplicações.

## Recursos definidos em `main.tf`

- `google_compute_network.vpc` e `google_compute_subnetwork.subnet`, a VPC dedicada (`solaria-vpc`) e a subnet (`solaria-subnet`) onde o cluster GKE roda.
- `google_container_cluster.primary`, o cluster GKE (`solaria-gke`), com o node pool padrão removido (`remove_default_node_pool = true`) e controle de acesso ao control plane via `master_authorized_networks_config`, restrito ao IP definido em `var.authorized_ip_cidr`.
- `google_container_node_pool.primary_nodes`, o node pool efetivo do cluster (`solaria-node-pool`, máquinas `e2-medium`), cujo `node_count` é o alvo do script de liga/desliga do cluster.
- `helm_release.argocd`, instalação do ArgoCD via Helm chart oficial, exposto por ingress no Kong sob um hostname `sslip.io` baseado no IP público do Kong.
- `google_compute_address.kong_ip`, IP público estático regional reservado para o LoadBalancer do Kong.
- `data.http.kong_values_base` / `data.http.kong_values_dev`, leitura remota dos arquivos de values do Helm do Kong direto do repositório [infra-gateway](https://github.com/Solierrr/infra-gateway).
- `helm_release.kong`, instalação do Kong como API Gateway/Ingress Controller, usando o IP reservado acima como `proxy.loadBalancerIP`.
- `helm_release.cert_manager`, instalação do cert-manager, responsável por emitir e renovar certificados TLS no cluster.
- `kubernetes_secret.cloudflare_api_token`, token da API do Cloudflare usado pelo cert-manager no desafio DNS-01.
- `cloudflare_dns_record.api_recommendation` e `cloudflare_ruleset.api_recommendation_cache`, o registro com proxy da Cloudflare para `api-recommendation.<domínio>` (que sobrepõe o wildcard DNS-only) e a regra de cache que atende `/public/feeds/*` na borda respeitando o `Cache-Control` da origem. Exigem que o token da Cloudflare tenha permissão de editar regras de cache da zona.
- `kubectl_manifest.letsencrypt_prod_issuer` e `kubectl_manifest.letsencrypt_http01_issuer`, os `ClusterIssuer` do Let's Encrypt (desafios DNS-01 via Cloudflare e HTTP-01 via Kong, respectivamente).

## Propósito de `secrets.tf`

Concentra a ponte entre o vault [Infisical](https://infisical.com) (autenticado via Machine Identity `gke-sync`, configurada em `versions.tf`) e os `kubernetes_secret` consumidos pelos serviços da organização (`api-messenger`, `api-core`, `api-auth`, `api-recommendation`, `api-mcp`, `ai-assistant`, `ai-validation`, `feeddb` e `database-bootstrap`). Cada serviço tem um bloco próprio que lê uma ou mais pastas do Infisical (`/database`, `/redis`, `/cloudinary`, `/google`, `/auth`, `/llm`, `/feeddb`, etc.) via `data.infisical_secrets`, filtra ou combina (`merge`) só as chaves relevantes, e cria o `kubernetes_secret` correspondente no namespace `default`. A pasta `/feeddb` guarda as credenciais do Neo4j self-hosted (`DB_NEO4J_URI`, `DB_NEO4J_USER`, `DB_NEO4J_PASSWORD`, `DB_NEO4J_FEED`) e precisa existir no Infisical (env `prod`) antes do `plan`, porque `feeddb-secrets` e `database-bootstrap-secrets` leem dela; a primeira monta o `NEO4J_AUTH` do Neo4j e a segunda soma as chaves de Postgres do `/database` com as de Neo4j do `/feeddb` para o job de bootstrap do grafo. O `web-app` é a exceção documentada: por ser uma SPA estática, suas variáveis `VITE_*` são embutidas no bundle em build-time (no CI), não injetadas em runtime pelo Terraform.

## Papel dos scripts em `scripts/`

- `toggle-nodes.ps1`, automatiza a escala do node pool: edita o `node_count` em `main.tf`, cria uma branch, comita, abre e faz merge de uma PR (`gh pr create` / `gh pr merge --admin`) e, opcionalmente (`-Apply`), aplica com as credenciais de bootstrap injetadas pelo Infisical. Quando `-Apply` é usado, salva um plano temporário, verifica que somente `google_container_node_pool.primary_nodes.node_count` muda para o valor pedido, e aplica esse mesmo plano depois de confirmar que o commit da PR chegou a `main`. O arquivo de plano pode conter valores sensíveis; fica na pasta temporária do sistema e é removido ao final do script.
- `ensure-secrets.ps1`, valida as credenciais de bootstrap injetadas pelo Infisical CLI, mapeia-as para as variáveis `TF_VAR_*` do provider e detecta o IP público atual para o acesso ao control plane do GKE. As credenciais não são gravadas em arquivo local.

Os alvos `plan`, `apply`, `destroy`, `toggle-nodes` e `check-environments` do `Makefile` chamam comandos ou scripts PowerShell desta pasta e são a exceção ao Makefile padrão da organização (`docs-warehouse/templates/make/`), que não usa PowerShell. `toggle-nodes` só requer Infisical quando `APPLY=1`; o plano verifica o acesso dos providers antes de criar e mesclar a PR.

```Tree do Repositório
├── .github/
│   ├── CODEOWNERS
│   ├── CONTRIBUTING.md
│   └── pull_request_template.md
├── scripts/
│   ├── ensure-secrets.ps1
│   ├── terraform-toggle.ps1
│   └── toggle-nodes.ps1
├── README.md
├── ARCHITECTURE.md
├── RUNNING.md
├── main.tf
├── secrets.tf
├── variables.tf
├── versions.tf
├── output.tf
├── .editorconfig
├── .gitattributes
├── .gitignore
├── .terraform.lock.hcl
├── LICENSE
└── ...
```
