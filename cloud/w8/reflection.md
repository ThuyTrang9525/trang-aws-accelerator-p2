# W8 Day 1 - Terraform Fundamentals (IaC Overview + HCL Syntax)

**Date:** 01/06/2026
**Track:** Cloud / DevOps Phase 2
**Topic:** Terraform Part 1 - Infrastructure as Code (IaC) & HCL Fundamentals# Terraform Foundation Notes

## W8 Day 1 - Terraform Fundamentals

**Date:** 01/06/2026

---

# 1. Infrastructure as Code (IaC)

## Infrastructure là gì?

Infrastructure là toàn bộ tài nguyên cần thiết để vận hành một ứng dụng.

Ví dụ trên AWS:

* VPC
* Subnet
* Route Table
* Internet Gateway
* Security Group
* EC2
* RDS
* S3
* Load Balancer

Ví dụ kiến trúc đơn giản:

```text
Internet
    ↓
Load Balancer
    ↓
EC2
    ↓
RDS
    ↓
S3
```

---

## Infrastructure as Code là gì?

Infrastructure as Code (IaC) là phương pháp quản lý và triển khai hạ tầng bằng code thay vì thao tác thủ công trên giao diện web.

### Cách làm truyền thống

Cloud Engineer phải:

1. Login AWS Console
2. Tạo VPC
3. Tạo Subnet
4. Tạo EC2
5. Tạo RDS

Nhược điểm:

* Tốn thời gian
* Dễ sai sót
* Khó tái sử dụng
* Không có version control
* Khó review thay đổi

---

### Cách làm với IaC

Ví dụ:

```hcl
resource "aws_instance" "web" {
  instance_type = "t2.micro"
}
```

Lợi ích:

* Tự động hóa
* Version Control
* Reusable
* Consistency
* Auditability
* Collaboration

---

# 2. Terraform

## Terraform là gì?

Terraform là công cụ Infrastructure as Code do HashiCorp phát triển.

Terraform giúp:

* Tạo hạ tầng
* Cập nhật hạ tầng
* Xóa hạ tầng

Terraform hỗ trợ:

* AWS
* Azure
* GCP
* Kubernetes
* Docker
* GitHub
* Cloudflare

---

## Terraform là Declarative

Terraform sử dụng mô hình Declarative.

Thay vì:

```text
Bước 1: Tạo EC2
Bước 2: Gắn Security Group
Bước 3: Gắn EBS
```

Ta mô tả trạng thái mong muốn:

```hcl
resource "aws_instance" "web" {
}
```

Terraform sẽ tự tính toán thứ tự thực hiện.

---

## Terraform Architecture

```text
Developer
    ↓
Terraform Configuration
    ↓
Terraform CLI
    ↓
Provider
    ↓
Cloud API
    ↓
Infrastructure
```

Ví dụ:

```text
terraform apply
        ↓
AWS Provider
        ↓
AWS API
        ↓
EC2 Instance
```

---

# 3. HCL (HashiCorp Configuration Language)

Terraform sử dụng HCL để khai báo hạ tầng.

## Cấu trúc cơ bản

```hcl
block_type "label1" "label2" {
  argument = value
}
```

Ví dụ:

```hcl
resource "aws_instance" "web" {
  instance_type = "t2.micro"
}
```

---

## terraform Block

Dùng để cấu hình Terraform.

```hcl
terraform {
  required_version = ">= 1.6.0"
}
```

Ý nghĩa:

* Khai báo version Terraform tối thiểu.

---

## required_providers

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

Ý nghĩa:

* Chỉ định provider cần dùng.
* Chỉ định version provider.

---

## provider Block

Dùng để cấu hình kết nối tới nền tảng.

Ví dụ:

```hcl
provider "aws" {
  region = "ap-southeast-1"
}
```

Provider chịu trách nhiệm giao tiếp với AWS API.

---

## resource Block

Resource là đối tượng hạ tầng được Terraform quản lý.

Ví dụ:

```hcl
resource "aws_s3_bucket" "learning" {
  bucket = "my-learning-bucket"
}
```

Cấu trúc:

```text
resource
    ↓
aws_s3_bucket
    ↓
learning
```

Trong đó:

* aws_s3_bucket = loại resource
* learning = tên logic

---

## variable Block

Khai báo dữ liệu đầu vào.

```hcl
variable "environment" {
  type = string
}
```

Sử dụng:

```hcl
bucket = "${var.environment}-bucket"
```

Ví dụ:

```text
environment = dev
```

Kết quả:

```text
dev-bucket
```

---

## locals Block

Biến nội bộ.

```hcl
locals {
  project_name = "aws-accelerator"
}
```

Sử dụng:

```hcl
local.project_name
```

---

## output Block

Hiển thị kết quả sau khi apply.

```hcl
output "bucket_name" {
  value = aws_s3_bucket.learning.bucket
}
```

Ví dụ:

```text
bucket_name = my-learning-bucket
```

---

## data Block

Dùng để đọc dữ liệu có sẵn.

Ví dụ:

```hcl
data "aws_caller_identity" "current" {}
```

Có thể dùng để lấy:

* Account ID
* Existing Resources
* Existing AMI

---

# 4. Terraform Workflow

## Terraform Lifecycle

```text
Write Configuration
        ↓
terraform init
        ↓
terraform validate
        ↓
terraform plan
        ↓
terraform apply
        ↓
terraform.tfstate Updated
```

---

## terraform init

Mục đích:

* Khởi tạo project
* Download provider
* Download module

Lệnh:

```bash
terraform init
```

Sau khi chạy:

```text
.terraform/
```

được tạo ra.

---

## terraform fmt

Format code Terraform.

```bash
terraform fmt
```

Giúp code thống nhất format.

---

## terraform validate

Kiểm tra syntax.

```bash
terraform validate
```

Không tạo resource.

---

## terraform plan

Terraform thực hiện:

1. Đọc code
2. Đọc state
3. So sánh

Ví dụ:

```text
Current State:
0 EC2

Desired State:
1 EC2
```

Plan:

```text
+ create EC2
```

Lệnh:

```bash
terraform plan
```

---

## terraform apply

Thực thi thay đổi.

```bash
terraform apply
```

Terraform gọi API thật để tạo resource.

---

## terraform destroy

Xóa toàn bộ resource do Terraform quản lý.

```bash
terraform destroy
```

---

# 5. Terraform State Management

## State là gì?

Terraform lưu trạng thái hạ tầng vào:

```text
terraform.tfstate
```

---

## State chứa gì?

* Resource IDs
* Resource Attributes
* Dependency Graph
* Current Infrastructure Status

---

## Tại sao Terraform cần State?

Terraform cần biết:

```text
Resource nào đã tồn tại?
```

Ví dụ:

Apply lần đầu:

```text
EC2 created
```

Apply lần hai:

```text
terraform apply
```

Terraform đọc:

```text
terraform.tfstate
```

và biết EC2 đã tồn tại.

---

## Local State

Lưu trực tiếp:

```text
terraform.tfstate
```

trên máy local.

Phù hợp:

* Learning
* Personal Project

---

## Remote State

Production thường dùng:

```text
AWS S3
+
DynamoDB Locking
```

Ví dụ:

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "prod.tfstate"
    region = "ap-southeast-1"
  }
}
```

Lợi ích:

* Backup
* Team Sharing
* Versioning
* Locking

---

# 6. Terraform Modules

## Module là gì?

Module là tập hợp các file Terraform có thể tái sử dụng.

Ví dụ:

```text
modules/
└── ec2/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

---

## Gọi Module

```hcl
module "web_server" {
  source = "./modules/ec2"

  instance_type = "t3.micro"
}
```

---

## Lợi ích của Module

* Reusable
* Maintainable
* Consistent
* Scalable

---

## Cấu trúc chuẩn của Module

```text
modules/ec2/
├── main.tf
├── variables.tf
└── outputs.tf
```

---

# 7. Terraform Best Practices

## Không Hard-code

Sai:

```hcl
bucket = "mybucket"
```

Đúng:

```hcl
bucket = var.bucket_name
```

---

## Tách file rõ ràng

```text
main.tf
variables.tf
outputs.tf
providers.tf
versions.tf
```

---

## Luôn chạy

```bash
terraform fmt
terraform validate
terraform plan
```

trước khi:

```bash
terraform apply
```

---

## Sử dụng Module

Tránh copy-paste code.

---

## Không commit State File

.gitignore:

```gitignore
.terraform/
terraform.tfstate
terraform.tfstate.backup
```

---

## Dùng Remote State cho Production

Khuyến nghị:

```text
S3 + DynamoDB Lock
```

---

## Đặt Naming Convention

Ví dụ:

```text
dev-web-ec2
staging-web-ec2
prod-web-ec2
```

---

# Câu hỏi thường gặp trong bài Test

## Terraform là Declarative hay Imperative?

Declarative.

---

## terraform plan có tạo resource không?

Không.

---

## terraform apply làm gì?

Thực thi thay đổi.

---

## Terraform lưu trạng thái ở đâu?

terraform.tfstate

---

## Provider dùng để làm gì?

Kết nối Terraform với nền tảng bên ngoài.

---

## Resource là gì?

Đối tượng hạ tầng được Terraform quản lý.

---

## Module dùng để làm gì?

Tái sử dụng code.

---

## Production nên dùng Local State hay Remote State?

Remote State.
# Terraform Foundation Notes

## W8 Day 1 - Terraform Fundamentals

**Date:** 01/06/2026

---

# 1. Infrastructure as Code (IaC)

## Infrastructure là gì?

Infrastructure là toàn bộ tài nguyên cần thiết để vận hành một ứng dụng.

Ví dụ trên AWS:

* VPC
* Subnet
* Route Table
* Internet Gateway
* Security Group
* EC2
* RDS
* S3
* Load Balancer

Ví dụ kiến trúc đơn giản:

```text
Internet
    ↓
Load Balancer
    ↓
EC2
    ↓
RDS
    ↓
S3
```

---

## Infrastructure as Code là gì?

Infrastructure as Code (IaC) là phương pháp quản lý và triển khai hạ tầng bằng code thay vì thao tác thủ công trên giao diện web.

### Cách làm truyền thống

Cloud Engineer phải:

1. Login AWS Console
2. Tạo VPC
3. Tạo Subnet
4. Tạo EC2
5. Tạo RDS

Nhược điểm:

* Tốn thời gian
* Dễ sai sót
* Khó tái sử dụng
* Không có version control
* Khó review thay đổi

---

### Cách làm với IaC

Ví dụ:

```hcl
resource "aws_instance" "web" {
  instance_type = "t2.micro"
}
```

Lợi ích:

* Tự động hóa
* Version Control
* Reusable
* Consistency
* Auditability
* Collaboration

---

# 2. Terraform

## Terraform là gì?

Terraform là công cụ Infrastructure as Code do HashiCorp phát triển.

Terraform giúp:

* Tạo hạ tầng
* Cập nhật hạ tầng
* Xóa hạ tầng

Terraform hỗ trợ:

* AWS
* Azure
* GCP
* Kubernetes
* Docker
* GitHub
* Cloudflare

---

## Terraform là Declarative

Terraform sử dụng mô hình Declarative.

Thay vì:

```text
Bước 1: Tạo EC2
Bước 2: Gắn Security Group
Bước 3: Gắn EBS
```

Ta mô tả trạng thái mong muốn:

```hcl
resource "aws_instance" "web" {
}
```

Terraform sẽ tự tính toán thứ tự thực hiện.

---

## Terraform Architecture

```text
Developer
    ↓
Terraform Configuration
    ↓
Terraform CLI
    ↓
Provider
    ↓
Cloud API
    ↓
Infrastructure
```

Ví dụ:

```text
terraform apply
        ↓
AWS Provider
        ↓
AWS API
        ↓
EC2 Instance
```

---

# 3. HCL (HashiCorp Configuration Language)

Terraform sử dụng HCL để khai báo hạ tầng.

## Cấu trúc cơ bản

```hcl
block_type "label1" "label2" {
  argument = value
}
```

Ví dụ:

```hcl
resource "aws_instance" "web" {
  instance_type = "t2.micro"
}
```

---

## terraform Block

Dùng để cấu hình Terraform.

```hcl
terraform {
  required_version = ">= 1.6.0"
}
```

Ý nghĩa:

* Khai báo version Terraform tối thiểu.

---

## required_providers

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

Ý nghĩa:

* Chỉ định provider cần dùng.
* Chỉ định version provider.

---

## provider Block

Dùng để cấu hình kết nối tới nền tảng.

Ví dụ:

```hcl
provider "aws" {
  region = "ap-southeast-1"
}
```

Provider chịu trách nhiệm giao tiếp với AWS API.

---

## resource Block

Resource là đối tượng hạ tầng được Terraform quản lý.

Ví dụ:

```hcl
resource "aws_s3_bucket" "learning" {
  bucket = "my-learning-bucket"
}
```

Cấu trúc:

```text
resource
    ↓
aws_s3_bucket
    ↓
learning
```

Trong đó:

* aws_s3_bucket = loại resource
* learning = tên logic

---

## variable Block

Khai báo dữ liệu đầu vào.

```hcl
variable "environment" {
  type = string
}
```

Sử dụng:

```hcl
bucket = "${var.environment}-bucket"
```

Ví dụ:

```text
environment = dev
```

Kết quả:

```text
dev-bucket
```

---

## locals Block

Biến nội bộ.

```hcl
locals {
  project_name = "aws-accelerator"
}
```

Sử dụng:

```hcl
local.project_name
```

---

## output Block

Hiển thị kết quả sau khi apply.

```hcl
output "bucket_name" {
  value = aws_s3_bucket.learning.bucket
}
```

Ví dụ:

```text
bucket_name = my-learning-bucket
```

---

## data Block

Dùng để đọc dữ liệu có sẵn.

Ví dụ:

```hcl
data "aws_caller_identity" "current" {}
```

Có thể dùng để lấy:

* Account ID
* Existing Resources
* Existing AMI

---

# 4. Terraform Workflow

## Terraform Lifecycle

```text
Write Configuration
        ↓
terraform init
        ↓
terraform validate
        ↓
terraform plan
        ↓
terraform apply
        ↓
terraform.tfstate Updated
```

---

## terraform init

Mục đích:

* Khởi tạo project
* Download provider
* Download module

Lệnh:

```bash
terraform init
```

Sau khi chạy:

```text
.terraform/
```

được tạo ra.

---

## terraform fmt

Format code Terraform.

```bash
terraform fmt
```

Giúp code thống nhất format.

---

## terraform validate

Kiểm tra syntax.

```bash
terraform validate
```

Không tạo resource.

---

## terraform plan

Terraform thực hiện:

1. Đọc code
2. Đọc state
3. So sánh

Ví dụ:

```text
Current State:
0 EC2

Desired State:
1 EC2
```

Plan:

```text
+ create EC2
```

Lệnh:

```bash
terraform plan
```

---

## terraform apply

Thực thi thay đổi.

```bash
terraform apply
```

Terraform gọi API thật để tạo resource.

---

## terraform destroy

Xóa toàn bộ resource do Terraform quản lý.

```bash
terraform destroy
```

---

# 5. Terraform State Management

## State là gì?

Terraform lưu trạng thái hạ tầng vào:

```text
terraform.tfstate
```

---

## State chứa gì?

* Resource IDs
* Resource Attributes
* Dependency Graph
* Current Infrastructure Status

---

## Tại sao Terraform cần State?

Terraform cần biết:

```text
Resource nào đã tồn tại?
```

Ví dụ:

Apply lần đầu:

```text
EC2 created
```

Apply lần hai:

```text
terraform apply
```

Terraform đọc:

```text
terraform.tfstate
```

và biết EC2 đã tồn tại.

---

## Local State

Lưu trực tiếp:

```text
terraform.tfstate
```

trên máy local.

Phù hợp:

* Learning
* Personal Project

---

## Remote State

Production thường dùng:

```text
AWS S3
+
DynamoDB Locking
```

Ví dụ:

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "prod.tfstate"
    region = "ap-southeast-1"
  }
}
```

Lợi ích:

* Backup
* Team Sharing
* Versioning
* Locking

---

# 6. Terraform Modules

## Module là gì?

Module là tập hợp các file Terraform có thể tái sử dụng.

Ví dụ:

```text
modules/
└── ec2/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

---

## Gọi Module

```hcl
module "web_server" {
  source = "./modules/ec2"

  instance_type = "t3.micro"
}
```

---

## Lợi ích của Module

* Reusable
* Maintainable
* Consistent
* Scalable

---

## Cấu trúc chuẩn của Module

```text
modules/ec2/
├── main.tf
├── variables.tf
└── outputs.tf
```

---

# 7. Terraform Best Practices

## Không Hard-code

Sai:

```hcl
bucket = "mybucket"
```

Đúng:

```hcl
bucket = var.bucket_name
```

---

## Tách file rõ ràng

```text
main.tf
variables.tf
outputs.tf
providers.tf
versions.tf
```

---

## Luôn chạy

```bash
terraform fmt
terraform validate
terraform plan
```

trước khi:

```bash
terraform apply
```

---

## Sử dụng Module

Tránh copy-paste code.

---

## Không commit State File

.gitignore:

```gitignore
.terraform/
terraform.tfstate
terraform.tfstate.backup
```

---

## Dùng Remote State cho Production

Khuyến nghị:

```text
S3 + DynamoDB Lock
```

---

## Đặt Naming Convention

Ví dụ:

```text
dev-web-ec2
staging-web-ec2
prod-web-ec2
```

---

# Câu hỏi thường gặp trong bài Test

## Terraform là Declarative hay Imperative?

Declarative.

---

## terraform plan có tạo resource không?

Không.

---

## terraform apply làm gì?

Thực thi thay đổi.

---

## Terraform lưu trạng thái ở đâu?

terraform.tfstate

---

## Provider dùng để làm gì?

Kết nối Terraform với nền tảng bên ngoài.

---

## Resource là gì?

Đối tượng hạ tầng được Terraform quản lý.

---

## Module dùng để làm gì?

Tái sử dụng code.

---

## Production nên dùng Local State hay Remote State?

Remote State.


---

# Learning Objectives

After completing Day 1, I should be able to:

* Explain Infrastructure as Code (IaC).
* Explain why Cloud/DevOps teams use Terraform.
* Understand Terraform architecture and workflow.
* Understand HCL syntax.
* Explain Provider, Resource, Variable, Output, Local and Data blocks.
* Understand the purpose of Terraform State.
* Create and execute a simple Terraform project.

---

# What is Infrastructure as Code (IaC)?

Infrastructure as Code (IaC) is the practice of managing and provisioning infrastructure through code instead of manually creating resources through a web console.

## Traditional Approach

1. Login to AWS Console
2. Create VPC
3. Create Security Group
4. Create EC2
5. Create S3 Bucket

### Problems

* Time consuming
* Human errors
* Difficult to reproduce
* No version control
* Hard to review changes

## Infrastructure as Code Approach

Infrastructure is defined using code.

Example:

```hcl
resource "aws_instance" "web" {
  instance_type = "t2.micro"
}
```

Benefits:

* Automation
* Version Control
* Consistency
* Reusability
* Collaboration
* Auditability

---

# What is Terraform?

Terraform is an Infrastructure as Code (IaC) tool developed by HashiCorp.

Terraform allows engineers to define infrastructure using code and automatically provision resources through cloud provider APIs.

## Supported Platforms

Terraform supports:

* AWS
* Azure
* Google Cloud
* Kubernetes
* Docker
* GitHub

Terraform follows a declarative approach.

Instead of saying:

> Create an EC2 instance

We describe:

> I want one EC2 instance

Terraform determines how to achieve the desired state.

---

# Terraform Architecture

```text
Developer
    ↓
Terraform Configuration (.tf)
    ↓
Terraform CLI
    ↓
Provider
    ↓
Cloud API
    ↓
Infrastructure
```

## Example with AWS

```text
Developer
    ↓
terraform apply
    ↓
AWS Provider
    ↓
AWS API
    ↓
EC2 Instance
```

## Example with Local Provider

```text
Developer
    ↓
terraform apply
    ↓
Local Provider
    ↓
student.txt
```

---

# Terraform Workflow

Terraform works using a Desired State model.

```text
Write Configuration
        ↓
terraform init
        ↓
Download Providers
        ↓
terraform validate
        ↓
Validate Configuration
        ↓
terraform plan
        ↓
Generate Execution Plan
        ↓
terraform apply
        ↓
Create / Update Resources
        ↓
Update terraform.tfstate
```

## terraform init

Purpose:

* Initialize Terraform project
* Download providers
* Create `.terraform` directory

Command:

```bash
terraform init
```

---

## terraform validate

Purpose:

* Validate Terraform syntax

Command:

```bash
terraform validate
```

---

## terraform plan

Purpose:

* Compare Desired State and Current State
* Generate execution plan

Command:

```bash
terraform plan
```

Example output:

```text
Plan: 1 to add, 0 to change, 0 to destroy
```

Meaning:

* Add 1 resource
* Change 0 resources
* Destroy 0 resources

---

## terraform apply

Purpose:

* Execute planned changes

Command:

```bash
terraform apply
```

Terraform will request confirmation before applying changes.

---

## terraform destroy

Purpose:

* Remove infrastructure managed by Terraform

Command:

```bash
terraform destroy
```

---

# Terraform State

Terraform stores infrastructure information in:

```text
terraform.tfstate
```

## What State Contains

* Resource information
* Resource IDs
* Resource attributes
* Dependency relationships

## Why Terraform Needs State

Terraform uses state to:

* Track resources
* Detect changes
* Create execution plans
* Avoid duplicate resources

Example:

Current State:

```text
student.txt exists
```

Desired State:

```text
student.txt exists
```

Result:

```text
No changes.
Infrastructure is up-to-date.
```

Without state, Terraform would not know what resources already exist.

---

# HCL (HashiCorp Configuration Language)

Terraform uses HCL to define infrastructure.

## Basic Structure

```hcl
block_type "label1" "label2" {
  argument = value
}
```

Example:

```hcl
resource "aws_instance" "web" {
  instance_type = "t2.micro"
}
```

---

# Common Terraform Blocks

## terraform Block

Used to configure Terraform itself.

```hcl
terraform {
  required_version = ">= 1.0"
}
```

---

## provider Block

Defines how Terraform connects to a platform.

Example:

```hcl
provider "aws" {
  region = "ap-southeast-1"
}
```

Common providers:

* AWS
* Azure
* Google Cloud
* Kubernetes
* Docker
* Local

---

## resource Block

Represents infrastructure managed by Terraform.

Example:

```hcl
resource "aws_s3_bucket" "learning" {
  bucket = "learning-bucket"
}
```

Examples of resources:

* aws_instance
* aws_s3_bucket
* aws_vpc
* kubernetes_deployment
* local_file

---

## variable Block

Defines input values.

Example:

```hcl
variable "student_name" {
  type = string
}
```

Benefits:

* Reusable
* Flexible
* Easier maintenance

---

## output Block

Displays values after apply.

Example:

```hcl
output "file_name" {
  value = local_file.student.filename
}
```

---

## locals Block

Defines reusable local values.

Example:

```hcl
locals {
  project_name = "aws-accelerator"
}
```

---

## data Block

Reads existing information without creating resources.

Example:

```hcl
data "aws_caller_identity" "current" {}
```

Common use cases:

* Reading existing AWS resources
* Reading account information
* Looking up AMI IDs

---

# Hands-on Practice

## Project Structure

```text
day-1/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── terraform.tfstate
├── terraform.tfstate.backup
└── student.txt
```

---

## variables.tf

```hcl
variable "student_name" {
  description = "Student name"
  type        = string
}
```

---

## terraform.tfvars

```hcl
student_name = "Bui Thi Thuy Trang"
```

---

## main.tf

```hcl
resource "local_file" "student" {
  filename = "student.txt"
  content  = var.student_name
}
```

---

## outputs.tf

```hcl
output "file_name" {
  value = local_file.student.filename
}
```

---

# Commands Executed

Initialize Terraform:

```bash
terraform init
```

Validate configuration:

```bash
terraform validate
```

Generate execution plan:

```bash
terraform plan
```

Apply changes:

```bash
terraform apply
```

---

# Results

Terraform successfully created:

```text
student.txt
```

Content:

```text
Bui Thi Thuy Trang
```

Output:

```text
file_name = "student.txt"
```

Terraform also generated:

```text
terraform.tfstate
terraform.tfstate.backup
```

---

# Evidence

## Screenshots

* terraform-init.png
* terraform-plan.png
* terraform-apply.png

## Files Created

* main.tf
* variables.tf
* outputs.tf
* terraform.tfvars
* student.txt

## Terraform Outputs

```text
file_name = "student.txt"
```

---

# Key Takeaways

Today I learned:

* What Infrastructure as Code is.
* Why Terraform is widely used in Cloud and DevOps.
* Terraform architecture and workflow.
* HCL syntax fundamentals.
* The purpose of Provider, Resource, Variable, Output, Local and Data blocks.
* The role of terraform.tfstate.
* How to create and execute a simple Terraform project.

---

# Questions for Mentor

1. When should Terraform state be stored remotely instead of locally?
2. When should we create reusable modules?
3. What are the most common Terraform resources used in AWS production environments?
4. What Terraform best practices should beginners adopt from the beginning?

---

# Reflection

## What I Understand Well

* Infrastructure as Code concepts
* Terraform workflow
* Terraform HCL syntax
* Variables and outputs
* State file fundamentals

## What Is Still Unclear

* Remote state management
* Terraform modules
* Backend configuration
* Production-grade Terraform structure

## Next Steps

Topics for Day 2:

* Terraform State Management
* Terraform Modules
* Terraform Best Practices
* Terraform Lifecycle
* Terraform Backend
* Remote State
* AWS Resources with Terraform
