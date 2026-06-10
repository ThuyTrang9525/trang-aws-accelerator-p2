resource "null_resource" "deploy_app" {
  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = aws_instance.minikube.public_ip
    private_key = tls_private_key.minikube.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      # Đợi cho đến khi cloud-init cài xong các thứ trong user-data.sh
      "cloud-init status --wait",
      "echo 'Hệ thống đã sẵn sàng, deploy app...'",
      "kubectl create deployment my-app --image=hashicorp/http-echo --port=5678 --dry-run=client -o yaml | kubectl apply -f -",
      "kubectl expose deployment my-app --port=80 --target-port=5678 --type=NodePort --dry-run=client -o yaml | kubectl apply -f -"
    ]
  }
}