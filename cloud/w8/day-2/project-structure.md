# Terraform Project Structure Best Practice

## Mục tiêu

File này giải thích cách tổ chức một Terraform project chuẩn, dễ đọc, dễ mở rộng và phù hợp với DevOps/Cloud thực tế.

Sau khi học xong, bạn cần hiểu:

1. Một project Terraform nhỏ nên có những file nào.
2. Một project lớn nên tách module và environment thế nào.
3. Vì sao cần tách `envs/` và `modules/`.
4. Cấu trúc nào phù hợp cho lab cá nhân, team nhỏ, production.
5. Cách đọc nhanh một Terraform project lạ.

---

## 1. Terraform project là gì?

Một Terraform project thường là một thư mục chứa các file `.tf`.

Ví dụ đơn giản:

```text
learn-terraform-get-started-aws/
  main.tf
  variables.tf
  outputs.tf
```

Khi bạn chạy Terraform trong thư mục đó:

```bash
terraform init
terraform plan
terraform apply
```

Thư mục đó được gọi là **root module**.

---

## 2. Cấu trúc tối thiểu cho lab nhỏ

Với bài lab nhỏ, cấu trúc này là đủ:

```text
terraform-lab/
  main.tf
  variables.tf
  outputs.tf
  README.md
```

Ý nghĩa:

| File | Vai trò |
|---|---|
| `main.tf` | Resource/module chính |
| `variables.tf` | Input variables |
| `outputs.tf` | Output values |
| `README.md` | Ghi chú cách chạy và bài học |

Ví dụ phù hợp:

- Lab tạo EC2 đơn giản.
- Lab dùng local provider.
- Lab tạo S3 bucket.
- Bài tập Terraform beginner.

---

## 3. Cấu trúc cơ bản nên dùng cho hầu hết project

Cấu trúc rõ hơn:

```text
terraform-project/
  terraform.tf
  providers.tf
  variables.tf
  locals.tf
  data.tf
  main.tf
  outputs.tf
  terraform.tfvars.example
  README.md
```

Vai trò từng file:

| File | Vai trò |
|---|---|
| `terraform.tf` | Terraform version, required providers, backend |
| `providers.tf` | Provider configuration, ví dụ AWS region |
| `variables.tf` | Input variables |
| `locals.tf` | Local values như name prefix, common tags |
| `data.tf` | Data sources đọc dữ liệu có sẵn |
| `main.tf` | Resource/module chính |
| `outputs.tf` | Output sau apply |
| `terraform.tfvars.example` | File mẫu cho input values |
| `README.md` | Hướng dẫn sử dụng project |

Terraform tự load tất cả file `.tf` trong cùng thư mục, nên tên file chủ yếu để con người dễ đọc.

---

## 4. Ví dụ nội dung từng file

### `terraform.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

Nếu có remote backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "dev/app/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

---

### `providers.tf`

```hcl
provider "aws" {
  region = var.aws_region
}
```

Nếu dùng nhiều provider alias:

```hcl
provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}
```

---

### `variables.tf`

```hcl
variable "project" {
  description = "Project name."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-southeast-1"
}
```

---

### `locals.tf`

```hcl
locals {
  name_prefix = "${var.environment}-${var.project}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

---

### `data.tf`

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}
```

---

### `main.tf`

```hcl
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-server"
  })
}
```

---

### `outputs.tf`

```hcl
output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.app_server.id
}
```

---

## 5. Khi project lớn hơn nên tách theo domain

Nếu `main.tf` quá dài, có thể tách theo loại hạ tầng:

```text
terraform-project/
  terraform.tf
  providers.tf
  variables.tf
  locals.tf
  data.tf
  network.tf
  security.tf
  compute.tf
  storage.tf
  monitoring.tf
  outputs.tf
```

Ý nghĩa:

| File | Nội dung |
|---|---|
| `network.tf` | VPC, subnet, route table, NAT, IGW |
| `security.tf` | Security Group, IAM role, policy |
| `compute.tf` | EC2, Auto Scaling Group, ECS, EKS nodes |
| `storage.tf` | S3, EBS, EFS, RDS |
| `monitoring.tf` | CloudWatch logs, alarms, dashboards |

Lưu ý:

> Tách file không tạo dependency boundary. Terraform vẫn gom tất cả `.tf` trong folder thành một root module.

---

## 6. Cấu trúc có module

Khi nhiều environment dùng chung logic, nên dùng module.

```text
infra/
  modules/
    vpc/
      main.tf
      variables.tf
      outputs.tf
      README.md
    ec2/
      main.tf
      variables.tf
      outputs.tf
      README.md
  envs/
    dev/
      terraform.tf
      providers.tf
      main.tf
      variables.tf
      terraform.tfvars.example
      outputs.tf
    staging/
      terraform.tf
      providers.tf
      main.tf
      variables.tf
      terraform.tfvars.example
      outputs.tf
    prod/
      terraform.tf
      providers.tf
      main.tf
      variables.tf
      terraform.tfvars.example
      outputs.tf
```

Trong cấu trúc này:

```text
modules/ = code reusable
envs/    = cấu hình từng môi trường
```

---

## 7. Vì sao cần `modules/`?

Không dùng module dễ bị copy-paste:

```text
dev/network.tf
staging/network.tf
prod/network.tf
```

Nếu muốn sửa logic VPC, phải sửa nhiều nơi.

Dùng module:

```text
modules/vpc/ chứa logic VPC chung

envs/dev gọi module với input dev
envs/prod gọi module với input prod
```

Ví dụ:

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr
}
```

---

## 8. Vì sao cần `envs/`?

Mỗi environment thường có config khác nhau:

| Environment | Ví dụ khác biệt |
|---|---|
| `dev` | Instance nhỏ, ít subnet, cost thấp |
| `staging` | Gần giống prod, dùng để test release |
| `prod` | HA, nhiều subnet, backup, monitoring đầy đủ |

Tách env giúp:

- State riêng cho từng môi trường.
- Apply dev không ảnh hưởng prod.
- Review thay đổi theo môi trường.
- Dễ phân quyền hơn.

---

## 9. Ví dụ root module trong `envs/dev`

```text
infra/envs/dev/
  terraform.tf
  providers.tf
  variables.tf
  locals.tf
  main.tf
  outputs.tf
  terraform.tfvars.example
```

`main.tf`:

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name                = "${local.name_prefix}-vpc"
  cidr                = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
}

module "app_server" {
  source = "../../modules/ec2"

  name          = "${local.name_prefix}-app"
  ami_id        = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnet_ids[0]
}
```

---

## 10. Ví dụ child module `modules/vpc`

```text
modules/vpc/
  main.tf
  variables.tf
  outputs.tf
  README.md
```

`variables.tf`:

```hcl
variable "name" {
  description = "VPC name."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks."
  type        = list(string)
}
```

`main.tf`:

```hcl
resource "aws_vpc" "this" {
  cidr_block = var.cidr

  tags = {
    Name = var.name
  }
}
```

`outputs.tf`:

```hcl
output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}
```

---

## 11. Module nên expose output cần thiết

Module không nên bắt root module biết quá nhiều chi tiết bên trong.

Ví dụ module VPC nên output:

```hcl
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
```

Root module dùng:

```hcl
subnet_id = module.vpc.public_subnet_ids[0]
```

---

## 12. Cấu trúc backend/state theo environment

Mỗi environment nên có state riêng.

Ví dụ S3 key:

```text
dev/app/terraform.tfstate
staging/app/terraform.tfstate
prod/app/terraform.tfstate
```

Ví dụ trong `envs/dev/terraform.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "dev/app/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

Dev apply chỉ đụng state dev. Prod có state riêng.

---

## 13. Có nên dùng Terraform workspace không?

Terraform workspace cho phép nhiều state trong cùng một config.

Ví dụ:

```bash
terraform workspace new dev
terraform workspace new prod
terraform workspace select dev
```

Tuy nhiên beginner nên hiểu:

| Cách | Khi nào dùng |
|---|---|
| Folder `envs/dev`, `envs/prod` | Dễ hiểu, rõ ràng, phổ biến cho beginner/team nhỏ |
| Terraform workspace | Khi config gần như giống hệt và team đã hiểu rõ workspace |

Khuyến nghị học giai đoạn này:

> Ưu tiên tách folder `envs/` trước, chưa cần lạm dụng workspace.

---

## 14. Cấu trúc cho repo học W8 hiện tại

Repo học cá nhân có thể dùng cấu trúc đơn giản:

```text
cloud/
  w8/
    day-a/
      README.md
      concepts.md
      workflow-state-modules.md
      best-practices.md
      project-structure.md
      exercise-1-hello-terraform.md
      learn-terraform-get-started-aws/
        main.tf
        variables.tf
        outputs.tf
    day-b/
      README.md
      concepts-docker.md
      concepts-kubernetes.md
```

Với lab AWS hiện tại:

```text
learn-terraform-get-started-aws/
  main.tf
  variables.tf
  outputs.tf
```

Đây là cấu trúc ổn cho beginner lab. Sau này nếu lab lớn hơn có thể bổ sung:

```text
learn-terraform-get-started-aws/
  terraform.tf
  providers.tf
  data.tf
  locals.tf
  main.tf
  variables.tf
  outputs.tf
  terraform.tfvars.example
```

---

## 15. Cấu trúc production tham khảo

Một cấu trúc production có thể như sau:

```text
infra/
  README.md
  modules/
    networking/
      README.md
      main.tf
      variables.tf
      outputs.tf
      versions.tf
    compute/
      README.md
      main.tf
      variables.tf
      outputs.tf
      versions.tf
    database/
      README.md
      main.tf
      variables.tf
      outputs.tf
      versions.tf
  envs/
    dev/
      backend.tf
      providers.tf
      variables.tf
      locals.tf
      main.tf
      outputs.tf
      terraform.tfvars.example
    staging/
      backend.tf
      providers.tf
      variables.tf
      locals.tf
      main.tf
      outputs.tf
      terraform.tfvars.example
    prod/
      backend.tf
      providers.tf
      variables.tf
      locals.tf
      main.tf
      outputs.tf
      terraform.tfvars.example
```

Có thể thêm:

```text
scripts/          # scripts hỗ trợ bootstrap/check
policies/         # policy-as-code nếu có
.github/workflows # CI/CD plan/apply nếu dùng GitHub Actions
```

---

## 16. Cách đọc nhanh một Terraform project lạ

Khi mở một project Terraform mới, đọc theo thứ tự:

### Bước 1: Đọc README

Tìm:

- Project tạo gì?
- Cách chạy?
- Environment nào?
- State/backend ở đâu?

### Bước 2: Đọc `terraform.tf` / `versions.tf` / `backend.tf`

Tìm:

- Terraform version.
- Provider version.
- Backend/state config.

### Bước 3: Đọc `providers.tf`

Tìm:

- Provider nào?
- AWS region nào?
- Có provider alias không?

### Bước 4: Đọc `variables.tf`

Tìm:

- Project cần input gì?
- Có default không?
- Có validation không?
- Có sensitive variable không?

### Bước 5: Đọc `locals.tf`

Tìm:

- Naming convention.
- Common tags.
- Giá trị tính toán chung.

### Bước 6: Đọc `main.tf` hoặc domain files

Tìm:

- Resource nào được tạo?
- Module nào được gọi?
- Dependency giữa resource.

### Bước 7: Đọc `outputs.tf`

Tìm:

- Sau apply sẽ expose thông tin gì?
- Output có sensitive không?

---

## 17. Các câu hỏi cần tự trả lời khi review project

Khi review một Terraform project, tự hỏi:

1. Project này tạo resource gì?
2. Resource nằm ở AWS account/region nào?
3. State lưu ở đâu?
4. Có remote backend và locking không?
5. File nào chứa input values?
6. Có secret nào bị hard-code không?
7. Có dùng module không?
8. Module là local hay registry?
9. Module/provider có pin version không?
10. Có common tags không?
11. Apply project này có thể tạo cost gì?
12. Destroy project này có nguy hiểm không?

---

## 18. Naming convention gợi ý

### Folder

```text
envs/dev
envs/staging
envs/prod
modules/vpc
modules/ec2
modules/s3
```

### Resource local name

```hcl
resource "aws_vpc" "main" {}
resource "aws_subnet" "public" {}
resource "aws_security_group" "app" {}
resource "aws_instance" "app_server" {}
```

### Name tag trên AWS

```text
<environment>-<project>-<component>
```

Ví dụ:

```text
dev-myapp-vpc
dev-myapp-app-server
prod-myapp-rds
```

---

## 19. Khi nào nên tạo module?

Nên tạo module khi:

- Logic được dùng lại nhiều lần.
- Cùng một loại infrastructure xuất hiện ở nhiều environment.
- Resource group có boundary rõ, ví dụ VPC, EC2 app, S3 logging.
- Muốn chuẩn hóa cách tạo resource.

Chưa cần tạo module khi:

- Chỉ có 1 resource đơn giản.
- Lab beginner đang học syntax.
- Chưa hiểu input/output cần thiết.

Nguyên tắc:

> Đừng module hóa quá sớm. Trước tiên viết rõ ràng, sau đó thấy lặp lại thì tách module.

---

## 20. Checklist project structure

- [ ] Root module có file `.tf` rõ ràng.
- [ ] Có `README.md` hướng dẫn chạy.
- [ ] Có `terraform.tf` hoặc `versions.tf` khai báo version.
- [ ] Có `providers.tf` cấu hình provider.
- [ ] Có `variables.tf` cho input.
- [ ] Có `outputs.tf` cho output.
- [ ] Có `locals.tf` nếu có naming/tags dùng chung.
- [ ] Không nhồi tất cả vào `main.tf` nếu project lớn.
- [ ] Có `modules/` nếu logic cần reuse.
- [ ] Có `envs/` nếu có nhiều môi trường.
- [ ] Mỗi environment có state riêng.
- [ ] Có `terraform.tfvars.example` nếu cần input mẫu.
- [ ] Không commit state, `.terraform/`, secret.

---

## 21. Cấu trúc khuyến nghị cho giai đoạn học hiện tại

Với level W8 Day A, nên đi theo 3 cấp:

### Cấp 1: Lab nhỏ

```text
lab/
  main.tf
  variables.tf
  outputs.tf
```

Mục tiêu: hiểu syntax và workflow.

### Cấp 2: Project nhỏ rõ file

```text
lab/
  terraform.tf
  providers.tf
  variables.tf
  locals.tf
  data.tf
  main.tf
  outputs.tf
  README.md
```

Mục tiêu: hiểu best practice file layout.

### Cấp 3: Multi-env + module

```text
infra/
  modules/
    vpc/
    ec2/
  envs/
    dev/
    prod/
```

Mục tiêu: hiểu cách team thực tế tổ chức Terraform.

Trong tuần này, chỉ cần nắm chắc cấp 1 và hiểu được cấp 2. Cấp 3 học dần khi sang module/state nâng cao.