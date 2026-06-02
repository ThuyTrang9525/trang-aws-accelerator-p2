# Terraform Workflow, State Management, Modules

## Mục tiêu

File này tập trung vào phần Day A/Day 2 quan trọng nhất của Terraform:

1. Hiểu workflow chạy Terraform thực tế.
2. Hiểu state management.
3. Hiểu module và cách tái sử dụng Terraform code.

---

## 1. Terraform workflow tổng quan

Workflow cơ bản:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform output
terraform destroy
```

Luồng tư duy:

```text
Viết .tf files
   ↓
terraform init       # chuẩn bị provider/module/backend
   ↓
terraform fmt        # format code
   ↓
terraform validate   # kiểm tra config
   ↓
terraform plan       # xem dự kiến thay đổi
   ↓
review plan          # bắt buộc đọc kỹ
   ↓
terraform apply      # thực thi
   ↓
terraform.tfstate    # Terraform lưu trạng thái
```

---

## 2. `terraform init`

`terraform init` dùng để khởi tạo working directory.

Nó làm các việc chính:

- Tải provider plugin.
- Tải module nếu có dùng `module` block.
- Khởi tạo backend nếu có khai báo backend.
- Tạo thư mục `.terraform/`.
- Tạo hoặc cập nhật `.terraform.lock.hcl`.

Ví dụ:

```bash
terraform init
```

Khi nào cần chạy lại `init`?

- Lần đầu clone project.
- Thêm/sửa provider.
- Thêm/sửa module source.
- Thêm/sửa backend.
- Xoá thư mục `.terraform/`.

---

## 3. `terraform fmt`

`terraform fmt` format code HCL theo chuẩn Terraform.

```bash
terraform fmt
```

Format toàn bộ thư mục con:

```bash
terraform fmt -recursive
```

Dùng trong CI để kiểm tra format:

```bash
terraform fmt -check -recursive
```

Best practice:

> Luôn chạy `terraform fmt` trước khi commit.

---

## 4. `terraform validate`

`terraform validate` kiểm tra file Terraform có hợp lệ về syntax và cấu trúc không.

```bash
terraform validate
```

Nó kiểm tra:

- Syntax HCL.
- Reference có hợp lệ không.
- Variable/output/resource block có đúng không.
- Provider schema cơ bản.

Nó không đảm bảo resource tạo được thật trên AWS, vì phần đó cần `plan/apply` gọi API.

---

## 5. `terraform plan`

`terraform plan` cho biết Terraform sẽ làm gì trước khi apply.

```bash
terraform plan
```

Plan so sánh 3 thứ:

```text
Terraform code hiện tại
        vs
Terraform state
        vs
Real infrastructure từ provider
```

Plan output ký hiệu:

| Ký hiệu | Ý nghĩa |
|---|---|
| `+` | Create resource mới |
| `~` | Update resource hiện có |
| `-` | Destroy resource |
| `-/+` | Replace: xoá cũ rồi tạo mới |
| `+/-` | Replace: tạo mới trước rồi xoá cũ |
| `<=` | Read data source |

Ví dụ:

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

Nghĩa là Terraform sẽ tạo thêm 2 resource.

Ví dụ replace:

```text
-/+ resource "aws_instance" "app" {
      ami = "ami-old" -> "ami-new" # forces replacement
}
```

`forces replacement` nghĩa là field đó thay đổi thì AWS không cho update in-place, Terraform phải xoá instance cũ và tạo instance mới.

---

## 6. `terraform apply`

`terraform apply` thực thi thay đổi.

```bash
terraform apply
```

Terraform sẽ:

1. Tạo plan.
2. Hỏi confirm.
3. Gọi provider API để tạo/sửa/xoá resource.
4. Cập nhật state.

Apply không hỏi confirm:

```bash
terraform apply -auto-approve
```

Best practice:

> Không dùng `-auto-approve` cho production nếu không có CI/CD approval an toàn.

Apply từ plan file:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

Cách này đảm bảo apply đúng plan đã review.

---

## 7. `terraform destroy`

`terraform destroy` xoá toàn bộ resource trong state của project hiện tại.

```bash
terraform destroy
```

Cẩn thận:

- Destroy xoá resource thật.
- Không chạy bừa trong production.
- Luôn đọc plan trước khi confirm.

Có thể destroy target resource nhưng không khuyến khích dùng thường xuyên:

```bash
terraform destroy -target=aws_instance.app
```

---

## 8. Terraform State là gì?

Terraform state là file lưu trạng thái resource Terraform đang quản lý.

File local mặc định:

```text
terraform.tfstate
```

State lưu:

- Resource address, ví dụ `aws_instance.app_server`.
- Resource ID thật trên cloud, ví dụ EC2 instance ID.
- Attribute của resource.
- Dependency information.
- Output values.
- Sensitive values có thể xuất hiện trong state.

Ví dụ tư duy:

```text
Code:  resource "aws_instance" "app_server"
State: aws_instance.app_server = i-0123456789abcdef0
AWS:   EC2 instance thật có ID i-0123456789abcdef0
```

Terraform cần state để biết resource trong code tương ứng với resource thật nào.

---

## 9. Vì sao state quan trọng?

Nếu không có state, Terraform không biết:

- Resource nào đã tạo rồi.
- Resource nào cần update.
- Resource nào cần xoá.
- Output hiện tại là gì.
- Dependency graph hiện tại ra sao.

State là một trong những phần quan trọng nhất của Terraform.

---

## 10. Có nên commit state không?

Không nên commit:

```text
terraform.tfstate
terraform.tfstate.backup
```

Lý do:

- Có thể chứa secret/password/token.
- Dễ conflict khi nhiều người cùng làm.
- Là runtime state, không phải source code.
- Nếu mất kiểm soát state có thể gây hỏng quản lý infra.

---

## 11. Local state vs Remote state

### Local state

```text
terraform.tfstate nằm trên máy cá nhân
```

Ưu điểm:

- Dễ học.
- Không cần setup backend.
- Phù hợp lab nhỏ.

Nhược điểm:

- Dễ mất file.
- Không phù hợp team.
- Không có locking.
- Dễ bị commit nhầm.

### Remote state

State lưu ở backend như:

- HCP Terraform / Terraform Cloud.
- AWS S3 + DynamoDB lock.
- Azure Storage.
- Google Cloud Storage.

Ưu điểm:

- Nhiều người dùng chung được.
- Có locking.
- Có thể encrypt.
- Phù hợp production.

---

## 12. Backend S3 + DynamoDB lock

Ví dụ backend AWS phổ biến:

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

Ý nghĩa:

| Field | Ý nghĩa |
|---|---|
| `bucket` | S3 bucket lưu state |
| `key` | Đường dẫn file state trong bucket |
| `region` | Region của bucket |
| `dynamodb_table` | Bảng lock để tránh apply cùng lúc |
| `encrypt` | Mã hoá state at rest |

Lưu ý:

> Backend resource thường phải được tạo trước bằng tay hoặc bằng một bootstrap Terraform project riêng.

---

## 13. State locking

State locking giúp tránh 2 người cùng apply một lúc.

Nếu không có lock:

```text
User A terraform apply
User B terraform apply cùng lúc
→ cả hai cùng ghi state
→ state conflict/hỏng
```

Với lock:

```text
User A apply → lock state
User B apply → phải chờ hoặc bị báo state locked
```

---

## 14. Drift là gì?

**Drift** xảy ra khi real infrastructure bị thay đổi ngoài Terraform.

Ví dụ:

1. Terraform tạo EC2 `t3.micro`.
2. Ai đó vào AWS Console đổi thành `t3.small`.
3. Code vẫn ghi `t3.micro`.
4. Lần sau `terraform plan`, Terraform phát hiện khác biệt.

Cách xử lý:

- Nếu thay đổi ngoài console là sai: apply Terraform để đưa về đúng code.
- Nếu thay đổi ngoài console là đúng: cập nhật code Terraform cho khớp.

Best practice:

> Không sửa hạ tầng Terraform-managed bằng tay trên console, trừ tình huống khẩn cấp.

---

## 15. State commands cần biết

```bash
terraform state list
terraform state show <address>
terraform state pull
terraform state mv <source> <destination>
terraform state rm <address>
```

### `terraform state list`

Liệt kê resource trong state:

```bash
terraform state list
```

Ví dụ output:

```text
aws_instance.app_server
module.vpc.aws_vpc.this[0]
```

### `terraform state show`

Xem chi tiết resource trong state:

```bash
terraform state show aws_instance.app_server
```

### `terraform state mv`

Đổi address resource trong state khi refactor code:

```bash
terraform state mv aws_instance.old aws_instance.new
```

### `terraform state rm`

Gỡ resource khỏi state nhưng không xoá resource thật:

```bash
terraform state rm aws_instance.app_server
```

Cẩn thận: resource thật vẫn còn, Terraform không quản lý nữa.

---

## 16. `terraform import`

`terraform import` đưa resource đã tồn tại vào Terraform state.

Ví dụ có một S3 bucket tạo bằng tay, muốn Terraform quản lý:

```hcl
resource "aws_s3_bucket" "existing" {
  bucket = "my-existing-bucket"
}
```

Import:

```bash
terraform import aws_s3_bucket.existing my-existing-bucket
```

Sau import:

- State biết resource này.
- Bạn vẫn cần viết code Terraform khớp với resource thật.
- Chạy `terraform plan` để xem có diff không.

---

## 17. Module là gì?

Module là một package Terraform có thể tái sử dụng.

Một thư mục chứa file `.tf` chính là một module.

```text
root module = thư mục bạn đang chạy terraform
child module = module được gọi bằng block module
```

Ví dụ root module:

```text
infra/envs/dev/
  main.tf
  variables.tf
  outputs.tf
```

Ví dụ child module:

```text
infra/modules/vpc/
  main.tf
  variables.tf
  outputs.tf
```

---

## 18. Vì sao cần module?

Không có module, code dễ bị copy-paste:

```text
dev tạo VPC riêng
staging copy VPC code
prod copy VPC code
→ sửa 1 chỗ phải sửa 3 chỗ
→ dễ lệch config
```

Có module:

```text
modules/vpc = logic tạo VPC reusable
envs/dev gọi module với input dev
envs/prod gọi module với input prod
```

Lợi ích:

- Reuse code.
- Giảm duplicate.
- Chuẩn hoá infrastructure.
- Dễ maintain.
- Dễ versioning.

---

## 19. Cấu trúc module chuẩn

```text
modules/
  vpc/
    README.md
    main.tf
    variables.tf
    outputs.tf
    versions.tf
```

Có thể thêm:

```text
modules/
  vpc/
    locals.tf
    data.tf
    examples/
      simple/
        main.tf
```

---

## 20. Gọi local module

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name = "dev-vpc"
  cidr = "10.0.0.0/16"
}
```

Dùng output từ module:

```hcl
subnet_id = module.vpc.private_subnet_ids[0]
```

---

## 21. Gọi registry module

Ví dụ dùng VPC module từ Terraform Registry:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.3.0"

  name = "example-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24"]
}
```

Best practice:

> Luôn pin `version` khi dùng registry module.

---

## 22. Module input/output

Module nhận input qua `variables.tf`.

```hcl
variable "name" {
  description = "VPC name."
  type        = string
}
```

Module expose output qua `outputs.tf`.

```hcl
output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}
```

Root module dùng output:

```hcl
output "vpc_id" {
  value = module.vpc.vpc_id
}
```

---

## 23. Lifecycle meta-arguments

Lifecycle giúp kiểm soát cách Terraform xử lý resource.

```hcl
resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true
    ignore_changes        = [tags]
  }
}
```

Ý nghĩa:

| Option | Ý nghĩa |
|---|---|
| `create_before_destroy` | Tạo resource mới trước khi xoá resource cũ |
| `prevent_destroy` | Chặn destroy resource này |
| `ignore_changes` | Bỏ qua một số thay đổi |
| `replace_triggered_by` | Replace khi resource khác thay đổi |

Cẩn thận:

- `prevent_destroy` có thể làm `terraform destroy` fail.
- `ignore_changes` dùng sai có thể che giấu drift thật.

---

## 24. `count` và `for_each`

### `count`

Dùng để tạo N resource giống nhau.

```hcl
resource "aws_instance" "web" {
  count = 3

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  tags = {
    Name = "web-${count.index}"
  }
}
```

Nhược điểm: nếu xoá/thay đổi thứ tự list, index thay đổi có thể gây replace ngoài ý muốn.

### `for_each`

Dùng khi có key rõ ràng.

```hcl
variable "instances" {
  type = map(object({
    instance_type = string
  }))
}

resource "aws_instance" "web" {
  for_each = var.instances

  ami           = data.aws_ami.ubuntu.id
  instance_type = each.value.instance_type

  tags = {
    Name = each.key
  }
}
```

Best practice:

> Ưu tiên `for_each` khi resource có identity rõ ràng.

---

## 25. Checklist workflow/state/module

- [ ] Chạy được `terraform init`.
- [ ] Hiểu `.terraform/` là gì.
- [ ] Biết `.terraform.lock.hcl` dùng để lock provider version.
- [ ] Chạy được `terraform fmt`.
- [ ] Chạy được `terraform validate`.
- [ ] Đọc được `terraform plan`.
- [ ] Hiểu create/update/destroy/replace trong plan.
- [ ] Chạy được `terraform apply`.
- [ ] Hiểu state file lưu gì.
- [ ] Không commit `terraform.tfstate`.
- [ ] Biết local state vs remote state.
- [ ] Biết state locking là gì.
- [ ] Biết drift là gì.
- [ ] Biết module là gì.
- [ ] Biết root module vs child module.
- [ ] Biết gọi registry module.
- [ ] Biết dùng module output.