# Kubernetes + ArgoCD + Terraform em infra-platform

## Contexto

A organização Solierrr tem hoje 8 serviços implantáveis (repositórios separados,
todos com Dockerfile pronto):

| Serviço              | Stack              | Exposição planejada |
|----------------------|---------------------|----------------------|
| `web-app`             | React/Vite (Node)   | Pública (NodePort)  |
| `infra-gateway`       | Python              | Pública (NodePort)  |
| `api-auth`            | Java/Spring Boot    | Interna (ClusterIP) |
| `api-messenger`       | Java/Spring Boot    | Interna (ClusterIP) |
| `api-persistence`     | Java/Spring Boot    | Interna (ClusterIP) |
| `api-recommendation`  | Java/Spring Boot    | Interna (ClusterIP) |
| `ai-assistant`        | Python              | Interna (ClusterIP) |
| `ai-validation`       | Python              | Interna (ClusterIP) |

`mobile-app` e `docs-warehouse` não são implantados no cluster.

O repositório `infra-platform` já centraliza os padrões da org (templates de CI,
`.gitignore`, Docker, PR) e é onde a infraestrutura declarativa (Terraform + k8s +
ArgoCD) deve viver, seguindo o mesmo espírito de "um lugar só para infra".

O usuário nunca usou Kubernetes. Objetivo explícito deste projeto: **funcionar e
ser compreensível/mantível**, não ser a arquitetura ideal de produção. O design
prioriza poucas peças móveis por fase, com um roadmap claro de features futuras.

## Fora de escopo (fase 1) — decisão deliberada

Para manter a primeira entrega compreensível, os itens abaixo **não** entram
agora. Cada um é uma feature natural para pedir depois:

- **CI automatizado de build/push de imagem** — os `release.yml` de cada stack
  (hoje um placeholder `echo "Release ainda não configurada."` em
  `infra-platform/github/workflow/*/release.yml`) continuam como estão. Nesta
  fase, build e push das imagens Docker são feitos manualmente pelo usuário.
- **Fechamento do loop GitOps via commit automático de tag de imagem** —
  depende do item acima.
- **Domínio próprio + HTTPS (cert-manager)** — só IP da VPS por enquanto.
- **Bancos de dados dentro do cluster** (StatefulSets/PersistentVolumes) —
  Postgres/MongoDB rodam como containers Docker simples na própria VPS, fora
  do k8s.
- **Secrets criptografados em Git (Sealed Secrets/SOPS)** — secrets aplicados
  manualmente via `kubectl create secret`, nunca commitados.

## Arquitetura

```
                         ┌───────────────────────────────────────────┐
                         │        VPS (Oracle Cloud, ARM free tier)   │
                         │                                             │
  Internet ── SSH:22 ────┤  systemd/docker-compose:                   │
           ── 80/443 ────┤    - postgres (5432)                        │
           ── NodePort ──┤    - mongo (27017)                          │
           ── kube API ──┤                                             │
    (seu IP)             │  k3s (cluster single-node)                  │
                         │  ┌───────────────────────────────────────┐  │
                         │  │ namespace: argocd                     │  │
                         │  │   ArgoCD (instalado via Terraform)    │  │
                         │  ├───────────────────────────────────────┤  │
                         │  │ namespace: solierrr                   │  │
                         │  │  web-app        (NodePort, pública)   │  │
                         │  │  infra-gateway  (NodePort, pública)   │  │
                         │  │  api-auth            (ClusterIP)      │  │
                         │  │  api-messenger       (ClusterIP)      │  │
                         │  │  api-persistence     (ClusterIP)      │  │
                         │  │  api-recommendation  (ClusterIP)      │  │
                         │  │  ai-assistant        (ClusterIP)      │  │
                         │  │  ai-validation       (ClusterIP)      │  │
                         │  └───────────────────────────────────────┘  │
                         └───────────────────────────────────────────┘
```

Fluxo GitOps (fase 1, com deploy manual de imagem): usuário builda e faz push
da imagem pro Docker Hub → edita a tag da imagem no `kustomization.yaml` do
serviço em `infra-platform/k8s/apps/<serviço>/` → commit/push →
ArgoCD detecta a mudança no Git e sincroniza o cluster automaticamente.
**O único comando manual contra o cluster, depois do bootstrap inicial, é o
`kubectl create secret`** — todo o resto (deploys, mudanças de config) passa
por commit no Git.

## Terraform (`infra-platform/terraform/`)

Provisiona a VPS do zero e deixa o cluster pronto para o ArgoCD assumir.

- **Provider**: `oci` (Oracle Cloud) — free tier permanente, VM Ampere A1
  (ARM). Pré-requisito manual (não automatizável): criar a conta OCI e gerar
  API keys — documentado em `terraform/README.md`.
- **Rede**: VCN, subnet pública, security list liberando `22` (SSH), a faixa
  de NodePort do k3s (`30000-32767`) e a porta da API do k8s (`6443`) restrita
  ao IP do usuário.
- **Compute**: uma instância Ampere A1, cloud-init instala o k3s
  (`curl -sfL https://get.k3s.io | sh -`) e sobe Postgres+MongoDB via
  `docker-compose` num systemd unit à parte do k8s.
- **Bootstrap do ArgoCD**: depois que o k3s responde, um `helm_release`
  (provider Helm do Terraform) instala o chart oficial do ArgoCD no
  namespace `argocd`.
- **Outputs**: IP público da VM e o `kubeconfig` (marcado como `sensitive`,
  nunca commitado) para o usuário configurar o `kubectl` local.

O Terraform cuida só da infraestrutura (VM, rede, k3s, ArgoCD instalado). Ele
**não** gerencia os manifests das aplicações — isso é 100% ArgoCD/Git.

## Kubernetes (`infra-platform/k8s/`)

Ferramenta: **Kustomize** (nativo do `kubectl`, sem linguagem de template
nova para aprender — só YAML + patches). Um único namespace de aplicação
(`solierrr`), para não introduzir multi-namespace/RBAC ainda.

```
k8s/
  base/
    api-java/            # Deployment+Service genérico p/ Spring Boot
    api-python/           # Deployment+Service genérico p/ Python
    web-app/               # Deployment+Service genérico p/ Vite/Node
  apps/
    api-auth/               # overlay: nome, imagem, env, porta específicos
    api-messenger/
    api-persistence/
    api-recommendation/
    ai-assistant/
    ai-validation/
    infra-gateway/          # + patch: Service tipo NodePort
    web-app/                # + patch: Service tipo NodePort
  argocd/
    root-app.yaml           # Application "app of apps" — único apply manual
    apps/
      api-auth-app.yaml      # uma Application por serviço, aponta p/ k8s/apps/<serviço>
      ...
```

Os 4 serviços Java reaproveitam `base/api-java`; os 3 Python reaproveitam
`base/api-python`. Isso significa: para adicionar um 9º serviço Java no
futuro, basta criar uma pasta em `k8s/apps/` com um `kustomization.yaml`
pequeno — não duplicar YAML inteiro.

**Padrão "app of apps"**: `root-app.yaml` é a única coisa aplicada
manualmente (`kubectl apply -f k8s/argocd/root-app.yaml`) no bootstrap. Ele
aponta para `k8s/argocd/apps/`, e o ArgoCD descobre e sincroniza cada
`Application` (uma por serviço) sozinho. Depois disso, adicionar/remover um
serviço do cluster é só adicionar/remover o arquivo `*-app.yaml`
correspondente e dar commit.

## Secrets

Cada serviço que precisa de segredo (JWT, chaves de API dos LLMs, senha de
banco) referencia um `Secret` do Kubernetes pelo nome
(`envFrom.secretRef` / `secretKeyRef`) dentro do seu overlay em
`k8s/apps/<serviço>/`. O `Secret` em si **não é criado pelo Kustomize nem pelo
ArgoCD** — é aplicado manualmente uma vez pelo usuário via
`kubectl create secret generic <nome> --from-literal=...`, com os comandos
exatos documentados por serviço (baseado nos `.env.example` já existentes em
cada repo). Isso evita segredo em texto puro no Git nesta fase.

## Banco de dados

Postgres e MongoDB rodam como containers Docker simples na própria VPS
(`docker-compose`, instalado pelo cloud-init do Terraform), **fora** do k3s.
Os pods dentro do cluster se conectam pelo IP interno da VM (mesma máquina).
A porta do banco (5432/27017) fica liberada no firewall só para a rede
interna do cluster, não para a internet.

## Registry de imagens

Docker Hub, com convenção de nome `<usuário-dockerhub>/solierrr-<serviço>`.
Nesta fase, a imagem é buildada e enviada manualmente
(`docker build && docker push`) pelo usuário; a automação disso é a Fase 2.

## Passos manuais (pré-requisitos, fora do código)

1. Criar conta Oracle Cloud + gerar API keys para o provider Terraform.
2. Criar conta/token no Docker Hub.
3. Gerar um par de chaves SSH para acesso à VM (se ainda não tiver).

## Critério de sucesso da fase 1

- `terraform apply` sobe a VPS, k3s e ArgoCD sem intervenção manual além dos
  pré-requisitos acima.
- `kubectl apply -f k8s/argocd/root-app.yaml` (uma vez) faz o ArgoCD
  sincronizar todos os 8 serviços automaticamente.
- `web-app` acessível pelo IP público da VPS, conseguindo falar com
  `infra-gateway`, que por sua vez fala com os demais serviços internos e com
  os bancos na VPS.
- Usuário consegue explicar, com as próprias palavras, o caminho
  "eu mudo um YAML → dou commit → o cluster muda sozinho" — esse é o
  entendimento central que a fase 1 precisa deixar claro.
