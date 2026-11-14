resource "yandex_mdb_mysql_cluster" "web" {
  name               = var.name_prefix
  environment        = var.db_environment
  network_id         = yandex_vpc_network.web.id
  version            = var.db_version
  security_group_ids = [yandex_vpc_security_group.db.id]
  resources {
    resource_preset_id = var.db_preset
    disk_type_id       = var.db_disk_type
    disk_size          = var.db_disk_size
  }
  host {
    zone             = var.zone
    subnet_id        = yandex_vpc_subnet.web["db"].id
    assign_public_ip = false
  }
}

resource "yandex_mdb_mysql_database" "web" {
  cluster_id = yandex_mdb_mysql_cluster.web.id
  name       = var.db_name
}

data "yandex_lockbox_secret_version" "db" {
  secret_id  = var.secret_id
  version_id = var.secret_version_id
}

resource "yandex_mdb_mysql_user" "web" {
  cluster_id          = yandex_mdb_mysql_cluster.web.id
  name                = var.db_user
  password_wo         = one([for entry in data.yandex_lockbox_secret_version.db.entries : entry.text_value if entry.key == "password"])
  password_wo_version = var.password_revision
  permission {
    database_name = yandex_mdb_mysql_database.web.name
    roles         = ["CREATE", "INSERT", "SELECT"]
  }
}
