# W8 Day 1 - Terraform Fundamentals (IaC Overview + HCL Syntax)

**Date:** 01/06/2026
**Track:** Cloud / DevOps Phase 2
**Topic:** Terraform Part 1 - Infrastructure as Code (IaC) & HCL Fundamentals

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

Traditional approach:

1. Login to AWS Console
2. Create VPC
3. Create Security Group
4. Create EC2
5. Create S3 Bucket

Problems:

* Time consuming
* Human errors
* Difficult to reproduce
* No version control
* Hard to review changes

IaC solves these problems by defining infrastructure in code.

Example:

```hcl
resource "aws_instance" "web" {
  instance_type = "t2.micro"
}
```

Benefits of IaC:

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

Terraform supports:

* AWS
* Azure
* Google Cloud
* Kubernetes
* Docker
* GitHub
* Many other providers

Terraform uses a declarative approach.

Instead of saying:

"Create an EC2 instance"

we describe:

"I want one EC2 instance"

Terraform figures out how to achieve that desired state.

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

Example with AWS:

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

Example with Local Provider:

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

Terraform follows a Desired State model.

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
Create/Modify Infrastructure
        ↓
Update State File
```

---

## terraform init

Purpose:

* Initialize project
* Download providers
* Create .terraform directory

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

Example:

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

Terraform will ask for confirmation before applying changes.

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

Terraform stores infrastructure information inside:

```text
terraform.tfstate
```

State contains:

* Resource information
* Resource IDs
* Resource attributes
* Dependency relationships

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

Basic structure:

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

## terraform block

Used to configure Terraform itself.

```hcl
terraform {
  required_version = ">= 1.0"
}
```

---

## provider block

Defines how Terraform connects to a platform.

Example:

```hcl
provider "aws" {
  region = "ap-southeast-1"
}
```

Provider examples:

* AWS
* Azure
* Google
* Kubernetes
* Docker
* Local

---

## resource block

Represents infrastructure managed by Terraform.

Example:

```hcl
resource "aws_s3_bucket" "learning" {
  bucket = "learning-bucket"
}
```

Resource examples:

* aws_instance
* aws_s3_bucket
* aws_vpc
* kubernetes_deployment
* local_file

---

## variable block

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

## output block

Displays values after apply.

Example:

```hcl
output "file_name" {
  value = local_file.student.filename
}
```

---

## locals block

Defines reusable local values.

Example:

```hcl
locals {
  project_name = "aws-accelerator"
}
```

---

## data block

Reads existing information without creating resources.

Example:

```hcl
data "aws_caller_identity" "current" {}
```

Used when:

* Reading existing AWS resources
* Reading account information
* Looking up AMI IDs

---

# Hands-on Practice

## Project Structure

```text
day-a/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── terraform.tfstate
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

Initialize project:

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

# Next Steps (Day 2)

Topics to study:

* Terraform State Management
* Terraform Modules
* Terraform Best Practices
* Terraform Lifecycle
* Terraform Backend
* Remote State
* AWS Resources with Terraform
