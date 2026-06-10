terraform {
  required_version = ">= 1.5"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    tls        = { source = "hashicorp/tls", version = "~> 4.0" }
    local      = { source = "hashicorp/local", version = "~> 2.5" }
    http       = { source = "hashicorp/http", version = "~> 3.4" } # Cần thêm provider này
  }
}

provider "aws" {
  region = var.aws_region
}

# Tự động lấy IP của người chạy để mở Security Group
data "http" "myip" {
 url = "https://checkip.amazonaws.com/"
}