# infra-platform

Repositório central de padronização e infraestrutura da organização Solierrr.

## Estrutura

- `database/` — schemas SQL, triggers e diagramas (dbml) dos bancos Postgres e Mongo usados pelos serviços.
- `github/pr_templates/` — templates de pull request por tipo de repositório (`ai`, `backend`, `frontend`, `mobile`, `infra`).
- `github/rulesets/` — rulesets de branch protection e CI exportados do GitHub.
- `github/workflow/` — workflows de CI/CD reutilizáveis por stack, replicados para `.github/workflows/` de cada repositório:
  - `python/` — FastAPI (pytest + ruff + SonarQube).
  - `java/` — Spring Boot em Java, Maven (JUnit/JaCoCo ad-hoc + Checkstyle + SonarQube).
  - `kotlin/springboot/` — Spring Boot em Kotlin, Maven (JUnit/JaCoCo ad-hoc + ktlint + SonarQube).
  - `kotlin/jetpack-compose/` — app Android em Kotlin, Gradle (testes unitários + ktlint + SonarQube).
  - `typescript/` — React/Vite (build + testes + eslint + SonarQube).

  Cada stack segue o mesmo padrão de 4 workflows: `ci.yml` (build/testes), `quality.yml` (lint), `sonarqube.yml` (scan disparado após o CI, via `workflow_run`) e `release.yml` (placeholder).
- `templates/` — arquivos padrão de repositório para copiar em novos projetos:
  - `.editorconfig`, `.gitattributes` — genéricos, para qualquer stack.
  - `docker/<stack>/` — `Dockerfile` e `.dockerignore` de referência por stack (`python`, `jvm-maven` para Java/Kotlin+SpringBoot, `typescript`).

## Convenções usadas nos repositórios da org

- Licença MIT, `.gitignore`, `.gitattributes` e `.editorconfig` em todo repositório.
- SonarQube como gate de qualidade (`sonar-project.properties` na raiz de cada repo, projectKey `Solierrr_<repo>`).
- Commits em inglês, minúsculo, no formato `tipo: descrição` (`feat`, `fix`, `chore`, `refactor`, `ci`, `test`, `build`...).
- Branches por tipo de trabalho (`feat/`, `fix/`, `chore/`, `refactor/`...).
