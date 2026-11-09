terraform {
  required_version = ">= 1.11"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.244.0"
    }
  }
  backend "s3" {}
}

provider "yandex" {}

variable "name_prefix" {
  type    = string
  default = "course-web"
}

variable "subnet_cidrs" {
  type = object({
    app = string
    db  = string
  })
  default = {
    app = "10.20.1.0/24"
    db  = "10.20.2.0/24"
  }
}

variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "ssh_cidr" {
  type = string
  validation {
    condition     = can(cidrnetmask(var.ssh_cidr)) && var.ssh_cidr != "0.0.0.0/0"
    error_message = "Укажите ограниченный IPv4 CIDR для SSH."
  }
}

variable "ssh_public_key" {
  type = string
}

variable "secret_id" {
  type = string
}

variable "secret_version_id" {
  type = string
}

variable "password_revision" {
  type    = number
  default = 1
}

variable "db_preset" {
  type = string
}

variable "image_tag" {
  type    = string
  default = null
  validation {
    condition     = var.image_tag == null ? true : can(regex("^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$", var.image_tag))
    error_message = "Укажите допустимый тег образа."
  }
}

locals {
  repository = "cr.yandex/${yandex_container_registry.web.id}/web"
  db_name    = "web"
  db_user    = "web"
}

resource "yandex_vpc_network" "web" {
  name = var.name_prefix
}

resource "yandex_vpc_subnet" "web" {
  for_each       = var.subnet_cidrs
  name           = "${var.name_prefix}-${each.key}"
  zone           = var.zone
  network_id     = yandex_vpc_network.web.id
  v4_cidr_blocks = [each.value]
}

resource "yandex_vpc_security_group" "web" {
  name       = var.name_prefix
  network_id = yandex_vpc_network.web.id
  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.ssh_cidr]
  }
  dynamic "ingress" {
    for_each = [80, 443]
    content {
      protocol       = "TCP"
      port           = ingress.value
      v4_cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "db" {
  name       = "${var.name_prefix}-db"
  network_id = yandex_vpc_network.web.id
  ingress {
    protocol          = "TCP"
    port              = 3306
    security_group_id = yandex_vpc_security_group.web.id
  }
}

resource "yandex_container_registry" "web" {
  name = var.name_prefix
}

resource "yandex_iam_service_account" "web" {
  name = "${var.name_prefix}-vm"
}

resource "yandex_container_registry_iam_binding" "pull" {
  registry_id = yandex_container_registry.web.id
  role        = "container-registry.images.puller"
  members     = ["serviceAccount:${yandex_iam_service_account.web.id}"]
}

resource "yandex_lockbox_secret_iam_member" "read" {
  secret_id = var.secret_id
  role      = "lockbox.payloadViewer"
  member    = "serviceAccount:${yandex_iam_service_account.web.id}"
}

resource "yandex_mdb_mysql_cluster" "web" {
  name               = var.name_prefix
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.web.id
  version            = "8.0"
  security_group_ids = [yandex_vpc_security_group.db.id]
  resources {
    resource_preset_id = var.db_preset
    disk_type_id       = "network-ssd"
    disk_size          = 20
  }
  host {
    zone             = var.zone
    subnet_id        = yandex_vpc_subnet.web["db"].id
    assign_public_ip = false
  }
}

resource "yandex_mdb_mysql_database" "web" {
  cluster_id = yandex_mdb_mysql_cluster.web.id
  name       = local.db_name
}

data "yandex_lockbox_secret_version" "db" {
  secret_id  = var.secret_id
  version_id = var.secret_version_id
}

resource "yandex_mdb_mysql_user" "web" {
  cluster_id          = yandex_mdb_mysql_cluster.web.id
  name                = local.db_user
  password_wo         = one([for entry in data.yandex_lockbox_secret_version.db.entries : entry.text_value if entry.key == "password"])
  password_wo_version = var.password_revision
  permission {
    database_name = yandex_mdb_mysql_database.web.name
    roles         = ["CREATE", "INSERT", "SELECT"]
  }
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts"
}

resource "yandex_compute_instance" "web" {
  count              = var.image_tag == null ? 0 : 1
  name               = var.name_prefix
  zone               = var.zone
  platform_id        = "standard-v3"
  service_account_id = yandex_iam_service_account.web.id

  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 15
      type     = "network-hdd"
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
          "DB_NAME=${local.db_name}",
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

output "repository" {
  value = local.repository
}

output "web_ip" {
  value = one(yandex_compute_instance.web[*].network_interface[0].nat_ip_address)
}

output "web_url" {
  value = var.image_tag == null ? null : "http://${one(yandex_compute_instance.web[*].network_interface[0].nat_ip_address)}"
}
