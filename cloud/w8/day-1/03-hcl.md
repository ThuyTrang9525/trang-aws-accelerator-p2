# HCL Syntax

## Block Structure

block_type "label1" "label2" {
    argument = value
}

Example:

resource "aws_instance" "web" {
    instance_type = "t2.micro"
}

---

## Data Types

string

"name"

number

123

bool

true

false

list

["a","b","c"]

map

{
  env = "dev"
}