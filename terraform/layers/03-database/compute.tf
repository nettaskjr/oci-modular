# Buscar a imagem Ubuntu mais recente para AMD (x86_64)
data "oci_core_images" "ubuntu_amd_images" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.E2.1.Micro"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# NSG para o Banco de Dados
resource "oci_core_network_security_group" "db_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = data.terraform_remote_state.base.outputs.vcn_id
  display_name   = "db-postgres-nsg"
}

# Regra: Permitir 5432 APENAS vindo da rede interna (VCN)
resource "oci_core_network_security_group_security_rule" "db_rule_internal" {
  network_security_group_id = oci_core_network_security_group.db_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = "10.0.0.0/16"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      max = 5432
      min = 5432
    }
  }
}

resource "oci_core_instance" "db_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "db-postgres-amd"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = data.terraform_remote_state.base.outputs.public_subnet_id
    display_name     = "db-vnic"
    assign_public_ip = true
    nsg_ids          = [oci_core_network_security_group.db_nsg.id]
  }

  source_details {
    source_id               = data.oci_core_images.ubuntu_amd_images.images[0].id
    source_type             = "image"
    boot_volume_size_in_gbs = 50
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data = base64encode(templatefile("${path.module}/scripts/install_postgres.sh", {
      db_user             = var.db_user
      db_password         = var.db_password
      db_name             = var.db_name
      discord_webhook_url = var.discord_webhook_url
    }))
  }
}

# Data source para ADs
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}
