resource "tls_private_key" "minikube" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {

  filename = "${path.module}/minikube-key.pem"

  content = tls_private_key.minikube.private_key_pem

  file_permission = "0400"
}

resource "aws_key_pair" "minikube" {

  key_name = "minikube-key"

  public_key = tls_private_key.minikube.public_key_openssh
}