# Arquitetura do Repositório

Este repositório segue a arquitetura padrão de um projeto Terraform da organização: um conjunto de arquivos `.tf` na raiz, sem subpastas de módulo, já que o escopo é um único cluster GKE com seus recursos de rede e as instalações Helm/Kubernetes que rodam dentro dele. `main.tf` concentra os recursos de infraestrutura propriamente ditos (rede, cluster, node pool, ArgoCD, Kong, cert-manager e os `ClusterIssuer` do Let's Encrypt), `secrets.tf` concentra exclusivamente a distribuição de segredos de aplicação lidos do Infisical para dentro do cluster, e `variables.tf`/`versions.tf`/`output.tf` cuidam, respectivamente, de parâmetros de entrada, providers/backends e valores expostos após o `apply`. Os scripts em `scripts/` não fazem parte do plano do Terraform em si — são ferramentas PowerShell de apoio ao fluxo local, usadas para escalar o node pool e para carregar segredos como variáveis de ambiente antes de rodar os comandos do Terraform.

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
- `kubectl_manifest.letsencrypt_prod_issuer` e `kubectl_manifest.letsencrypt_http01_issuer`, os `ClusterIssuer` do Let's Encrypt (desafios DNS-01 via Cloudflare e HTTP-01 via Kong, respectivamente).

## Propósito de `secrets.tf`

Concentra a ponte entre o vault [Infisical](https://infisical.com) (autenticado via Machine Identity `gke-sync`, configurada em `versions.tf`) e os `kubernetes_secret` consumidos pelos serviços da organização (`api-messenger`, `api-core`, `api-auth`, `api-recommendation`, `api-mcp`, `ai-assistant`, `ai-validation`). Cada serviço tem um bloco próprio que lê uma ou mais pastas do Infisical (`/database`, `/redis`, `/cloudinary`, `/google`, `/auth`, `/llm`, etc.) via `data.infisical_secrets`, filtra ou combina (`merge`) só as chaves relevantes, e cria o `kubernetes_secret` correspondente no namespace `default`. O `web-app` é a exceção documentada: por ser uma SPA estática, suas variáveis `VITE_*` são embutidas no bundle em build-time (no CI), não injetadas em runtime pelo Terraform.

## Papel dos scripts em `scripts/`

- `toggle-nodes.ps1`, automatiza a escala do node pool: edita o `node_count` em `main.tf`, cria uma branch, comita, abre e faz merge de uma PR (`gh pr create` / `gh pr merge --admin`) e, opcionalmente (`-Apply`), roda `terraform apply -auto-approve` — garantindo que o state do Terraform nunca fique divergente do que está de fato aplicado.
- `secrets.template.ps1`, template para o arquivo local `scripts/secrets.local.ps1` (ignorado pelo `.gitignore`), que exporta as variáveis `TF_VAR_*` consumidas pelo Terraform antes de um `plan`/`apply` — inclui a senha do ArgoCD, o token do Cloudflare, o e-mail do ACME e credenciais por serviço, além da conversão automática de um keystore `.p12` local para base64.

```Tree do Repositório
├── .github/
│   ├── CODEOWNERS
│   ├── CONTRIBUTING.md
│   └── pull_request_template.md
├── scripts/
│   ├── secrets.template.ps1
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
