# Terraform Best Practices

## Mục tiêu

File này tổng hợp các best practices quan trọng khi viết Terraform, từ mức beginner đến gần production.

Sau khi học xong, bạn cần biết:

1. File nào được commit và file nào không được commit.
2. Cách tổ chức Terraform code dễ đọc.
3. Cách đặt tên resource/module/variable.
4. Cách quản lý provider, version, state, secret.
5. Cách review `terraform plan` an toàn trước khi apply.

---

## 1. Nguyên tắc lớn nhất

Terraform quản lý hạ tầng thật, vì vậy cần nhớ:

```text
Terraform code thay đổi
        ↓
terraform plan
        ↓
review kỹ
        ↓
terraform apply
        ↓
AWS infrastructure thật thay đổi
```

Không xem Terraform như code demo bình thường. Một thay đổi nhỏ có thể tạo, xoá hoặc replace resource thật.

---

## 2. Luôn commit code, không commit runtime files

### Nên commit

```text
*.tf
*.tfvars.example
README.md
modules/
envs/
```

Ví dụ:

```text
main.tf
variables.tf
outputs.tf
providers.tf
terraform.tf
README.md
```

### Không nên commit

```text
.terraform/
terraform.tfstate
terraform.tfstate.backup
*.tfvars
*.tfplan
crash.log
```

Lý do:

- `.terraform/` là thư mục plugin/module tải về local.
- `terraform.tfstate` có thể chứa sensitive data.
- `*.tfvars` có thể chứa giá trị riêng của môi trường hoặc secret.
- `*.tfplan` là file binary/runtime, có thể chứa sensitive data.

---

## 3. Dùng `.gitignore` cho Terraform

Một `.gitignore` Terraform cơ bản:

```gitignore
# Terraform local directory
.terraform/

# Terraform state
*.tfstate
*.tfstate.*

# Terraform variable values
*.tfvars
*.tfvars.json

# Terraform plan files
*.tfplan

# Terraform crash logs
crash.log
crash.*.log

# Override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json
```

Lưu ý về `.terraform.lock.hcl`:

- Với project thật, thường **nên commit** `.terraform.lock.hcl` để lock provider version.
- Với lab cá nhân, có thể ignore nếu mentor yêu cầu, nhưng cần hiểu file này dùng để khóa dependency provider.

---

## 4. Luôn chạy `terraform fmt`

Trước khi commit:

```bash
terraform fmt -recursive
```

Kiểm tra trong CI:

```bash
terraform fmt -check -recursive
```

Lợi ích:

- Code đồng nhất format.
- Dễ review.
- Tránh tranh luận style không cần thiết.

---

## 5. Luôn chạy `terraform validate`

Sau khi viết/sửa code:

```bash
terraform validate
```

Lệnh này kiểm tra:

- Syntax HCL.
- Block/resource/variable có hợp lệ không.
- Reference cơ bản có đúng không.

Nhưng cần nhớ:

> `validate` không đảm bảo apply thành công trên AWS. Apply còn phụ thuộc permission, quota, region, API, service availability.

---

## 6. Luôn review `terraform plan` trước khi apply

Không nên apply khi chưa đọc plan.

```bash
terraform plan
```

Cần đọc kỹ:

| Ký hiệu | Cần hiểu |
|---|---|
| `+` | Resource mới sẽ được tạo |
| `~` | Resource hiện có sẽ bị thay đổi |
| `-` | Resource sẽ bị xoá |
| `-/+` | Resource bị xoá rồi tạo lại |
| `+/-` | Resource tạo mới trước rồi xoá cũ |

Đặc biệt cẩn thận với:

```text
Plan: 0 to add, 0 to change, 5 to destroy.
```

hoặc:

```text
forces replacement
```

`forces replacement` nghĩa là Terraform không thể update tại chỗ, phải replace resource. Với EC2, RDS, EKS, điều này có thể ảnh hưởng service.

---

## 7. Dùng plan file khi cần an toàn hơn

Thay vì:

```bash
terraform apply
```

Có thể dùng:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

Lợi ích:

- Review đúng plan sẽ được apply.
- Tránh trường hợp code/state thay đổi giữa lúc plan và apply.

Không commit file `tfplan`.

---

## 8. Không hard-code giá trị lặp lại

Không nên:

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "dev-myapp-logs"
}

resource "aws_instance" "app" {
  tags = {
    Project     = "myapp"
    Environment = "dev"
  }
}
```

Nên dùng variable và locals:

```hcl
variable "project" {
  type    = string
  default = "myapp"
}

variable "environment" {
  type    = string
  default = "dev"
}

locals {
  name_prefix = "${var.environment}-${var.project}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = "${local.name_prefix}-logs"

  tags = local.common_tags
}
```

---

## 9. Đặt tên rõ ràng

### Resource name

Không nên:

```hcl
resource "aws_instance" "x" {}
resource "aws_s3_bucket" "bucket1" {}
```

Nên:

```hcl
resource "aws_instance" "app_server" {}
resource "aws_s3_bucket" "access_logs" {}
```

Resource address sẽ dễ hiểu:

```text
aws_instance.app_server
aws_s3_bucket.access_logs
```

### Variable name

Nên đặt tên thể hiện ý nghĩa:

```hcl
variable "instance_type" {}
variable "environment" {}
variable "vpc_cidr" {}
variable "private_subnet_cidrs" {}
```

Không nên đặt tên quá mơ hồ:

```hcl
variable "type" {}
variable "name1" {}
variable "config" {}
```

---

## 10. Tách file theo trách nhiệm

Terraform không bắt buộc tên file, nhưng nên tách để dễ đọc:

```text
terraform.tf      # required_version, required_providers, backend
providers.tf      # provider config
variables.tf      # input variables
locals.tf         # reusable local values
main.tf           # main resources/modules
data.tf           # data sources
outputs.tf        # outputs
```

Với project lớn:

```text
network.tf        # VPC, subnet, route table
security.tf       # Security Group, IAM
compute.tf        # EC2, ASG, ECS, EKS
storage.tf        # S3, EBS, EFS, RDS
monitoring.tf     # CloudWatch, alarms
```

Không nên nhồi tất cả vào một file `main.tf` quá dài.

---

## 11. Khai báo version rõ ràng

Nên có file `terraform.tf` hoặc `versions.tf`:

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

Lợi ích:

- Tránh mỗi máy dùng provider version khác nhau.
- Tránh upgrade provider bất ngờ làm thay đổi behavior.
- Dễ debug khi team làm chung.

---

## 12. Pin version khi dùng module registry

Không nên:

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
}
```

Nên:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.3.0"
}
```

Lý do:

- Module mới có thể thay đổi input/output.
- Có thể làm plan thay đổi ngoài ý muốn.
- Pin version giúp build reproducible.

---

## 13. Dùng remote state cho team/production

Local state phù hợp cho lab nhỏ:

```text
terraform.tfstate trên máy cá nhân
```

Nhưng với team hoặc production nên dùng remote backend:

- HCP Terraform / Terraform Cloud.
- AWS S3 + DynamoDB lock.
- Azure Storage.
- Google Cloud Storage.

Ví dụ AWS S3 backend:

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

Best practice:

> Backend S3 bucket và DynamoDB lock table nên được tạo bởi bootstrap process riêng.

---

## 14. Không sửa resource bằng tay trên AWS Console

Nếu resource đã được Terraform quản lý, không nên sửa bằng tay trên Console.

Vì sẽ tạo drift:

```text
Terraform code: t3.micro
AWS Console:    t3.small
State:          t3.micro hoặc old value
```

Lần sau `terraform plan`, Terraform phát hiện khác biệt và có thể đổi lại theo code.

Nếu bắt buộc sửa tay trong incident:

1. Ghi chú lại thay đổi.
2. Cập nhật Terraform code cho khớp.
3. Chạy `terraform plan` để kiểm tra drift.

---

## 15. Quản lý secret cẩn thận

Không hard-code secret:

```hcl
variable "db_password" {
  default = "SuperSecret123"
}
```

Không commit secret trong:

```text
*.tf
*.tfvars
README.md
state file
```

Nên:

- Dùng secret manager như AWS Secrets Manager / SSM Parameter Store.
- Dùng environment variables khi phù hợp.
- Mark variable/output là sensitive nếu cần.

Ví dụ:

```hcl
variable "db_password" {
  description = "Database password."
  type        = string
  sensitive   = true
}

output "db_password" {
  value     = var.db_password
  sensitive = true
}
```

Lưu ý:

> `sensitive = true` chỉ che output trên CLI, không đảm bảo secret không nằm trong state.

---

## 16. Dùng `terraform.tfvars.example`

Không commit file thật:

```text
terraform.tfvars
```

Nên commit file mẫu:

```text
terraform.tfvars.example
```

Ví dụ:

```hcl
project     = "myapp"
environment = "dev"
aws_region  = "ap-southeast-1"

# Do not put real secrets here.
db_password = "CHANGE_ME"
```

Người dùng copy:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Sau đó sửa giá trị local.

---

## 17. Dùng tags chuẩn

Với AWS, tag giúp quản lý cost, ownership và environment.

Ví dụ:

```hcl
locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}
```

Dùng:

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "${local.name_prefix}-logs"

  tags = local.common_tags
}
```

Tags thường nên có:

| Tag | Ý nghĩa |
|---|---|
| `Project` | Tên project |
| `Environment` | dev/staging/prod |
| `Owner` | Team hoặc người chịu trách nhiệm |
| `ManagedBy` | terraform |
| `CostCenter` | Mã cost center nếu công ty yêu cầu |

---

## 18. Ưu tiên `for_each` khi resource có identity rõ

`count` phù hợp khi tạo N resource gần như giống nhau:

```hcl
resource "aws_instance" "web" {
  count = 3
}
```

Nhưng nếu resource có tên/key rõ, nên dùng `for_each`:

```hcl
variable "buckets" {
  type = map(object({
    purpose = string
  }))
}

resource "aws_s3_bucket" "this" {
  for_each = var.buckets

  bucket = "${local.name_prefix}-${each.key}"

  tags = merge(local.common_tags, {
    Purpose = each.value.purpose
  })
}
```

Lý do:

- Address ổn định hơn.
- Ít bị replace do thay đổi index.
- Dễ đọc plan hơn.

---

## 19. Cẩn thận với `target`

Terraform có flag:

```bash
terraform apply -target=aws_instance.app_server
```

Nhưng không nên dùng thường xuyên.

Vì `-target` có thể bỏ qua dependency hoặc làm state/code không được apply đầy đủ.

Chỉ nên dùng khi:

- Debug.
- Khôi phục sự cố.
- Có lý do rõ ràng.

Workflow bình thường nên để Terraform tính toàn bộ dependency graph.

---

## 20. Cẩn thận với lifecycle

Ví dụ:

```hcl
lifecycle {
  prevent_destroy = true
}
```

Tốt cho resource quan trọng như production database, nhưng có thể làm `terraform destroy` fail.

Ví dụ:

```hcl
lifecycle {
  ignore_changes = [tags]
}
```

Có thể hữu ích nếu tag bị tool khác quản lý, nhưng dùng sai sẽ che giấu drift thật.

Nguyên tắc:

> Dùng lifecycle khi hiểu rõ vấn đề đang giải quyết, không dùng để che lỗi plan.

---

## 21. Viết README cho mỗi project/module

Một Terraform project tốt nên có README mô tả:

- Project tạo resource gì.
- Cách chạy.
- Input variables chính.
- Outputs chính.
- Backend/state ở đâu.
- Lưu ý destroy/cost.

Ví dụ README ngắn:

```markdown
# Dev VPC

## Resources

- VPC
- Public/private subnets
- Internet Gateway
- NAT Gateway

## Usage

terraform init
terraform plan
terraform apply
```

---

## 22. Review checklist trước khi apply

Trước khi chạy `terraform apply`, tự hỏi:

- [ ] Đang ở đúng folder/env chưa?
- [ ] Đang dùng đúng AWS account chưa?
- [ ] Đang dùng đúng region chưa?
- [ ] Backend/state đúng chưa?
- [ ] Plan có destroy resource nào không?
- [ ] Plan có replace resource quan trọng không?
- [ ] Có secret nào bị in ra output không?
- [ ] Có resource nào gây cost không?
- [ ] Có cần approval không?

---

## 23. Best practices cho lab cá nhân

Với repo học cá nhân như W8 Day A:

Nên làm:

- Viết note rõ ràng.
- Commit `.tf` code lab.
- Không commit `.terraform/`.
- Không commit state.
- Không commit tfvars chứa secret.
- Ghi lại lệnh đã chạy trong exercise.
- Ghi lại bài học/rút kinh nghiệm.

Không nhất thiết phải làm ngay:

- Remote backend production.
- CI/CD Terraform pipeline.
- Multi-account AWS.
- Module quá phức tạp.

---

## 24. Những lỗi beginner hay gặp

| Lỗi | Hậu quả | Cách tránh |
|---|---|---|
| Commit `terraform.tfstate` | Lộ sensitive data, conflict | Thêm vào `.gitignore` |
| Không đọc plan | Xoá/replace resource ngoài ý muốn | Luôn review plan |
| Dùng `latest` module/provider | Behavior thay đổi bất ngờ | Pin version |
| Hard-code secret | Lộ credential | Dùng secret manager/tfvars local |
| Sửa resource bằng Console | Drift | Quản lý bằng Terraform code |
| Dùng `count` với list hay thay đổi | Replace do index shift | Dùng `for_each` |
| Không đặt tag | Khó quản lý cost/owner | Dùng common tags |

---

## 25. Checklist Terraform best practices

- [ ] Có `.gitignore` cho Terraform.
- [ ] Không commit `.terraform/`.
- [ ] Không commit `terraform.tfstate`.
- [ ] Không commit `*.tfvars` chứa giá trị thật.
- [ ] Có `terraform.tfvars.example` nếu cần.
- [ ] Có `required_version`.
- [ ] Có `required_providers`.
- [ ] Pin version module registry.
- [ ] Tách file rõ trách nhiệm.
- [ ] Dùng variable/locals thay vì hard-code lặp lại.
- [ ] Có common tags.
- [ ] Chạy `terraform fmt` trước commit.
- [ ] Chạy `terraform validate` trước commit.
- [ ] Review kỹ `terraform plan` trước apply.
- [ ] Hiểu rõ mọi destroy/replace trong plan.
- [ ] Không sửa resource Terraform-managed bằng tay trên Console.