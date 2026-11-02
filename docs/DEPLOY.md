<p align="center">
  <img src="../assets/readme/banners/terraform.png" alt="Terraform" width="100%">
</p>

# Provisionamento

A aplicação do plano Terraform cria ou altera recursos reais, e o processo comum está em [PROD_GKE_ARGOCD.md](https://github.com/Solierrr/docs-warehouse/blob/main/readme/deploy/PROD_GKE_ARGOCD.md), sem uma URL única para este repositório.

Os charts versionados incluem Argo CD 10.4.2, Kong 3.4.1 e cert-manager 1.16.2. A composição usa valores do gateway na main por HTTP, portanto uma mudança nesse repositório pode alterar um plano posterior.

`bootstrap-gitops.ps1` configura o acesso ao cluster e aplica a Application raiz. `toggle-nodes.ps1` altera a contagem versionada, abre e faz merge de PR e pode executar apply. `set-cluster-state.ps1` versiona o marcador e também faz merge de PR antes de disparar verificações. Esses scripts não são validadores sem efeitos.

O marcador `ephemerality.json` informa se o cluster está ativo, porque o cluster de produção é efêmero e é desligado quando não precisa atender.
