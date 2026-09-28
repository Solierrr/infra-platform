ifeq ($(OS),Windows_NT)
ORG_SCRIPTS_DIR ?= $(USERPROFILE)/.local/share/solierrr-infra-scripts
ORG_SCRIPTS_POWERSHELL ?= powershell
else
ORG_SCRIPTS_DIR ?= $(HOME)/.local/share/solierrr-infra-scripts
ORG_SCRIPTS_POWERSHELL ?= pwsh
endif
ORG_SCRIPTS_REPO ?= https://github.com/Solierrr/infra-scripts.git
EXTRACT_ENV := $(ORG_SCRIPTS_DIR)/scripts/extract-env.ps1
SERVICE ?=
ENV ?=
OUT ?= .env



.DEFAULT_GOAL := help

.PHONY: help tools-check install login init plan apply destroy extract-env toggle-nodes check-environments vault-config vault-auth env

help: ## Show the available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\\n\\n"} /^[a-zA-Z_-]+:.*## / {printf "  %-16s %s\\n", $$1, $$2}' $(MAKEFILE_LIST)


install: ## Install the Terraform and platform command-line dependencies
	winget install --id Hashicorp.Terraform -e
	winget install --id Google.CloudSDK -e
	winget install --id GitHub.cli -e
	winget install --id infisical.infisical -e
	winget install --id Kubernetes.kubectl -e

login: ## Authenticate the Infisical CLI
	infisical login

init: ## Initialize Terraform providers and backend
	terraform init

plan: ## Show the proposed infrastructure changes
	powershell -NoProfile -ExecutionPolicy Bypass -Command ". ./scripts/ensure-secrets.ps1; terraform plan"

apply: ## Apply reviewed infrastructure changes
	powershell -NoProfile -ExecutionPolicy Bypass -Command ". ./scripts/ensure-secrets.ps1; terraform apply"
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-gitops.ps1
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/set-cluster-state.ps1 -Active true

destroy: ## Destroy all infrastructure
	powershell -NoProfile -ExecutionPolicy Bypass -Command ". ./scripts/ensure-secrets.ps1; terraform destroy"
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/set-cluster-state.ps1 -Active false


toggle-nodes: ## Set node-pool capacity (NODES=0, optionally APPLY=1)
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/toggle-nodes.ps1 -NodeCount $(NODES) $(if $(APPLY),-Apply)

check-environments: ## Re-trigger the environment status workflow on all app repos, without changing ephemerality.json
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/trigger-environment-checks.ps1

vault-config: ## Clone or update the shared infra-scripts toolkit
	$(ORG_SCRIPTS_POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/make-vault.ps1 -Action config -ScriptsDir "$(ORG_SCRIPTS_DIR)" -Repo "$(ORG_SCRIPTS_REPO)" -ExtractEnvPath "$(EXTRACT_ENV)"

vault-auth: vault-config ## Check that the Infisical CLI is installed and authenticated
	$(ORG_SCRIPTS_POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/make-vault.ps1 -Action auth

extract-env: vault-auth ## Generate a local environment file; prompts for missing service/environment
	$(ORG_SCRIPTS_POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/make-vault.ps1 -Action extract-env -ExtractEnvPath "$(EXTRACT_ENV)" -Service "$(SERVICE)" -Environment "$(ENV)" -OutputPath "$(OUT)"

tools-check: vault-config ## Alias for vault-config

env: extract-env ## Alias for extract-env
