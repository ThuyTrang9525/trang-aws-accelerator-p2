resource "terraform_data" "wait_for_minikube" {
  depends_on = [aws_instance.minikube]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.minikube.private_key_pem
    host        = aws_instance.minikube.public_ip
    timeout     = "10m" # Đợi đủ lâu để SSH mở
  }

  provisioner "remote-exec" {
    inline = [
      "until minikube status | grep -q 'host: Running'; do sleep 5; done",
      "echo 'Minikube is ready!'"
    ]
  }
}