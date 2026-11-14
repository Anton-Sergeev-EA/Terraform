data "yandex_compute_image" "ubuntu" {
  family = var.vm_image_family
}

resource "yandex_compute_instance" "web" {
  count              = var.image_tag == null ? 0 : 1
  name               = var.name_prefix
  zone               = var.zone
  platform_id        = var.vm_platform_id
  service_account_id = yandex_iam_service_account.web.id

  resources {
    cores         = var.vm_cores
    memory        = var.vm_memory
    core_fraction = var.vm_core_fraction
  }
  scheduling_policy {
    preemptible = var.vm_preemptible
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.vm_disk_size
      type     = var.vm_disk_type
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.web["app"].id
    security_group_ids = [yandex_vpc_security_group.web.id]
    nat                = true
  }

  metadata = {
    user-data = "#cloud-config\n${yamlencode({
      users = [{
        name                = "deploy"
        shell               = "/bin/bash"
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
        ssh_authorized_keys = [var.ssh_public_key]
      }]
      ssh_pwauth = false
      packages   = ["ca-certificates", "curl", "jq"]
      write_files = [
        { path = "/opt/yandex-web/compose.yaml", content = file("${path.module}/../compose.yaml") },
        { path = "/opt/yandex-web/settings", content = join("\n", [
          "APP_IMAGE=${local.repository}:${var.image_tag}",
          "DB_HOST=${one(yandex_mdb_mysql_cluster.web.host).fqdn}",
          "DB_NAME=${var.db_name}",
          "DB_USER=${yandex_mdb_mysql_user.web.name}",
          "SECRET_ID=${var.secret_id}",
          "SECRET_VERSION_ID=${var.secret_version_id}",
        ]) },
        { path = "/opt/yandex-web/install.sh", permissions = "0755", content = file("${path.module}/install.sh") },
        { path = "/opt/yandex-web/start.sh", permissions = "0755", content = file("${path.module}/start.sh") },
        { path = "/etc/systemd/system/yandex-web.service", content = file("${path.module}/yandex-web.service") },
      ]
      runcmd = [["/opt/yandex-web/install.sh"]]
    })}"
  }

  lifecycle {
    replace_triggered_by = [terraform_data.deployment]
  }

  depends_on = [yandex_container_registry_iam_binding.pull, yandex_lockbox_secret_iam_member.read]
}

resource "terraform_data" "deployment" {
  triggers_replace = sha256(jsonencode([
    var.image_tag, var.secret_id, var.secret_version_id, var.ssh_public_key,
    file("${path.module}/../compose.yaml"), file("${path.module}/install.sh"),
    file("${path.module}/start.sh"), file("${path.module}/yandex-web.service")
  ]))
}
