#cloud-config
package_update: true
package_upgrade: false

packages:
  - ca-certificates
  - curl
  - gnupg

write_files:
  # Postgres + MongoDB run as plain Docker containers on this VM, outside
  # k3s, on purpose - see docs/superpowers/specs/2026-08-11-k8s-argocd-terraform-design.md
  - path: /opt/databases/docker-compose.yml
    permissions: '0600'
    content: |
      services:
        postgres:
          image: postgres:16
          restart: unless-stopped
          environment:
            POSTGRES_PASSWORD: "${postgres_password}"
          ports:
            - "5432:5432"
          volumes:
            - postgres-data:/var/lib/postgresql/data
        mongo:
          image: mongo:7
          restart: unless-stopped
          environment:
            MONGO_INITDB_ROOT_USERNAME: root
            MONGO_INITDB_ROOT_PASSWORD: "${mongo_root_password}"
          ports:
            - "27017:27017"
          volumes:
            - mongo-data:/data/db
      volumes:
        postgres-data:
        mongo-data:

  - path: /etc/systemd/system/databases.service
    permissions: '0644'
    content: |
      [Unit]
      Description=Postgres + MongoDB (docker compose)
      After=docker.service
      Requires=docker.service

      [Service]
      WorkingDirectory=/opt/databases
      ExecStart=/usr/bin/docker compose up
      ExecStop=/usr/bin/docker compose down
      Restart=always

      [Install]
      WantedBy=multi-user.target

runcmd:
  # --- Docker (only needed to run the databases above - k3s has its own container runtime) ---
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  - chmod a+r /etc/apt/keyrings/docker.asc
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
  - apt-get update -y
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  - systemctl enable --now docker
  - systemctl enable --now databases.service

  # --- k3s (single-node Kubernetes) ---
  - curl -sfL https://get.k3s.io | sh -
  - |
    tries=0
    until kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes --no-headers 2>/dev/null | awk '{print $2}' | grep -qx Ready; do
      tries=$((tries + 1))
      if [ "$tries" -ge 60 ]; then
        echo "k3s did not become Ready in time, continuing anyway - check 'kubectl get nodes' manually" >&2
        break
      fi
      sleep 5
    done

  # --- ArgoCD (official non-HA install manifest - simplest path to get started) ---
  - kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml create namespace argocd
  - kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  - kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml -n argocd rollout status deployment/argocd-server --timeout=300s
