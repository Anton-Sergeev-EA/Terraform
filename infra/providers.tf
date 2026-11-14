terraform {
  required_version = "~> 1.12.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.244.0"
    }
  }
  backend "s3" {}
}

provider "yandex" {}
