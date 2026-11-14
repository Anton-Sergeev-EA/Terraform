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
