# Kubernetes - Kustomize + ArgoCD

Design rationale: `../docs/superpowers/specs/2026-08-11-k8s-argocd-terraform-design.md`.

```
k8s/
  base/            # generic Deployment+Service per stack (api-java, api-python, web-app)
  apps/            # one overlay per service - image, env, NodePort/ClusterIP
  argocd/
    root-app.yaml       # the ONLY manifest you apply by hand
    apps/*-app.yaml      # one ArgoCD Application per service, picked up by root-app.yaml
```

After this, the flow is: edit a YAML under `k8s/` -> commit -> push -> ArgoCD notices and
syncs the cluster automatically. The only exceptions are Secrets (never
committed, see below) and the one-time `kubectl apply -f argocd/root-app.yaml`.

## Before you deploy anything

1. **Replace the image placeholder.** Every `k8s/apps/*/kustomization.yaml`
   has `SEU_USUARIO_DOCKERHUB` in the `images:` section - swap it for your
   real Docker Hub username in all 8 files, then build and push each image:
   ```bash
   docker build -t <usuario>/solierrr-api-auth:latest api-auth/
   docker push <usuario>/solierrr-api-auth:latest
   ```
   (repeat per service; automating this build/push is explicitly out of
   scope for phase 1 - see the design doc)

2. **Get the VM's private IP** (needed for DB connection strings):
   ```bash
   cd ../terraform && terraform output private_ip
   ```

## Known issues per service (found while surveying the repos)

Fix these in each service's own repo whenever you get to it - not blocking
for standing up the k8s/ArgoCD plumbing itself, but the pod for that service
will crash-loop until fixed:

| Service | Issue |
|---|---|
| `infra-gateway` | Repo is an empty skeleton (no `requirements.txt`, no source). Dockerfile won't build. |
| `api-recommendation` | Dockerfile is a leftover copy of the Java template; the actual app is Python/FastAPI+Neo4j with no source code yet. Won't build. |
| `ai-assistant` | Dockerfile has no `CMD`/`ENTRYPOINT`, and `main.py` is currently an interactive CLI loop, not an HTTP server. Container exits immediately. |
| `ai-validation` | Dockerfile has no `CMD` to start `uvicorn`, and `fastapi`/`uvicorn` aren't pinned in `requirements.txt` even though `main.py` uses them. Container exits immediately. |
| `api-auth`, `api-messenger`, `api-persistence` | None include `spring-boot-starter-actuator`, so there's no real HTTP health endpoint yet - the Deployments use TCP-only probes for now. |

## Bootstrap (once)

```bash
kubectl --kubeconfig ../terraform/kubeconfig.yaml apply -f argocd/root-app.yaml
```

This makes ArgoCD sync `argocd/apps/*.yaml`, which in turn sync each
service's overlay. Every service will show `CrashLoopBackOff` until you (a)
push a real image for it and (b) create its Secret/ConfigMap below.

## Secrets and ConfigMaps (applied by hand, never committed)

Only 3 of the 8 services need env vars right now.

### api-auth

```bash
kubectl create secret generic api-auth-secrets -n solierrr \
  --from-literal=JWT_SECRET='<gere um valor aleatorio longo>' \
  --from-literal=DB_URL='jdbc:postgresql://<VM_PRIVATE_IP>:5432/solaria_auth' \
  --from-literal=DB_USERNAME='postgres' \
  --from-literal=DB_PASSWORD='<a mesma senha que voce colocou em terraform.tfvars, postgres_password>'

kubectl create configmap api-auth-config -n solierrr \
  --from-literal=JWT_ISSUER='solaria-auth' \
  --from-literal=JWT_ACCESS_TOKEN_TTL='PT15M' \
  --from-literal=JWT_REFRESH_TOKEN_TTL='P7D' \
  --from-literal=FIREBASE_ENABLED='false' \
  --from-literal=FIREBASE_PROJECT_ID='<opcional, so se FIREBASE_ENABLED=true>'
```

Note: the Postgres container only ever creates the default `postgres`
database - you still need to create `solaria_auth` yourself once, e.g.:
```bash
ssh ubuntu@<public_ip> "docker exec -it \$(docker ps -qf name=postgres) psql -U postgres -c 'CREATE DATABASE solaria_auth;'"
```

### ai-assistant

```bash
kubectl create secret generic ai-assistant-secrets -n solierrr \
  --from-literal=GOOGLE_API_KEY='<sua chave>' \
  --from-literal=GROQ_API_KEY='<sua chave>'

kubectl create configmap ai-assistant-config -n solierrr \
  --from-literal=MONGODB_URI='mongodb://root:<mongo_root_password do terraform.tfvars>@<VM_PRIVATE_IP>:27017' \
  --from-literal=MONGO_DB='assessor_inteligente'
```
(`MONGODB_URI` is what the code actually reads - kept in the ConfigMap
rather than the Secret only because this is a learning environment; move it
to the Secret if you'd rather not have the Mongo password there in plain
text.)

### ai-validation

```bash
kubectl create secret generic ai-validation-secrets -n solierrr \
  --from-literal=GEMINI_API_KEY='<sua chave>' \
  --from-literal=GEMINI_API_KEY2='<opcional>' \
  --from-literal=GEMINI_API_KEY3='<opcional>' \
  --from-literal=GROQ_API_KEY='<sua chave>' \
  --from-literal=GROQ_API_KEY2='<opcional>'

kubectl create configmap ai-validation-config -n solierrr \
  --from-literal=LLM_MODEL='gemini-2.5-flash' \
  --from-literal=LLM_TEMPERATURE='0.0'
```

`api-messenger`, `api-persistence`, `api-recommendation`, `infra-gateway`,
and `web-app` need no Secret/ConfigMap right now - none of them read any
env var today.

## Everyday use

```bash
kubectl --kubeconfig ../terraform/kubeconfig.yaml -n solierrr get pods
kubectl --kubeconfig ../terraform/kubeconfig.yaml -n solierrr logs deploy/api-auth-app
```

To add a 9th service later: copy the closest overlay under `k8s/apps/`,
adjust `namePrefix`/`commonLabels`/`images`, add its `*-app.yaml` under
`k8s/argocd/apps/`, commit, push. ArgoCD does the rest.
