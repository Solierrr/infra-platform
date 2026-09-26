<#
.SYNOPSIS
  Configura o kubectl local para o cluster solaria-gke e aplica o
  bootstrap/root-app.yaml do infra-gitops (app-of-apps), religando o ArgoCD
  nos manifests dos serviços. Necessário depois de todo cluster novo, já que
  o Terraform só sobe a plataforma (cluster, ArgoCD, Kong, cert-manager) -
  quem sincroniza os serviços de verdade (web-app, api-core etc.) é o
  ArgoCD, a partir da Application raiz. Idempotente: se o root-app já
  existir (ex. depois de um toggle-nodes que só reescala o node pool sem
  recriar o control plane), o kubectl apply não muda nada.

.EXAMPLE
  ./scripts/bootstrap-gitops.ps1
#>
$ErrorActionPreference = "Stop"

gcloud container clusters get-credentials solaria-gke --zone us-central1-a --project solaria-authenticator
kubectl apply -f https://raw.githubusercontent.com/Solierrr/infra-gitops/main/bootstrap/root-app.yaml
