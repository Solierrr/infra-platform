# Terraform - VPS + k3s + ArgoCD

Provisions a single Ampere A1 VM (Oracle Cloud Always Free tier), installs
k3s (lightweight Kubernetes) and ArgoCD on it, and runs Postgres/MongoDB as
plain Docker containers on the same VM, outside the cluster. Design
rationale: `../docs/superpowers/specs/2026-08-11-k8s-argocd-terraform-design.md`.

Terraform provisions the VM and kicks off the install via cloud-init; it does
**not** wait for k3s/ArgoCD to finish installing (that happens in the
background on first boot, takes 3-6 minutes). It also does not manage the
Kubernetes application manifests - that is ArgoCD's job, from `../k8s/`.

## One-time manual prerequisites

1. **Oracle Cloud account** (free): https://signup.oraclecloud.com
2. **API key for Terraform** - in the OCI Console: Profile icon -> User
   Settings -> API Keys -> Add API Key -> "Generate API Key Pair". Download
   the private key, and copy the config values it shows you
   (`tenancy`, `user`, `fingerprint`, `region`) into `terraform.tfvars`.
3. **SSH key pair** on your machine, if you don't already have one:
   `ssh-keygen -t ed25519`
4. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill it in.
   This file is gitignored - it holds real credentials, never commit it.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

`terraform apply` finishes in a minute or two (that's just the VM being
created). k3s + ArgoCD keep installing in the background afterwards. Wait
~5 minutes, then check progress:

```bash
ssh ubuntu@<public_ip> 'cloud-init status --wait'
```

Once that returns `status: done`:

```bash
# Fetch a local kubeconfig (also printed by `terraform output get_kubeconfig_command`)
terraform output -raw get_kubeconfig_command | sh

kubectl --kubeconfig kubeconfig.yaml get nodes
kubectl --kubeconfig kubeconfig.yaml -n argocd get pods
```

### Logging into the ArgoCD UI

ArgoCD isn't exposed publicly (only SSH, the Kubernetes API, and the k3s
NodePort range are open - see `network.tf`). Reach it through a tunnel:

```bash
terraform output -raw argocd_ui_port_forward_command | sh
# in another terminal:
terraform output -raw argocd_admin_password_command | sh
```

Open https://localhost:8080, log in as `admin` with that password.

### Bootstrapping the applications

Once ArgoCD is up, apply the single "app of apps" manifest once - from then
on, every service is managed by ArgoCD from Git:

```bash
kubectl --kubeconfig kubeconfig.yaml apply -f ../k8s/argocd/root-app.yaml
```

See `../k8s/README.md` for the required secrets you must create by hand
before the apps will actually start.

## Destroying everything

```bash
terraform destroy
```

This deletes the VM (and with it, the databases' data - there's no backup
mechanism in phase 1).
