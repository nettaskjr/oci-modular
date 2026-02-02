variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "compartment_ocid" {}
variable "fingerprint" {}
variable "region" {}
variable "api_private_key_path" {}

variable "ssh_public_key_path" {}
variable "user_instance" { default = "ubuntu" }
variable "instance_display_name" {}
variable "instance_shape" { default = "VM.Standard.A1.Flex" }
variable "instance_ocpus" { default = 4 }
variable "instance_memory_in_gbs" { default = 24 }
variable "boot_volume_size_in_gbs" { default = 50 }

variable "cloudflare_api_token" { sensitive = true }
variable "domain_name" {}
variable "github_repo" {}
variable "discord_webhook_url" { default = "" }
variable "cloudflared_version" { default = "2025.11.1" }
variable "grafana_admin_user" { default = "admin" }
variable "grafana_admin_password" { sensitive = true }
variable "db_password" { sensitive = true }
variable "minio_root_user" { default = "admin" }
variable "minio_root_password" { sensitive = true }
