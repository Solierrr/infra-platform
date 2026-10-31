# Arquitetura do Repositório

Este repositório é um projeto Terraform com uma raiz de composição e três módulos locais em `modules/`, um por área: `cluster`, `vault` e `cloudflare`. O escopo é um único cluster GKE com seus recursos de rede, as instalações Helm/Kubernetes e a borda na Cloudflare.

<p>
  <a href="https://github.com/syvixor/skills-icons">
    <img src="https://skills.syvixor.com/api/icons?i=terraform,gcp,kubernetes,helm,powershell" height="48" alt="Arquitetura">
  </a>
</p>

- **Infraestrutura como código em módulos locais**, a raiz (`main.tf`) só liga três módulos: `modules/cluster` (rede, GKE, Kong, Argo CD e cert-manager), `modules/vault` (leitura do Infisical e Secrets do cluster) e `modules/cloudflare` (DNS, cache e Cloudflare Access). Os blocos `moved` em `main.tf` preservam o state de antes da divisão.
- **Cluster efêmero**, o `google_container_node_pool.primary_nodes` é dimensionado sob demanda (inclusive para `node_count = 0`) via `scripts/toggle-nodes.ps1`, em vez de manter nodes ativos (e cobrando) o tempo todo.
- **Segredos centralizados no Infisical**, `modules/vault` não guarda nenhum valor sensível em texto puro — cada `kubernetes_secret` é montado a partir de `data.infisical_secrets` lidos do vault, por pasta/tecnologia, e distribuído para o serviço correspondente dentro do cluster.
- **Bootstrap de plataforma via Helm/kubectl**, o Terraform não só sobe o cluster, como também instala nele o ArgoCD (GitOps), o Kong (gateway/ingress) e o cert-manager (certificados TLS via Let's Encrypt), preparando o cluster para receber as demais aplicações.

## Recursos de `modules/cluster` e `modules/cloudflare`

- `google_compute_network.vpc` e `google_compute_subnetwork.subnet`, a VPC dedicada (`solaria-vpc`) e a subnet (`solaria-subnet`) onde o cluster GKE roda.
- `google_container_cluster.primary`, o cluster GKE (`solaria-gke`), com o node pool padrão removido (`remove_default_node_pool = true`) e controle de acesso ao control plane via `master_authorized_networks_config`, restrito ao IP definido em `var.authorized_ip_cidr`.
- `google_container_node_pool.primary_nodes`, o node pool efetivo do cluster (`solaria-node-pool`, máquinas `e2-medium`), cujo `node_count` é o alvo do script de liga/desliga do cluster.
- `helm_release.argocd`, instalação do ArgoCD via Helm chart oficial, exposto por ingress no Kong sob um hostname `sslip.io` baseado no IP público do Kong.
- `google_compute_address.kong_ip`, IP público estático regional reservado para o LoadBalancer do Kong.
- `data.http.kong_values_base` / `data.http.kong_values_dev`, leitura remota dos arquivos de values do Helm do Kong direto do repositório [infra-gateway](https://github.com/Solierrr/infra-gateway).
- `helm_release.kong`, instalação do Kong como API Gateway/Ingress Controller, usando o IP reservado acima como `proxy.loadBalancerIP`.
- `helm_release.cert_manager`, instalação do cert-manager, responsável por emitir e renovar certificados TLS no cluster.
- `kubernetes_secret.cloudflare_api_token`, token da API do Cloudflare usado pelo cert-manager no desafio DNS-01.
- `cloudflare_dns_record.api_recommendation` e `cloudflare_ruleset.api_recommendation_cache`, o registro com proxy da Cloudflare para `recommendation.<domínio>` (que sobrepõe o wildcard DNS-only) e a regra de cache que atende `/public/feeds/*` na borda respeitando o `Cache-Control` da origem. Exigem que o token da Cloudflare tenha permissão de editar regras de cache da zona.
- `kubectl_manifest.letsencrypt_prod_issuer` e `kubectl_manifest.letsencrypt_http01_issuer`, os `ClusterIssuer` do Let's Encrypt (desafios DNS-01 via Cloudflare e HTTP-01 via Kong, respectivamente).

## Propósito de `modules/vault`

Concentra a ponte entre o vault [Infisical](https://infisical.com) (autenticado via Machine Identity `gke-sync`, configurada em `versions.tf`) e os `kubernetes_secret` consumidos pelos serviços da organização (`api-messenger`, `api-notify`, `api-core`, `api-auth`, `api-email`, `api-recommendation`, `mcp-database`, `ai-assistant`, `ai-accessibility`, `ai-geographic`, `ai-operational`, `ai-validation`, `google-registry`, `infra-broker`, `infra-grafana`, `feeddb` e `database-bootstrap`). Cada serviço tem um bloco próprio que lê uma ou mais pastas do Infisical (`/database`, `/redis`, `/cloudinary`, `/google`, `/auth`, `/llm`, `/feeddb`, etc.) via `data.infisical_secrets`, filtra ou combina (`merge`) só as chaves relevantes, e cria o `kubernetes_secret` correspondente no namespace `default`. A pasta `/feeddb` guarda as credenciais do Neo4j self-hosted (`DB_NEO4J_URI`, `DB_NEO4J_USER`, `DB_NEO4J_PASSWORD`, `DB_NEO4J_FEED`) e precisa existir no Infisical (env `prod`) antes do `plan`, porque `feeddb-secrets` e `database-bootstrap-secrets` leem dela; a primeira monta o `NEO4J_AUTH` do Neo4j e a segunda soma as chaves de Postgres do `/database` com as de Neo4j do `/feeddb` para o job de bootstrap do grafo. A pasta `/broker` (`RABBITMQ_USER` e `RABBITMQ_PASSWORD`) alimenta o `infra-broker` e o `api-messenger`, e a `/email` (`BREVO_API_KEY` e `EMAIL_FROM`) o `api-email`. O `infra-grafana` é a exceção inversa: a senha do administrador é gerada pelo `random_password.grafana_admin` e fica só no state (`terraform output -raw grafana_admin_password`), porque o Infisical ainda não tem uma pasta do Grafana. O `web-app` é a exceção documentada: por ser uma SPA estática, suas variáveis `VITE_*` são embutidas no bundle em build-time (no CI), não injetadas em runtime pelo Terraform.

## Papel dos scripts em `scripts/`

- `toggle-nodes.ps1`, automatiza a escala do node pool: edita o `node_count` em `modules/cluster/main.tf`, cria uma branch, comita, abre e faz merge de uma PR (`gh pr create` / `gh pr merge --admin`) e, opcionalmente (`-Apply`), roda `terraform apply -auto-approve` — garantindo que o state do Terraform nunca fique divergente do que está de fato aplicado.
- `secrets.template.ps1`, template para o arquivo local `scripts/secrets.local.ps1` (ignorado pelo `.gitignore`), que exporta as variáveis `TF_VAR_*` consumidas pelo Terraform antes de um `plan`/`apply` — client ID/secret da Machine Identity `gke-sync` do Infisical (usada por `secrets.tf` pra buscar as credenciais reais de cada serviço em `env=prod`), a senha do ArgoCD, o token do Cloudflare e o e-mail do ACME. Não inclui mais credencial por serviço nem conversão de keystore `.p12` — isso já vem pronto do Infisical (`JWT_KEYSTORE_BASE64` em `/auth`).

Os alvos `plan`, `apply`, `destroy`, `toggle-nodes` e `check-environments` do `Makefile` chamam os scripts PowerShell desta pasta e são a exceção ao Makefile padrão da organização (`docs-warehouse/templates/make/`), que não usa PowerShell.

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
├── modules/
│   ├── cluster/
│   ├── vault/
│   └── cloudflare/
├── main.tf
├── variables.tf
├── versions.tf
├── outputs.tf
├── .editorconfig
├── .gitattributes
├── .gitignore
├── .terraform.lock.hcl
├── LICENSE
└── ...
```

## Cloudflare Access

`modules/cloudflare/access.tf` protege o Argo CD e o Grafana (host inteiro) e a documentação das APIs (`/swagger-ui*`, `/v3/api-docs*`, `/docs*`, `/redoc*` e `/openapi.json*`) com login pelo Google. Só é criado quando `access_allowed_emails` tem ao menos um e-mail. O app e a política que já existem no painel precisam ser importados antes do primeiro apply, para não duplicar.

## Token da Cloudflare

Dois tokens, com papéis separados:

- Token mestre (`CLOUDFLARE_TOKEN_MANAGER`, pasta `/infisical` do Infisical): criado à mão uma vez em Profile, API Tokens, com a permissão User, API Tokens, Edit. Só o módulo `modules/cloudflare-token` o usa, por um provider com alias `manager`.
- Token operacional (`CLOUDFLARE_API_TOKEN`, pasta `/cloudflare`): usado pelo Terraform e pelo cert-manager. `modules/cloudflare-token` gere as permissões dele (DNS Write, Zone Read e Cache Settings Write na zona; Access Apps and Policies e Identity Providers Read na conta) sem mudar o valor. O bloco `import` adota o token que já existia.

Para rotacionar o mestre, crie outro no painel e troque o valor em `/infisical`.

## Saída fixa para a internet

Os nós do node pool não têm IP público. A saída dos pods passa pelo Cloud NAT (`google_compute_router_nat.nat`) com o IP estático `google_compute_address.nat_ip`, exposto pela saída `nat_ip`. É esse IP que se libera no MongoDB Atlas e em outros serviços externos, e ele não muda quando os nós são trocados.

## Login do Argo CD pelo Access

O app `argocd-sso` (tipo SaaS, OIDC) faz o Cloudflare Access agir como provedor de identidade do Argo CD. O módulo `cloudflare` expõe o emissor e as credenciais, e o módulo `cluster` os coloca no Helm do Argo CD (`configs.cm.oidc.config`). Os e-mails de `access_allowed_emails` entram como `role:admin`; os demais ficam só com leitura. O usuário `admin` por senha está desligado (`admin.enabled: "false"`): só o SSO entra. Se o SSO quebrar, o caminho de volta é remover essa linha em `modules/cluster/main.tf` e aplicar o Terraform.

## Coletor de telemetria

O OpenTelemetry Collector roda no namespace `solierrr` (o endereço `otel-collector.solierrr.svc.cluster.local:4318` já está em `OTEL_EXPORTER_OTLP_ENDPOINT`), instalado pelo ArgoCD a partir do `infra-otel-collector`. O módulo `vault` cria o namespace e, quando a pasta `/grafana-cloud` do Infisical (prod) tem `GRAFANA_CLOUD_OTLP_ENDPOINT` e `GRAFANA_CLOUD_OTLP_AUTH`, o Secret `grafana-cloud-otlp` que o coletor lê. Essas chaves ficam fora de `/otel` porque essa pasta é copiada para o Secret de todos os serviços.

## Kong só para a Cloudflare

O Service do Kong recebe `loadBalancerSourceRanges` com as faixas IPv4 da borda da Cloudflare, lidas de `data.cloudflare_ip_ranges` a cada plan. Quem chamar o IP do Kong direto, sem passar pela Cloudflare, é barrado pelo firewall do Google, então o Cloudflare Access passa a ser a única porta de entrada. Os certificados do `web-app` e do `grafana` usam o `letsencrypt-prod` (validação por DNS), porque a validação por HTTP exigiria abrir a porta 80 para todo mundo.

## Quem entra e com qual papel

- `access_allowed_emails` (código) e `ACCESS_EXTRA_EMAILS` (pasta `/terraform` do Infisical, separados por vírgula) definem quem passa pelo Cloudflare Access. Os e-mails extras ficam no Infisical e não no código, porque este repositório é público.
- `admin_emails` define quem é administrador do Argo CD e do Grafana. Quem está só no Access entra no Argo CD com leitura e no Grafana como visualizador.
- O papel no Grafana vem de `GF_AUTH_JWT_ROLE_ATTRIBUTE_PATH`, montado pelo módulo `vault` no Secret `infra-grafana-secrets`; o manifesto do `infra-gitops` não o define.

