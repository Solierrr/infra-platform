<p align="center">
  <img src="../assets/readme/banners/terraform.png" alt="Terraform" width="100%">
</p>

# Preparação do cluster

A infraestrutura base é preparada antes das aplicações.

```mermaid
flowchart TD
 A[Credenciais e state] --> B[Plano revisado]
 B --> C[Aplica rede, cluster e controladores]
 C --> D[Cria configuração dos serviços]
 D --> E[Aplica raiz do GitOps]
 E --> F[Argo CD sincroniza aplicações]
```

Permissão insuficiente, rede não autorizada, segredo ausente e falha de chart impedem concluir a preparação. O [fluxo central](https://github.com/Solierrr/docs-warehouse/blob/main/docs/flows/RELEASE_AND_DEPLOY.md) contextualiza as aplicações.
