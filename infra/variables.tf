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

variable "vm_platform_id" {
  description = "Платформа ВМ."
  type        = string
  default     = "standard-v3"
}

variable "vm_cores" {
  description = "Количество vCPU."
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Оперативная память ВМ в ГиБ."
  type        = number
  default     = 2
}

variable "vm_core_fraction" {
  description = "Гарантированная доля vCPU в процентах."
  type        = number
  default     = 20
}

variable "vm_preemptible" {
  description = "Прерываемая ВМ."
  type        = bool
  default     = true
}

variable "vm_disk_size" {
  description = "Размер загрузочного диска в ГиБ."
  type        = number
  default     = 15
}

variable "vm_disk_type" {
  description = "Тип загрузочного диска."
  type        = string
  default     = "network-hdd"
}

variable "vm_image_family" {
  description = "Семейство загрузочного образа."
  type        = string
  default     = "ubuntu-2404-lts"
}

variable "db_environment" {
  description = "Среда Managed MySQL."
  type        = string
  default     = "PRESTABLE"

  validation {
    condition     = contains(["PRESTABLE", "PRODUCTION"], var.db_environment)
    error_message = "Допустимые среды MySQL: PRESTABLE и PRODUCTION."
  }
}

variable "db_version" {
  description = "Версия MySQL."
  type        = string
  default     = "8.0"
}

variable "db_disk_type" {
  description = "Тип диска Managed MySQL."
  type        = string
  default     = "network-ssd"
}

variable "db_disk_size" {
  description = "Размер диска Managed MySQL в ГиБ."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Имя базы данных."
  type        = string
  default     = "web"
}

variable "db_user" {
  description = "Имя пользователя MySQL."
  type        = string
  default     = "web"
}
