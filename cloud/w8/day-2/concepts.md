# Terraform Concepts — Giải thích chi tiết

## 1. Provider

**Provider** là plugin giúp Terraform giao tiếp với API bên ngoài.

Ví dụ:

```hcl
provider "aws" {
  region = "ap-southeast-1"
}
```

Terraform bản thân không biết cách tạo EC2, S3, VPC. Nó cần AWS provider để gọi AWS API.

Một số provider phổ biến:

- `hashicorp/aws`
- `hashicorp/azurerm`
- `hashicorp/google`
- `hashicorp/kubernetes`
- `hashicorp/local`
- `hashicorp/random`

---

## 2. Resource

**Resource** là object mà Terraform quản lý.

Ví dụ:

```hcl
resource "local_file" "hello" {
  filename = "hello.txt"
  content  = "Hello Terraform"
}
```

Cú pháp:

```hcl
resource "<resource_type>" "<resource_name>" {
  argument = value
}
```

Trong ví dụ trên:

- `local_file`: resource type
- `hello`: tên nội bộ trong Terraform
- `filename`, `content`: argument

Tham chiếu resource:

```hcl
local_file.hello.filename
```

Format:

```hcl
<resource_type>.<resource_name>.<attribute>
```

---

## 3. Variable

**Variable** là input của Terraform module.

Ví dụ:

```hcl
variable "environment" {
  type    = string
  default = "dev"
}
```

Dùng variable:

```hcl
name = var.environment
```

Truyền variable khi chạy command:

```bash
terraform apply -var="environment=prod"
```

Hoặc tạo file `.tfvars`:

```hcl
environment = "prod"
```

Rồi chạy:

```bash
terraform apply -var-file="prod.tfvars"
```

> Không nên commit file `.tfvars` nếu chứa secret hoặc thông tin nhạy cảm.

---

## 4. Output

**Output** là thông tin Terraform in ra sau khi apply.

Ví dụ:

```hcl
output "instance_ip" {
  value = aws_instance.web.public_ip
}
```

Dùng output để:

- Xem kết quả quan trọng sau deploy
- Truyền dữ liệu giữa module
- Expose thông tin cho automation khác

Xem output:

```bash
terraform output
```

---

## 5. Locals

**Locals** là biến nội bộ trong module, dùng để tránh lặp logic.

Ví dụ:

```hcl
locals {
  name_prefix = "myapp-dev"
}
```

Dùng local:

```hcl
name = local.name_prefix
```

Khác với variable:

| Variable | Local |
|---|---|
| Input từ bên ngoài | Giá trị nội bộ |
| Có thể truyền qua CLI/tfvars | Không truyền từ bên ngoài |
| Dùng cho config linh hoạt | Dùng để tái sử dụng logic |

---

## 6. Data Source

**Data source** dùng để đọc dữ liệu đã tồn tại, không tạo resource mới.

Ví dụ AWS AMI:

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
```

Dùng data source:

```hcl
ami = data.aws_ami.ubuntu.id
```

---

## 7. Terraform State

Terraform cần biết resource nào đang được quản lý. Thông tin đó được lưu trong **state file**.

File local mặc định:

```text
terraform.tfstate
```

State lưu:

- Resource đã tạo
- Attribute của resource
- Mapping giữa code Terraform và hạ tầng thật
- Dependency graph

Ví dụ nếu code có:

```hcl
resource "local_file" "hello" {}
```

State sẽ ghi resource `local_file.hello` đang tương ứng với file nào trên máy.

### Có nên commit state không?

Không nên commit `terraform.tfstate` lên Git vì:

- Có thể chứa secret
- Dễ conflict khi nhiều người cùng làm
- Là trạng thái runtime, không phải source code

Production thường dùng remote backend như:

- S3 + DynamoDB lock
- Terraform Cloud
- Azure Storage
- GCS

---

## 8. Dependency

Terraform tự hiểu dependency qua reference.

Ví dụ:

```hcl
resource "local_file" "a" {
  filename = "a.txt"
  content  = "hello"
}

resource "local_file" "b" {
  filename = "b.txt"
  content  = local_file.a.content
}
```

Resource `b` phụ thuộc vào `a` vì dùng `local_file.a.content`.

Terraform sẽ tạo `a` trước rồi mới tạo `b`.

---

## 9. Expressions

Terraform hỗ trợ expression như:

### String interpolation

```hcl
"${var.app_name}-${var.environment}"
```

### Conditional

```hcl
var.environment == "prod" ? "large" : "small"
```

### List

```hcl
["web", "api", "worker"]
```

### Map

```hcl
{
  environment = "dev"
  owner       = "team-cloud"
}
```

### for expression

```hcl
[for name in var.names : upper(name)]
```

---

## 10. Cách đọc một file Terraform

Khi đọc file `.tf`, hãy hỏi:

1. Config này dùng provider nào?
2. Nó tạo resource gì?
3. Input variable là gì?
4. Output là gì?
5. Có data source nào không?
6. Dependency giữa các resource ra sao?
7. Có secret nào không nên commit không?

---

## Mini quiz

1. Terraform là declarative hay imperative?
2. Provider dùng để làm gì?
3. Resource khác data source ở điểm nào?
4. Variable khác local ở điểm nào?
5. Vì sao không nên commit `terraform.tfstate`?
6. `terraform plan` khác `terraform apply` thế nào?
7. `terraform destroy` dùng khi nào?