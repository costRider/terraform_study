terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.3"
    }
  }

}

provider "local" {}

resource "local_file" "hello" {
  content  = "Hello, Terraform!"
  filename = "${path.module}/hello.txt"
}