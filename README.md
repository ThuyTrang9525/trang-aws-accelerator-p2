# W8 Reflection Report

## Terraform & Kubernetes Foundations

**Student:** Bùi Thị Thùy Trang
**Week:** W8
**Period:** 01/06/2026 – 03/06/2026
**Track:** Cloud / DevOps Phase 2

---

# 1. Overview

Trong tuần 8, em tập trung vào hai chủ đề quan trọng của Cloud & DevOps:

1. Terraform Fundamentals & State Management
2. Kubernetes Basics & Core Production Concepts

Mục tiêu của tuần là hiểu cách quản lý hạ tầng bằng Infrastructure as Code (IaC) và cách vận hành ứng dụng containerized trên Kubernetes.

---

# 2. Day 1 – Terraform Fundamentals

## Nội dung đã học

### Infrastructure as Code (IaC)

Em hiểu rằng Infrastructure as Code là phương pháp quản lý hạ tầng bằng code thay vì thao tác thủ công trên AWS Console.

Thay vì tạo:

* VPC
* EC2
* RDS
* Security Group

bằng tay, ta có thể định nghĩa bằng Terraform.

Ví dụ:

```hcl
resource "aws_instance" "web" {
  instance_type = "t2.micro"
}
```

---

### Terraform

Terraform là công cụ IaC của HashiCorp.

Terraform hoạt động theo mô hình Declarative:

Không mô tả từng bước thực hiện mà mô tả trạng thái mong muốn của hệ thống.

---

### Terraform Workflow

Em đã thực hành quy trình:

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
```

Hiểu được ý nghĩa của từng lệnh:

| Command            | Mục đích             |
| ------------------ | -------------------- |
| terraform init     | Khởi tạo project     |
| terraform validate | Kiểm tra syntax      |
| terraform plan     | Xem thay đổi dự kiến |
| terraform apply    | Thực thi thay đổi    |
| terraform destroy  | Xóa resource         |

---

### HCL Fundamentals

Các block quan trọng:

* terraform
* provider
* resource
* variable
* output
* local
* data

Ví dụ:

```hcl
provider "aws" {
  region = "us-east-1"
}
```

---

### Terraform State

Terraform lưu trạng thái hạ tầng trong:

```text
terraform.tfstate
```

State giúp Terraform biết:

* Resource nào đã tồn tại
* Resource nào cần tạo
* Resource nào cần cập nhật

---

### Hands-on

Em đã thực hành:

```hcl
resource "local_file" "student" {
  filename = "student.txt"
  content  = var.student_name
}
```

và chạy:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

---

## Điều em hiểu rõ

* Khái niệm IaC
* Terraform workflow
* HCL syntax cơ bản
* Resource, Variable, Output
* Vai trò của Terraform State

---

## Điều cần học thêm

* Backend configuration
* Remote State
* Terraform Modules
* Production Terraform Structure

---

# 3. Day 2 – Kubernetes Basics

## Nội dung đã học

### Kubernetes Overview

Kubernetes là nền tảng orchestration dùng để:

* Deploy container
* Scaling
* Load balancing
* Service discovery
* Rolling update
* Self-healing

---

### Cluster Architecture

Kiến trúc cơ bản:

```text
Cluster
│
├── Control Plane
│   ├── API Server
│   ├── Scheduler
│   ├── Controller Manager
│   └── etcd
│
└── Worker Nodes
    └── Pods
```

---

### Pod

Pod là đơn vị deploy nhỏ nhất trong Kubernetes.

Một Pod có thể chứa:

* Một container
* Nhiều container liên quan

---

### Deployment

Deployment chịu trách nhiệm:

* Tạo Pod
* Scale Pod
* Rolling Update
* Rollback

Flow:

```text
Deployment
      ↓
ReplicaSet
      ↓
Pods
```

---

### Service

Service cung cấp:

* Stable IP
* DNS
* Load Balancing

Các loại:

* ClusterIP
* NodePort
* LoadBalancer
* ExternalName

---

### Labels & Selectors

Labels giúp phân loại tài nguyên.

Ví dụ:

```yaml
app: backend
env: dev
version: v1
```

Service sử dụng selector để tìm Pod phù hợp.

---

### Scaling

Scale thủ công:

```bash
kubectl scale deployment app --replicas=4
```

ReplicaSet đảm bảo số lượng Pod đúng với desired state.

---

### Rolling Update & Rollback

Update image:

```bash
kubectl set image deployment app ...
```

Kiểm tra:

```bash
kubectl rollout status deployment app
```

Rollback:

```bash
kubectl rollout undo deployment app
```

---

## Điều em hiểu rõ

* Cluster Architecture
* Pod
* Deployment
* Service
* ReplicaSet
* Rolling Update
* Rollback

---

## Điều cần học thêm

* Networking trong Kubernetes
* Storage
* Production Architecture
* Monitoring

---

# 4. Day 3 – Terraform Advanced & Kubernetes Production Concepts

## Terraform State Management

### Local State

Lưu trên máy local:

```text
terraform.tfstate
```

Phù hợp:

* Learning
* Personal Project

---

### Remote State

Production thường dùng:

```text
S3
+
DynamoDB
```

Ví dụ:

```text
Terraform
    ↓
S3 Backend
    ↓
State File
```

---

### State Locking

Khi nhiều người cùng làm việc:

```text
Engineer A
terraform apply

Engineer B
terraform apply
```

Nếu cùng ghi vào state sẽ gây xung đột.

DynamoDB Locking giúp:

```text
Acquire Lock
        ↓
Apply
        ↓
Release Lock
```

Ngăn chặn corruption của state.

---

## Terraform Modules

Module tương tự function trong lập trình.

Cấu trúc:

```text
modules/
└── ec2/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

Ví dụ gọi module:

```hcl
module "web" {
  source = "./modules/ec2"
}
```

Lợi ích:

* Reusable
* Maintainable
* Scalable
* Standardized

---

## Terraform Best Practices

### Không hard-code

Sử dụng:

```hcl
var.environment
```

thay vì:

```hcl
"dev"
```

---

### Naming Convention

Ví dụ:

```text
dev-web-ec2
staging-web-ec2
prod-web-ec2
```

---

### Folder Structure

```text
main.tf
variables.tf
outputs.tf
providers.tf
versions.tf
```

---

### Không commit state

```gitignore
terraform.tfstate
terraform.tfstate.backup
```

---

## ADR (Architecture Decision Record)

ADR là tài liệu giải thích:

* Tại sao chọn giải pháp này
* Tại sao không chọn giải pháp khác

Ví dụ:

### Decision

Sử dụng Remote State trên S3.

### Reason

* Team collaboration
* Backup
* Versioning

### Alternative

Local State.

### Trade-off

Tốn thêm chi phí S3 và DynamoDB.

---

# Kubernetes Production Concepts

## ConfigMap

Lưu configuration không nhạy cảm.

Ví dụ:

* API URL
* Hostname
* Feature Flags

---

## Secret

Lưu dữ liệu nhạy cảm:

* Password
* JWT Secret
* API Key

---

## Liveness Probe

Kiểm tra ứng dụng còn hoạt động hay không.

Nếu fail:

```text
Restart Container
```

---

## Readiness Probe

Kiểm tra ứng dụng có sẵn sàng nhận traffic hay chưa.

Nếu fail:

```text
Remove khỏi Service
```

---

## Startup Probe

Dùng cho ứng dụng khởi động chậm.

Ví dụ:

* Spring Boot
* Django
* Java Monolith

---

## Ingress

Cung cấp:

* Reverse Proxy
* Routing
* SSL Termination

Flow:

```text
Internet
    ↓
Ingress
    ↓
Services
    ↓
Pods
```

---

## Persistent Volume (PV)

Storage thật trong cluster.

Ví dụ:

* EBS
* EFS
* NFS

---

## Persistent Volume Claim (PVC)

Request sử dụng storage.

Flow:

```text
Pod
 ↓
PVC
 ↓
PV
 ↓
Disk
```

---

## NetworkPolicy

Kiểm soát traffic giữa Pod.

Tương tự:

```text
AWS Security Group
```

trong môi trường Kubernetes.

---

## Namespace

Tách môi trường:

```text
dev
staging
prod
```

---

## Horizontal Pod Autoscaler (HPA)

Tự động scale Pod theo:

* CPU
* Memory
* Custom Metrics

Ví dụ:

```text
CPU > 70%
      ↓
Scale Out
```

---

# 5. Kết nối kiến thức Terraform và Kubernetes

Sau 3 ngày học, em nhận thấy Terraform và Kubernetes bổ trợ cho nhau:

```text
Terraform
    ↓
Provision Infrastructure
(VPC, EKS, IAM, RDS)

Kubernetes
    ↓
Deploy Applications
(Pods, Services, Ingress)
```

Terraform giúp tạo nền tảng hạ tầng.

Kubernetes giúp vận hành workload trên hạ tầng đó.

---

# 6. Những điều em hiểu rõ nhất

* Infrastructure as Code
* Terraform Workflow
* Terraform State
* Terraform Modules
* Kubernetes Architecture
* Pod
* Deployment
* Service
* ConfigMap
* Secret
* Ingress
* HPA

---

# 7. Những điều em cần đào sâu thêm

## Terraform

* Backend Migration
* State Recovery
* Workspace
* Multi-environment Strategy
* Advanced Modules

## Kubernetes

* Ingress Controller
* CNI Networking
* StorageClass
* StatefulSet
* Helm
* Monitoring & Logging
* EKS Production Architecture

---

# 8. Câu hỏi thảo luận với Mentor

### Terraform

1. Trong môi trường production, khi Terraform state bị corruption hoặc mất đồng bộ với hạ tầng thực tế, quy trình xử lý phổ biến là gì?

2. Trong dự án lớn, khi nào nên tách một thành nhiều state files thay vì dùng một state duy nhất?

3. Workspaces và thư mục tách biệt cho Dev/Staging/Prod thường được ưu tiên theo trường hợp nào?

---

### Kubernetes

1. Trong thực tế EKS production, khi nào nên sử dụng Ingress và khi nào nên sử dụng LoadBalancer Service trực tiếp?

2. Có best practice nào để quản lý Secret trên Kubernetes ngoài AWS Secrets Manager và External Secrets Operator không?

3. HPA chỉ scale theo CPU/Memory có đủ cho production hay nên dùng custom metrics như request rate hoặc queue length?

---

# 9. Reflection

Qua 3 ngày học, em đã chuyển từ việc chỉ biết sử dụng AWS Console sang hiểu rõ hơn về tư duy Infrastructure as Code và Container Orchestration.

Terraform giúp em hiểu cách xây dựng hạ tầng có thể lặp lại, kiểm soát bằng version và làm việc nhóm hiệu quả.

Kubernetes giúp em hiểu cách triển khai ứng dụng hiện đại với khả năng tự phục hồi, mở rộng và vận hành ổn định.

Trong thời gian tới, em muốn tiếp tục đào sâu về:

* AWS EKS
* Terraform Production Architecture
* Kubernetes Networking
* Kubernetes Storage
* Helm
* GitOps
* CI/CD Pipeline
* Observability

để có thể tự triển khai và vận hành một hệ thống cloud-native hoàn chỉnh trên AWS.
