# Kubernetes Cheat Sheet

Tài liệu tóm tắt các lệnh `kubectl` thường dùng trong quá trình làm việc với Cluster.

## 1. Lệnh Điều khiển (Management)
* `kubectl apply -f <file.yaml>`: Tạo hoặc cập nhật tài nguyên.
* `kubectl delete -f <file.yaml>`: Xóa tài nguyên từ file.
* `kubectl delete <resource> <name>`: Xóa một tài nguyên cụ thể.

## 2. Lệnh Kiểm tra (Inspection)
* `kubectl get <resource>`: Liệt kê tài nguyên (pods, deployments, nodes, configmaps, secrets).
* `kubectl get <resource> -o wide`: Xem thông tin chi tiết hơn (IP, Node).
* `kubectl get <resource> -w`: Theo dõi sự thay đổi thời gian thực.
* `kubectl describe <resource> <name>`: Xem chi tiết cấu hình và sự kiện (logs sự kiện).

## 3. Lệnh Gỡ lỗi (Debugging)
* `kubectl logs <pod-name>`: Xem logs của container.
* `kubectl logs -f <pod-name>`: Xem logs thời gian thực.
* `kubectl exec -it <pod-name> -- /bin/sh`: Truy cập vào bên trong container.

## 4. Quản lý hệ thống
* `kubectl get nodes`: Kiểm tra trạng thái các Node trong cụm.
* `kubectl cluster-info`: Xem thông tin kết nối API Server.

---
*Ghi chú: Luôn sử dụng `kubectl <command> --help` nếu bạn quên cú pháp.*tree -L 2