output "db_internal_ip" {
  value = oci_core_instance.db_instance.private_ip
}

output "db_instance_id" {
  value = oci_core_instance.db_instance.id
}
