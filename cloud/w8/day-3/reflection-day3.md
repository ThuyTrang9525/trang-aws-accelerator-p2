# Terraform Advanced Concepts - State Management, Modules & Best Practices

## Mục tiêu học tập

Sau khi hoàn thành nội dung này, bạn có thể:

* Hiểu cách Terraform quản lý trạng thái hạ tầng (State).
* Thiết lập Remote State trên AWS.
* Hiểu cơ chế State Locking bằng DynamoDB.
* Viết và tái sử dụng Terraform Modules.
* Áp dụng các Best Practices trong môi trường thực tế.
* Hiểu vai trò của ADR (Architecture Decision Records).
* Chuẩn bị các câu hỏi thảo luận với mentor.

---

# 1. State Management (Quản lý trạng thái)

## Terraform State là gì?

Terraform sử dụng file trạng thái (`terraform.tfstate`) để theo dõi toàn bộ tài nguyên mà nó đã tạo ra.

Ví dụ:

```hcl
resource "aws_s3_bucket" "demo" {
  bucket = "my-demo-bucket"
}
```

Sau khi chạy:

```bash
terraform apply
```

Terraform sẽ lưu thông tin như:

* ARN
* Resource ID
* Bucket Name
* Metadata

vào file:

```text
terraform.tfstate
```

Terraform không đọc trực tiếp hạ tầng AWS mỗi lần chạy.

Thay vào đó nó:

1. Đọc state hiện tại
2. So sánh với code Terraform
3. Tạo execution plan
4. Apply các thay đổi cần thiết

---

## Tại sao không nên lưu State cục bộ?

Ví dụ:

Developer A:

```text
terraform.tfstate
```

Developer B:

```text
terraform.tfstate
```

Mỗi người giữ một bản state riêng.

Khi cùng chạy:

```bash
terraform apply
```

sẽ dễ xảy ra:

* Drift
* Ghi đè tài nguyên
* Mất đồng bộ hạ tầng
* Xóa nhầm resource

Đây là lý do các team production không dùng local state.

---

# Remote State

Remote State là việc lưu file state trên một hệ thống tập trung.

Trên AWS thường dùng:

```text
Terraform
    ↓
S3 Bucket
    ↓
terraform.tfstate
```

Ví dụ:

```hcl
terraform {
  backend "s3" {
    bucket = "company-terraform-state"
    key    = "network/dev/terraform.tfstate"
    region = "us-east-1"
  }
}
```

Lợi ích:

* Team dùng chung một state
* Backup tự động
* Versioning
* Tránh mất dữ liệu
* Dễ audit

---

## S3 Versioning

Nên bật Versioning:

```text
S3 Bucket
├── Version 1
├── Version 2
├── Version 3
└── Current
```

Nếu state bị hỏng:

```text
Restore Previous Version
```

là có thể khôi phục.

---

# State Locking

## Vấn đề

Giả sử:

Developer A:

```bash
terraform apply
```

đang chạy.

Cùng lúc:

Developer B:

```bash
terraform apply
```

cũng chạy.

Kết quả:

```text
Race Condition
```

Cả hai cùng sửa state.

State có thể bị:

* Corrupt
* Lost Update
* Drift

---

## Giải pháp: DynamoDB Locking

Terraform sử dụng DynamoDB như một cơ chế khóa.

Kiến trúc:

```text
Terraform
     │
     ▼
 DynamoDB Lock
     │
     ▼
    S3
```

Ví dụ:

```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "network/dev.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}
```

---

## Cách hoạt động

Developer A:

```bash
terraform apply
```

Terraform tạo lock:

```text
LockID = network/dev.tfstate
```

trong DynamoDB.

Developer B:

```bash
terraform apply
```

sẽ nhận:

```text
Error acquiring state lock
```

và phải chờ.

---

## Nếu Apply bị lỗi giữa chừng?

Ví dụ:

```text
Laptop mất điện
VPN disconnect
Terminal bị kill
```

Lock có thể còn tồn tại.

Kiểm tra:

```bash
terraform force-unlock LOCK_ID
```

Ví dụ:

```bash
terraform force-unlock 12345678
```

Lưu ý:

Chỉ force-unlock khi chắc chắn không còn ai đang chạy Terraform.

---

# 2. Terraform Modules

## Module là gì?

Module giống như:

```java
function
class
library
```

trong lập trình.

Thay vì copy-paste code:

```hcl
resource "aws_vpc" ...
resource "aws_subnet" ...
resource "aws_route_table" ...
```

nhiều lần.

Ta đóng gói thành module.

---

# Cấu trúc Module

```text
modules/
└── vpc/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
```

---

## variables.tf

Input của module.

```hcl
variable "cidr_block" {
  type = string
}
```

---

## main.tf

Logic chính.

```hcl
resource "aws_vpc" "this" {
  cidr_block = var.cidr_block
}
```

---

## outputs.tf

Giá trị trả về.

```hcl
output "vpc_id" {
  value = aws_vpc.this.id
}
```

---

# Gọi Module

## Local Module

```hcl
module "vpc" {
  source = "./modules/vpc"

  cidr_block = "10.0.0.0/16"
}
```

---

## Terraform Registry

Ví dụ module VPC nổi tiếng:

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "demo-vpc"
}
```

---

# Khi nào nên tạo Module?

Nên tạo module khi:

* Dùng từ 2 lần trở lên
* Có logic riêng
* Muốn tái sử dụng
* Muốn chuẩn hóa

Ví dụ:

```text
VPC Module
ECS Module
RDS Module
ALB Module
```

---

# Khi nào KHÔNG nên tạo Module?

Không nên nếu:

* Chỉ dùng 1 lần
* Logic quá đơn giản
* Chưa xác định được nhu cầu tái sử dụng

Over-engineering cũng là một vấn đề.

---

# 3. Terraform Best Practices

## 1. Đặt tên nhất quán

Tốt:

```hcl
aws_vpc.main
aws_subnet.public
aws_subnet.private
```

Không nên:

```hcl
aws_vpc.v1
aws_subnet.test123
```

---

## 2. Không hardcode

Không nên:

```hcl
cidr_block = "10.0.0.0/16"
```

Nên:

```hcl
cidr_block = var.vpc_cidr
```

---

## 3. Tách Environment

Ví dụ:

```text
environments/
├── dev
├── staging
└── prod
```

---

## 4. Sử dụng Remote State

Production:

```text
S3 + DynamoDB
```

gần như là bắt buộc.

---

## 5. Commit Code, Không Commit State

Không nên:

```text
terraform.tfstate
terraform.tfstate.backup
```

trong Git.

Thêm vào:

```gitignore
*.tfstate
*.tfstate.backup
```

---

# 4. ADR (Architecture Decision Records)

## ADR là gì?

ADR là tài liệu ghi lại:

```text
Tại sao chúng ta đưa ra quyết định kỹ thuật này?
```

Thay vì chỉ ghi:

```text
Chúng tôi dùng VPC.
```

ADR giải thích:

```text
Tại sao dùng VPC?
Tại sao CIDR này?
Tại sao không dùng Transit Gateway?
```

---

## Cấu trúc ADR

### Context

Bối cảnh.

### Decision

Quyết định.

### Consequences

Hệ quả.

---

## Ví dụ

### ADR-001: Sử dụng S3 + DynamoDB cho Terraform State

Context:

Team có nhiều thành viên cùng quản lý hạ tầng.

Decision:

Sử dụng S3 Remote State và DynamoDB State Locking.

Consequences:

Ưu điểm:

* Tránh state corruption
* Hỗ trợ teamwork
* Backup dễ dàng

Nhược điểm:

* Tăng thêm tài nguyên AWS
* Cần quản lý IAM

---

# 5. Câu hỏi thảo luận với Mentor

## Câu hỏi 1 - State

Khi làm việc nhóm, nếu một lệnh terraform apply bị dừng giữa chừng và state chưa được cập nhật hoàn toàn, ngoài DynamoDB locking thì team thường áp dụng quy trình nào để tránh state drift?

---

## Câu hỏi 2 - Modules

Có tiêu chí thực tế nào để quyết định một đoạn Terraform nên được tách thành module dùng chung hay giữ lại trong project hiện tại?

---

## Câu hỏi 3 - Environment Strategy

Trong môi trường production, giữa Terraform Workspaces và cấu trúc thư mục riêng cho Dev/Staging/Prod, phương pháp nào được sử dụng phổ biến hơn và tại sao?

---

## Key Takeaways

* Terraform State là nguồn dữ liệu quan trọng nhất của Terraform.
* Remote State giúp nhiều người cùng quản lý hạ tầng an toàn.
* DynamoDB Locking ngăn xung đột khi nhiều người chạy Terraform.
* Module giúp tái sử dụng code và chuẩn hóa kiến trúc.
* Best Practices giúp hạ tầng dễ bảo trì và mở rộng.
* ADR giúp lưu lại lý do của các quyết định kỹ thuật quan trọng.
