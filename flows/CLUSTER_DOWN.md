<p align="center">
  <img src="../assets/readme/banners/terraform.png" alt="Terraform" width="100%">
</p>

# Redução de nós

A redução muda a capacidade de executar aplicações sem equivaler à destruição de toda a infraestrutura.

```mermaid
flowchart TD
 A[Escolhe capacidade] --> B[Versiona node_count]
 B --> C[Aplica mudança revisada]
 C --> D[Pool reduzido]
 D --> E[Registra estado esperado]
```

Sem apply, a mudança no Git não altera a nuvem. Reduzir a zero interrompe workloads, mas não remove automaticamente control plane, endereços ou outros recursos cobrados. Falhas operacionais precisam ser conciliadas com o state.
