output "public_ip" {
  description = "Public IP of the VM. Use it for SSH, kubectl, and to reach web-app/infra-gateway via NodePort."
  value       = oci_core_instance.cluster.public_ip
}

output "private_ip" {
  description = "Private IP of the VM. Use this (not public_ip or localhost) as the DB host in Secrets/ConfigMaps - Postgres/MongoDB listen here, reachable from pods on the same node."
  value       = oci_core_instance.cluster.private_ip
}

output "ssh_command" {
  description = "Command to SSH into the VM."
  value       = "ssh ubuntu@${oci_core_instance.cluster.public_ip}"
}

output "get_kubeconfig_command" {
  description = "Run this once cloud-init finishes to fetch a kubeconfig you can use locally. It rewrites the server address from 127.0.0.1 to the VM's public IP."
  value       = "ssh ubuntu@${oci_core_instance.cluster.public_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/${oci_core_instance.cluster.public_ip}/' > kubeconfig.yaml"
}

output "argocd_admin_password_command" {
  description = "Run this (with the kubeconfig above) to get the initial ArgoCD admin password."
  value       = "kubectl --kubeconfig kubeconfig.yaml -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "argocd_ui_port_forward_command" {
  description = "ArgoCD's UI isn't exposed publicly. Run this and open https://localhost:8080 to log in (user: admin)."
  value       = "kubectl --kubeconfig kubeconfig.yaml -n argocd port-forward svc/argocd-server 8080:443"
}
