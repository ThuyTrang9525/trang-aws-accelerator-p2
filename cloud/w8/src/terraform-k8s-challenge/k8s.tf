resource "kubernetes_deployment" "app" {
  depends_on = [null_resource.deploy_app]

  metadata {
    name = "my-app"
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "my-app" }
    }
    template {
      metadata {
        labels = { app = "my-app" }
      }
      spec {
        container {
          # Thay nginx bằng http-echo
          image = "hashicorp/http-echo"
          name  = "my-app"
          # Truyền tham số để hiển thị thông điệp của bạn
          args = ["-text", "Hello from Trang's AWS Challenge!"]
          port {
            container_port = 5678
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app" {
  depends_on = [null_resource.deploy_app]
  metadata { name = "my-app" }
  spec {
    selector = { app = "my-app" }
    type     = "NodePort"
    port {
      port        = 80
      target_port = 5678
      node_port   = 30080
    }
  }
}