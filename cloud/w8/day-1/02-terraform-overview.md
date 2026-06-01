# Terraform Overview

## What is Terraform

Terraform là công cụ Infrastructure as Code do HashiCorp phát triển.

Terraform cho phép:

- Provision Infrastructure
- Manage Infrastructure
- Version Infrastructure

---

## Supported Platforms

Terraform có thể quản lý:

- AWS
- Azure
- GCP
- Kubernetes
- Docker
- GitHub

---

## Terraform Architecture

Developer
    |
Terraform CLI
    |
Provider
    |
Cloud API
    |
Resources

Ví dụ:

Developer
    |
terraform apply
    |
AWS Provider
    |
AWS API
    |
EC2 Instance

---

## Terraform Files

main.tf
variables.tf
outputs.tf
terraform.tfvars
terraform.tfstate