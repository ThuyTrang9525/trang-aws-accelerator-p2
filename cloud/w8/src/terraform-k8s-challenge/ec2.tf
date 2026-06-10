data "aws_ami" "ubuntu" {

  most_recent = true

  owners = ["099720109477"]

  filter {
    name = "name"

    values = [
      "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    ]
  }
}
resource "aws_instance" "minikube" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  key_name = aws_key_pair.minikube.key_name

  subnet_id = aws_subnet.public_a.id

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  user_data = file("${path.module}/user-data.sh")

  tags = {
    Name = "minikube-node"
  }
  timeouts {
    create = "10m"
  }
}