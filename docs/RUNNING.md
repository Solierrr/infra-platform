<p align="center">
  <img src="../assets/readme/banners/terraform.png" alt="Terraform" width="100%">
</p>

# Validação e planejamento

Use Terraform 1.16 ou superior, Google Cloud CLI, `kubectl`, Helm e PowerShell para os utilitários. O guia comum está em [TERRAFORM.md](https://github.com/Solierrr/docs-warehouse/blob/main/readme/running/TERRAFORM.md).

O `make vault` exporta a pasta `/infisical`, e o carregamento das credenciais está descrito em `scripts/ensure-secrets.ps1`, que considera o ambiente, o arquivo local e a sessão do operador. Os arquivos de credenciais nunca devem entrar no Git.

| Comando | Efeito |
|---|---|
| `make install` | `terraform init -backend=false` |
| `make build` | `terraform validate` |
| `make lint` | Confere formatação recursiva |
| `make test` | Não tem comando configurado |
| `terraform plan` | Calcula alterações com as credenciais e o state selecionados |

O CI inicializa sem backend e valida. A validação de sintaxe não comprova permissões nem disponibilidade de recursos. Os scripts operacionais podem alterar Git, fazer merge e aplicar recursos. Leia os efeitos em [DEPLOY.md](./DEPLOY.md) antes de usá-los no fluxo operacional do repositório de origem.
