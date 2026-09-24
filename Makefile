SHELL := /bin/sh

ORG_SCRIPTS_DIR ?= $(HOME)/.local/share/solierrr-infra-scripts
ORG_SCRIPTS_POWERSHELL ?= powershell
EXTRACT_ENV := $(ORG_SCRIPTS_DIR)/scripts/extract-env.ps1
ENV ?= local
OUT ?= .env

.DEFAULT_GOAL := help

.PHONY: help tools-check install login init plan apply extract-env toggle-nodes

help: ## Show the available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\\n\\n"} /^[a-zA-Z_-]+:.*## / {printf "  %-16s %s\\n", $$1, $$2}' $(MAKEFILE_LIST)

tools-check: ## Verify that the shared organization scripts are installed
	@test -f "$(EXTRACT_ENV)" || { echo "error: infra-scripts was not found at $(ORG_SCRIPTS_DIR). See docs-warehouse/templates/make/README.md"; exit 1; }

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
	terraform plan

apply: ## Apply reviewed infrastructure changes
	terraform apply

extract-env: tools-check ## Generate an environment file (ENV=local SERVICE=api-core OUT=.env)
	$(ORG_SCRIPTS_POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File "$(EXTRACT_ENV)" -Environment "$(ENV)" $(if $(SERVICE),-Service "$(SERVICE)") -OutputPath "$(OUT)"

toggle-nodes: ## Set node-pool capacity (NODES=0, optionally APPLY=1)
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/toggle-nodes.ps1 -NodeCount $(NODES) $(if $(APPLY),-Apply)
