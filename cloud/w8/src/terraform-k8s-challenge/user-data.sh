#!/bin/bash
# (Các phần cài đặt docker, kubectl, minikube giữ nguyên)

# KHÔNG DÙNG lệnh chạy trực tiếp, hãy tạo systemd service
cat <<EOF > /etc/systemd/system/k8s-forward.service
[Unit]
Description=Forward traffic to Minikube
After=network.target

[Service]
ExecStart=/usr/local/bin/kubectl port-forward --address 0.0.0.0 service/nginx 30080:80
Restart=always
User=ubuntu

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable k8s-forward
systemctl start k8s-forward