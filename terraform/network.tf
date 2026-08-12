# Detects the machine running `terraform apply` public IP, so SSH and the
# Kubernetes API stay closed to the rest of the internet by default. Override
# with var.my_ip_override if this doesn't match (e.g. behind a VPN/proxy).
data "http" "my_ip" {
  url = "https://ifconfig.me/ip"
}

locals {
  my_ip_cidr = "${coalesce(var.my_ip_override, trimspace(data.http.my_ip.response_body))}/32"
}

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "solierrr-vcn"
  dns_label      = "solierrr"
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "solierrr-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "solierrr-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "solierrr-public-sl"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # SSH - only from your current IP
  ingress_security_rules {
    protocol = "6" # TCP
    source   = local.my_ip_cidr
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Kubernetes API - only from your current IP (kubectl runs from your machine)
  ingress_security_rules {
    protocol = "6"
    source   = local.my_ip_cidr
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # k3s NodePort range - public, this is how web-app/infra-gateway are reached
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 30000
      max = 32767
    }
  }

  ingress_security_rules {
    protocol = "1" # ICMP, useful for basic troubleshooting (ping)
    source   = "0.0.0.0/0"
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "solierrr-public-subnet"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false
}
