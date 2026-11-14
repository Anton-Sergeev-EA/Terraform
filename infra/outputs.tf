output "repository" {
  value = local.repository
}

output "web_ip" {
  value = one(yandex_compute_instance.web[*].network_interface[0].nat_ip_address)
}

output "web_url" {
  value = var.image_tag == null ? null : "http://${one(yandex_compute_instance.web[*].network_interface[0].nat_ip_address)}"
}
