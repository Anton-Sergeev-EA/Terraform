resource "yandex_container_registry" "web" {
  name = var.name_prefix
}

resource "yandex_container_registry_iam_binding" "pull" {
  registry_id = yandex_container_registry.web.id
  role        = "container-registry.images.puller"
  members     = ["serviceAccount:${yandex_iam_service_account.web.id}"]
}
