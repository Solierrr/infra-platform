<p align="center">
  <img src="../assets/readme/banners/terraform.png" alt="Terraform" width="100%">
</p>

# Configuração dos serviços

O módulo de vault lê pastas do Infisical em produção e monta Secrets no namespace dos consumidores. Não há valores de credenciais nesta documentação.

Os nomes de Secrets declarados no módulo incluem os seguintes itens.

- `api-messenger-secrets`.
- `api-notify-secrets`.
- `api-core-secrets`.
- `api-auth-secrets`.
- `api-auth-jwt-keystore`.
- `api-recommendation-secrets`.
- `mcp-database-secrets`.
- `ai-assistant-secrets`.
- `ai-validation-secrets`.
- `google-registry-secrets`.
- `feeddb-secrets`.
- `database-bootstrap-secrets`.
- `ai-accessibility-secrets`.
- `ai-geographic-secrets`.
- `ai-operational-secrets`.
- `api-email-secrets`.
- `infra-broker-secrets`.
- `infra-grafana-secrets`.
- `grafana-cloud-otlp`.

As definições atuais já incluem acessibilidade, e-mail e `mcp-database-secrets`, corrigindo as ausências e o nome divergente registrados no checklist antigo. O Secret do coletor fica no namespace do overlay correspondente. A existência de um bloco Terraform não comprova que ele já foi aplicado.
