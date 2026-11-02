<p align="center">
  <img src="./assets/readme/banners/terraform.png" alt="Terraform" width="100%">
</p>

<p align="center">
  <img src="./assets/readme/stacks/gke.png" width="100" hspace="8" alt="GKE" title="GKE">
  <img src="./assets/readme/stacks/kubernetes.png" width="100" hspace="8" alt="Kubernetes" title="Kubernetes">
  <img src="./assets/readme/stacks/helm.png" width="100" hspace="8" alt="Helm" title="Helm">
  <img src="./assets/readme/stacks/argocd.png" width="100" hspace="8" alt="Argo CD" title="Argo CD">
  <img src="./assets/readme/stacks/infisical.png" width="100" hspace="8" alt="Infisical" title="Infisical">
  <img src="./assets/readme/stacks/cloudflare.png" width="100" hspace="8" alt="Cloudflare" title="Cloudflare">
</p>

# Infraestrutura base da plataforma

[![License](https://img.shields.io/github/license/Solierrr/infra-platform)](https://github.com/Solierrr/infra-platform/blob/main/LICENSE)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/Solierrr/infra-platform)](https://github.com/Solierrr/infra-platform/commits)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr/Solierrr/infra-platform)](https://github.com/Solierrr/infra-platform/pulls)
[![Release](https://img.shields.io/github/v/release/Solierrr/infra-platform)](https://github.com/Solierrr/infra-platform/releases)

Este repositório define a base de nuvem necessária para executar a plataforma. Ele organiza rede, cluster, entrada de tráfego, certificados, controle de acesso e distribuição de configuração. A equipe usa uma definição versionada para conhecer o que deve existir e planejar alterações antes de aplicá-las no ambiente.

O Terraform combina recursos do Google Cloud, Kubernetes, Helm, Infisical e Cloudflare. A instalação inicial prepara os controladores, enquanto o GitOps mantém as aplicações. Scripts de operação apoiam a criação e a redução do conjunto de máquinas e o registro do estado esperado, sem que esse registro substitua a observação do ambiente real.

## Aprofunde-se no Projeto!

- [OVERVIEW.md](./docs/OVERVIEW.md), finalidade e regras de produto.
- [ARCHITECTURE.md](./docs/ARCHITECTURE.md), componentes, dados e integrações.
- [RUNNING.md](./docs/RUNNING.md), preparação e execução local.
- [DEPLOY.md](./docs/DEPLOY.md), ambientes e publicação.
- [SECRETS.md](./docs/SECRETS.md), detalhes do fluxo ou modelo de dados.
- [STATUS.md](./docs/STATUS.md), limites observados.
- [Fluxos](./flows/), etapas e casos de erro do repositório.
- [PENDENCIAS.md](./PENDENCIAS.md), questões para revisão.

## Contribuindo

- [CONTRIBUTING.md](https://github.com/Solierrr/.github/blob/main/.github/CONTRIBUTING.md), convenções de contribuição.
- [CODE_OF_CONDUCT.md](https://github.com/Solierrr/.github/blob/main/CODE_OF_CONDUCT.md), código de conduta.
- [SECURITY.md](https://github.com/Solierrr/.github/blob/main/SECURITY.md), relato de vulnerabilidades.
