# Buscar imagem Ubuntu AMD64
data "oci_core_images" "ubuntu_amd_images" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.E2.1.Micro"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# NSG para o MinIO
resource "oci_core_network_security_group" "minio_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = data.terraform_remote_state.base.outputs.vcn_id
  display_name   = "minio-storage-nsg"
}

# Regras Ingress para MinIO (API e Console)
resource "oci_core_network_security_group_security_rule" "minio_rule_api" {
  network_security_group_id = oci_core_network_security_group.minio_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "10.0.0.0/16"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      max = 9000
      min = 9000
    }
  }
}

resource "oci_core_network_security_group_security_rule" "minio_rule_console" {
  network_security_group_id = oci_core_network_security_group.minio_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "10.0.0.0/16"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      max = 9001
      min = 9001
    }
  }
}

resource "oci_core_instance" "minio_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "minio-storage-amd"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = data.terraform_remote_state.base.outputs.public_subnet_id
    display_name     = "minio-vnic"
    assign_public_ip = true
    nsg_ids          = [oci_core_network_security_group.minio_nsg.id]
  }

  source_details {
    source_id               = data.oci_core_images.ubuntu_amd_images.images[0].id
    source_type             = "image"
    boot_volume_size_in_gbs = 100
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data = base64encode(templatefile("${path.module}/scripts/install_minio.sh", {
      minio_root_user     = var.minio_root_user
      minio_root_password = var.minio_root_password
      discord_webhook_url = var.discord_webhook_url
    }))
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}
