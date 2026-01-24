variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "compartment_ocid" {}
variable "fingerprint" {}
variable "region" {}
variable "api_private_key_path" {}

variable "cloudflare_api_token" {
  sensitive = true
}
variable "cloudflare_zone_id" {}
variable "cloudflare_account_id" {}

variable "instance_display_name" {
  description = "Usado para nomear o túnel"
}
