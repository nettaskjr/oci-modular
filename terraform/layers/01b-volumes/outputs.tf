output "db_volume_id" {
  value = oci_core_volume.db_volume.id
}

output "minio_volume_id" {
  value = oci_core_volume.minio_volume.id
}
