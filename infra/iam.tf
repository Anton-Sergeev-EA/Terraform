resource "yandex_iam_service_account" "web" {
  name = "${var.name_prefix}-vm"
}

resource "yandex_lockbox_secret_iam_member" "read" {
  secret_id = var.secret_id
  role      = "lockbox.payloadViewer"
  member    = "serviceAccount:${yandex_iam_service_account.web.id}"
}
