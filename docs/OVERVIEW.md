<p align="center">
  <img src="../assets/readme/banners/terraform.png" alt="Terraform" width="100%">
</p>

# Visão de produto

A infraestrutura base fornece o ambiente onde as aplicações funcionam. Ela reúne máquinas, rede, entrada pública, certificados e configuração por serviço.

A equipe reduz o número de máquinas quando o ambiente não precisa atender e o retoma depois, o que afeta a disponibilidade das aplicações. Enquanto o cluster está desligado, o `worker-failover` responde no lugar delas.
