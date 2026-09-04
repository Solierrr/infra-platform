# infra-platform

Este é o repositório que define, via Terraform, a infraestrutura base da organização Solierrr no Google Cloud: a VPC, o cluster GKE, o node pool que sustenta as cargas de trabalho, e a instalação inicial do ArgoCD, do Kong e do cert-manager dentro desse cluster. Diferente de um repositório de aplicação, aqui não existe "build" ou "deploy" no sentido tradicional — o artefato final é o próprio estado da infraestrutura na nuvem, gerenciado pelo state do Terraform. Um ponto central da arquitetura é o conceito de **cluster efêmero**: como o GKE é cobrado por node ativo, o cluster é pensado para subir e ser derrubado sob demanda (fora de sessões de estudo/uso), com um script dedicado para zerar o node pool sem destruir o control plane nem recursos como o IP público do Kong.

<p>

[![License](https://img.shields.io/github/license/Solierrr/infra-platform)](https://github.com/Solierrr/infra-platform/blob/main/LICENSE)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/Solierrr/infra-platform)](https://github.com/Solierrr/infra-platform/commits)
[![GitHub Issues](https://img.shields.io/github/issues/Solierrr/infra-platform)](https://github.com/Solierrr/infra-platform/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr/Solierrr/infra-platform)](https://github.com/Solierrr/infra-platform/pulls)
[![GitHub Contributors](https://img.shields.io/github/contributors/Solierrr/infra-platform)](https://github.com/Solierrr/infra-platform/graphs/contributors)
[![Release](https://img.shields.io/github/v/release/Solierrr/infra-platform)](https://github.com/Solierrr/infra-platform/releases)

</p>

<div align="center">

<p>
  <a href="https://github.com/syvixor/skills-icons">
    <img src="https://skills.syvixor.com/api/icons?i=terraform,gcp,kubernetes,powershell" height="48" alt="Cloud & Infrastructure">
  </a>
</p>

<p>

[![Terraform](https://img.shields.io/badge/Terraform-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Google Cloud](https://img.shields.io/badge/Google_Cloud-4285F4?logo=googlecloud&logoColor=white)](https://cloud.google.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)

</p>

</div>

## Aprofunde-se no Projeto!

- [ARCHITECTURE.md](./ARCHITECTURE.md), estrutura do repositório e explicação dos recursos definidos em cada arquivo `.tf`.
- [RUNNING.md](./RUNNING.md), como rodar `terraform plan`/`apply` localmente e usar os scripts PowerShell auxiliares.
- [DEPLOYMENT.md](https://github.com/Solierrr/docs-warehouse/blob/main/.github/DEPLOYMENT.md), papel deste repositório no fluxo de deploy da organização.

## Contribuindo

- [.github/CONTRIBUTING.md](./.github/CONTRIBUTING.md), convenções de commit, branch e Pull Request.
- CODE_OF_CONDUCT.md, código de conduta do projeto ({a confirmar}, ainda não existe neste repositório).
- SECURITY.md, como reportar vulnerabilidades de segurança ({a confirmar}, ainda não existe neste repositório).
