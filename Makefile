.PHONY: install login init plan apply extract-env toggle-nodes

install:
	winget install --id Hashicorp.Terraform -e
	winget install --id Google.CloudSDK -e
	winget install --id GitHub.cli -e
	winget install --id infisical.infisical -e
	winget install --id Kubernetes.kubectl -e

login:
	infisical login

init:
	terraform init

plan:
	terraform plan

apply:
	terraform apply

# make extract-env ENV=local [SERVICE=api-core] [OUT=.env]
# sem SERVICE, extrai a uniao de todas as pastas de todos os servicos mapeados.
extract-env:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/extract-env.ps1 -e $(if $(ENV),$(ENV),local) $(if $(SERVICE),-s $(SERVICE)) $(if $(OUT),-o $(OUT))

# make toggle-nodes NODES=0 [APPLY=1]
toggle-nodes:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/toggle-nodes.ps1 -NodeCount $(NODES) $(if $(APPLY),-Apply)
