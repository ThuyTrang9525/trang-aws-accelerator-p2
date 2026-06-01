# Infrastructure as Code (IaC)

## Traditional Infrastructure

Trước đây DevOps hoặc Cloud Engineer thường:

1. Login AWS Console
2. Create VPC
3. Create EC2
4. Create Security Group
5. Create S3

Các bước này được thực hiện bằng tay.

### Problems

1. Tốn thời gian
2. Dễ sai sót
3. Không có version control
4. Khó tái sử dụng
5. Không thể review như source code

---

## Infrastructure as Code

Infrastructure được định nghĩa bằng code.

Ví dụ:

resource "aws_instance" "web" {
  ami = "ami-123456"
  instance_type = "t2.micro"
}

Thay vì click tạo EC2 trên AWS Console,
Terraform sẽ tạo EC2 thông qua code.

---

## Benefits

### Automation

Tự động tạo infrastructure.

### Version Control

Có thể lưu trên GitHub.

### Reusability

Tái sử dụng nhiều lần.

### Consistency

Mọi môi trường giống nhau.

### Collaboration

Có thể pull request và review code.