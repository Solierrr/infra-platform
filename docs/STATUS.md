<p align="center">
  <img src="../assets/readme/banners/terraform.png" alt="Terraform" width="100%">
</p>

# Situação

Leitura da main em 2026-10-31.

- A configuração já foi dividida em módulos com blocos de migração de state.
- Secrets de acessibilidade e e-mail existem, e o nome de MCP já corresponde ao consumidor.
- O DNS do domínio raiz não é criado neste módulo, pois pertence ao Worker. O wildcard permanece separado de registros proxied de serviços.
- O endereço do Kong é reservado no Terraform, diferentemente de descrições antigas de IP sempre transitório.
- O pool declara seis nós na revisão consultada, e o marcador de ambiente indica se o cluster efêmero está ativo.
- Scripts de escala e estado contêm merge administrativo automático, que precisa ser considerado no processo de operação.
