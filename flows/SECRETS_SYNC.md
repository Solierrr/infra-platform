<p align="center">
  <img src="../assets/readme/banners/terraform.png" alt="Terraform" width="100%">
</p>

# Sincronização de configuração

O plano lê configuração autorizada do cofre e materializa os Secrets usados pelas aplicações.

```mermaid
flowchart LR
 I[Infisical prod] --> V[Módulo vault]
 V --> P[Plano Terraform]
 P --> S[Secrets nos namespaces]
 S --> A[Aplicações consumidoras]
```

Credencial sem acesso à pasta, nome divergente e namespace incorreto impedem o consumo. Os conteúdos não devem aparecer nos documentos ou commits.
