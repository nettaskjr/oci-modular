variable "state_bucket_name" {
  description = "Nome do bucket onde estão os states"
  type        = string
}

data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "terraform-state-oci/base.tfstate"
    region = "us-east-1"
  }
}

# Data source para obter Availability Domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# --- VOLUMES DE BLOCO (DADOS E ARQUIVOS) ---

# Volume para o PostgreSQL (50GB)
resource "oci_core_volume" "db_volume" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "${var.instance_display_name}-db-vol"
  size_in_gbs         = 50
}

# Volume para o MinIO (100GB)
resource "oci_core_volume" "minio_volume" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "${var.instance_display_name}-minio-vol"
  size_in_gbs         = 100
}
