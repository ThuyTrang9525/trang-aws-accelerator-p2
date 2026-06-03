# W8 - Day B - Kubernetes Basics Summary

> Source: Kubernetes Official Tutorial - Kubernetes Basics
> Date: 02/06/2026

---

# 1. Kubernetes là gì?

Kubernetes (K8s) là nền tảng mã nguồn mở dùng để:

* Deploy container
* Scale ứng dụng
* Load balancing
* Service discovery
* Self-healing
* Rolling update

Mục tiêu:

* Ứng dụng luôn sẵn sàng (High Availability)
* Triển khai phiên bản mới không downtime
* Tự động quản lý container

---

# 2. Kubernetes Cluster Architecture

Một Kubernetes Cluster gồm:

```text
Cluster
│
├── Control Plane
│   ├── API Server
│   ├── Scheduler
│   ├── Controller Manager
│   └── etcd
│
└── Worker Nodes
    ├── Pod
    ├── Pod
    └── Pod
```

---

## Control Plane

Chịu trách nhiệm:

* Quản lý cluster
* Scheduling Pod
* Scaling
* Rolling Update
* Duy trì desired state

---

## Node

Node là máy chạy workload.

Có thể là:

* VM
* Physical Server

Mỗi Node gồm:

```text
Node
│
├── Kubelet
├── Container Runtime
│   ├── containerd
│   └── CRI-O
└── Pods
```

---

## Kubelet

Agent chạy trên mỗi Node.

Nhiệm vụ:

* Nhận lệnh từ Control Plane
* Tạo Pod
* Theo dõi trạng thái Pod
* Báo cáo về Control Plane

---

# 3. Minikube

## Minikube là gì?

Minikube là Kubernetes local cluster.

Mục đích:

* Học Kubernetes
* Test ứng dụng local
* Thực hành lab

---

## Khởi động Cluster

```bash
minikube start
```

Kiểm tra:

```bash
minikube status
```

---

## Dừng Cluster

```bash
minikube stop
```

---

## Xóa Cluster

```bash
minikube delete
```

---

# 4. kubectl

kubectl là CLI để làm việc với Kubernetes.

---

## Kiểm tra cluster

```bash
kubectl cluster-info
```

---

## Kiểm tra node

```bash
kubectl get nodes
```

Ví dụ:

```text
NAME       STATUS   ROLES
minikube   Ready    control-plane
```

---

# 5. Deployment

## Deployment là gì?

Deployment là object quản lý vòng đời ứng dụng.

Deployment chịu trách nhiệm:

* Tạo Pod
* Scale Pod
* Update Pod
* Rollback Pod

---

## Flow

```text
Deployment
      │
      ▼
ReplicaSet
      │
      ▼
Pods
```

---

## Tạo Deployment

```bash
kubectl create deployment kubernetes-bootcamp \
--image=gcr.io/google-samples/kubernetes-bootcamp:v1
```

---

## Xem Deployment

```bash
kubectl get deployments
```

---

## Chi tiết Deployment

```bash
kubectl describe deployment kubernetes-bootcamp
```

---

# 6. Pod

## Pod là gì?

Pod là đơn vị deploy nhỏ nhất trong Kubernetes.

Một Pod có thể chứa:

* 1 container
* Nhiều container liên quan

---

## Pod chứa

```text
Pod
│
├── Container A
├── Container B
├── Shared Network
└── Shared Storage
```

---

## Xem Pod

```bash
kubectl get pods
```

---

## Chi tiết Pod

```bash
kubectl describe pod <pod-name>
```

---

## Log Pod

```bash
kubectl logs <pod-name>
```

---

# 7. Self-Healing

Một trong những tính năng quan trọng nhất của Kubernetes.

Ví dụ:

```text
Pod chết
     │
     ▼
Deployment phát hiện
     │
     ▼
Tạo Pod mới
```

Developer không cần restart thủ công.

---

# 8. Proxy

Pods chạy trong private network.

Muốn truy cập từ máy local:

```bash
kubectl proxy
```

API server được expose tại:

```text
http://localhost:8001
```

---

## Lấy Pod Name

```bash
export POD_NAME=$(kubectl get pods \
-o go-template \
--template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```

---

## Truy cập Pod

```bash
curl http://localhost:8001/api/v1/namespaces/default/pods/$POD_NAME:8080/proxy/
```

---

# 9. Service

## Vấn đề

Pod có IP động.

Ví dụ:

```text
Pod A
IP = 10.0.0.5

Restart

Pod B
IP = 10.0.0.7
```

Frontend sẽ bị lỗi nếu gọi trực tiếp Pod IP.

---

## Giải pháp

Service cung cấp:

* Stable IP
* DNS
* Load Balancing

---

## Kiến trúc

```text
Client
   │
Service
   │
┌──┴──┐
Pod  Pod
Pod  Pod
```

---

# 10. Các loại Service

## ClusterIP

Mặc định.

Chỉ truy cập trong cluster.

```text
Pod → Service → Pod
```

---

## NodePort

Expose ra ngoài.

```text
NodeIP:30080
```

---

## LoadBalancer

Cloud Provider tạo LB.

```text
Internet
    │
LoadBalancer
    │
Service
    │
Pods
```

---

## ExternalName

Map DNS bên ngoài.

Ví dụ:

```yaml
externalName: database.company.com
```

---

# 11. Expose Service

Expose Deployment:

```bash
kubectl expose deployment kubernetes-bootcamp \
--type=NodePort \
--port=8080
```

---

## Kiểm tra Service

```bash
kubectl get svc
```

---

## Chi tiết Service

```bash
kubectl describe svc kubernetes-bootcamp
```

---

# 12. Labels & Selectors

Label là metadata dạng key-value.

Ví dụ:

```yaml
app: backend
version: v1
env: dev
```

---

## Tìm Pod theo Label

```bash
kubectl get pods -l app=kubernetes-bootcamp
```

---

## Thêm Label

```bash
kubectl label pod POD_NAME version=v1
```

---

## Vai trò của Selector

Service tìm Pod thông qua selector:

```yaml
selector:
  app: backend
```

---

# 13. Scaling

## Scale Out

Tăng số lượng Pod.

```bash
kubectl scale deployment/kubernetes-bootcamp \
--replicas=4
```

---

## Scale In

Giảm số lượng Pod.

```bash
kubectl scale deployment/kubernetes-bootcamp \
--replicas=2
```

---

## Kiểm tra

```bash
kubectl get deployments
```

```bash
kubectl get pods
```

---

# 14. ReplicaSet

ReplicaSet đảm bảo số lượng Pod đúng với mong muốn.

Ví dụ:

```text
Desired = 4

Hiện tại = 3

ReplicaSet tạo thêm 1 Pod
```

---

## Xem ReplicaSet

```bash
kubectl get rs
```

---

# 15. Load Balancing

Khi có nhiều Pod:

```text
Service
│
├── Pod 1
├── Pod 2
├── Pod 3
└── Pod 4
```

Service sẽ phân phối request.

Ví dụ:

```bash
curl service-url
```

Lần lượt:

```text
Pod1
Pod2
Pod3
Pod1
Pod4
```

---

# 16. Rolling Update

## Mục tiêu

Update ứng dụng mà không downtime.

---

## Update Image

```bash
kubectl set image deployment/kubernetes-bootcamp \
kubernetes-bootcamp=docker.io/jocatalin/kubernetes-bootcamp:v2
```

---

## Kiểm tra tiến trình

```bash
kubectl rollout status deployment/kubernetes-bootcamp
```

---

## Quá trình

```text
Old Pod v1
Old Pod v1
Old Pod v1

↓

New Pod v2
Old Pod v1
Old Pod v1

↓

New Pod v2
New Pod v2
Old Pod v1

↓

New Pod v2
New Pod v2
New Pod v2
```

Không downtime.

---

# 17. Rollback

Nếu update lỗi:

```bash
kubectl rollout undo deployment/kubernetes-bootcamp
```

Rollback về version ổn định gần nhất.

---

## Ví dụ lỗi

```bash
kubectl set image deployment/kubernetes-bootcamp \
kubernetes-bootcamp=v10
```

Pod:

```text
ImagePullBackOff
```

Rollback:

```bash
kubectl rollout undo deployment/kubernetes-bootcamp
```

---

# 18. Các lệnh kubectl quan trọng

## Cluster

```bash
kubectl cluster-info
kubectl get nodes
```

---

## Deployment

```bash
kubectl get deployments
kubectl describe deployment <name>
kubectl scale deployment <name> --replicas=4
```

---

## Pod

```bash
kubectl get pods
kubectl describe pod <name>
kubectl logs <name>
kubectl exec -it <name> -- bash
```

---

## Service

```bash
kubectl get svc
kubectl describe svc <name>
kubectl delete svc <name>
```

---

## ReplicaSet

```bash
kubectl get rs
```

---
# 19. ConfigMap

## ConfigMap là gì?

ConfigMap dùng để lưu trữ cấu hình không nhạy cảm của ứng dụng.

Ví dụ:

* API URL
* Environment Variables
* Application Config
* Feature Flags

Thay vì hard-code:

```java
DB_HOST=localhost
```

ta đưa vào ConfigMap.

---

## Ví dụ ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config

data:
  DB_HOST: mysql-service
  LOG_LEVEL: INFO
  APP_ENV: production
```

---

## Sử dụng ConfigMap trong Pod

```yaml
env:
- name: DB_HOST
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: DB_HOST
```

---

## Use Cases

* URL endpoint
* Hostname
* Application settings
* Feature toggle

---

## Best Practice

ConfigMap chỉ dùng cho:

✅ Configuration

Không dùng cho:

❌ Password

❌ API Key

❌ Secret Token

---

# 20. Secret

## Secret là gì?

Secret dùng để lưu dữ liệu nhạy cảm.

Ví dụ:

* Database Password
* JWT Secret
* API Key
* SSL Certificate

---

## Ví dụ Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret

type: Opaque

data:
  password: cGFzc3dvcmQ=
```

(Base64 encoded)

---

## Mount Secret

```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: app-secret
      key: password
```

---

## ConfigMap vs Secret

| ConfigMap     | Secret           |
| ------------- | ---------------- |
| Non-sensitive | Sensitive        |
| Plain config  | Password/API Key |
| Readable      | Encoded          |

---

## Production Best Practice

Không commit Secret vào Git.

Nên dùng:

* AWS Secrets Manager
* HashiCorp Vault
* External Secrets Operator

---

# 21. Liveness Probe

## Mục đích

Kiểm tra:

> Application còn sống hay không?

---

Ví dụ:

```text
Application bị deadlock
Container vẫn chạy
```

Kubernetes không biết ứng dụng bị treo.

---

## Liveness Probe hoạt động

```text
Probe Fail
     ↓
Kubernetes Restart Container
```

---

## Ví dụ

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080

  initialDelaySeconds: 10
  periodSeconds: 5
```

---

## Khi nào dùng?

* Web API
* Spring Boot
* NodeJS
* Django

---

# 22. Readiness Probe

## Mục đích

Kiểm tra:

> Application đã sẵn sàng nhận traffic chưa?

---

Ví dụ:

```text
Container Running

Nhưng:

- DB chưa connect
- Cache chưa load
```

Không nên nhận request.

---

## Readiness Probe

```text
Probe Fail
      ↓
Service không gửi traffic tới Pod
```

---

## Ví dụ

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
```

---

## Khác biệt

```text
Liveness
  ↓
Restart Pod

Readiness
  ↓
Remove khỏi Load Balancer
```

---

# 23. Startup Probe

## Mục đích

Dành cho ứng dụng khởi động chậm.

Ví dụ:

* Spring Boot
* Java Monolith
* Large Django App

---

Nếu không có Startup Probe:

```text
Application đang boot

↓

Liveness fail

↓

Container restart

↓

Loop vô hạn
```

---

## Startup Probe

```yaml
startupProbe:
  httpGet:
    path: /startup
    port: 8080

  failureThreshold: 30
  periodSeconds: 10
```

---

## Flow

```text
Startup Probe OK
        ↓
Readiness Probe
        ↓
Liveness Probe
```

---

# 24. Ingress

## Vấn đề

Có nhiều Service:

```text
frontend-service
user-service
product-service
payment-service
```

Nếu dùng LoadBalancer:

```text
4 Services
=
4 Load Balancers
=
Tốn tiền
```

---

## Giải pháp

Ingress cung cấp:

* Reverse Proxy
* Routing
* SSL Termination

---

## Kiến trúc

```text
Internet
    │
Ingress
    │
 ┌──┼─────┐
 │  │     │
 ▼  ▼     ▼
User Product Payment
```

---

## Ví dụ

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress

spec:
  rules:
  - host: api.company.com

    http:
      paths:
      - path: /users
        backend:
          service:
            name: user-service

      - path: /products
        backend:
          service:
            name: product-service
```

---

## Thực tế AWS

Ingress Controller:

* NGINX Ingress
* AWS Load Balancer Controller
* Traefik

---

# 25. Persistent Volume (PV)

## Vấn đề

Container có storage tạm thời.

```text
Pod Restart

↓

Data mất
```

---

## Persistent Volume

Lưu dữ liệu bên ngoài Pod.

Ví dụ:

* AWS EBS
* NFS
* Ceph
* EFS

---

## Kiến trúc

```text
Pod
 │
 ▼
Persistent Volume
```

---

## Ví dụ

```yaml
apiVersion: v1
kind: PersistentVolume

spec:
  capacity:
    storage: 10Gi
```

---

## Use Cases

* Database
* Upload Files
* Logs
* CMS Content

---

# 26. Persistent Volume Claim (PVC)

## PVC là gì?

PVC là yêu cầu sử dụng storage.

---

## Ví dụ

```yaml
apiVersion: v1
kind: PersistentVolumeClaim

spec:
  accessModes:
    - ReadWriteOnce

  resources:
    requests:
      storage: 5Gi
```

---

## Flow

```text
Pod
 ↓
PVC
 ↓
PV
 ↓
Disk
```

---

## So sánh

| PV           | PVC             |
| ------------ | --------------- |
| Storage thật | Request Storage |
| Admin tạo    | Developer dùng  |

---

# 27. NetworkPolicy

## Mục tiêu

Kiểm soát traffic giữa Pods.

---

## Mặc định

```text
Pod A
 ↔
Pod B

Allowed
```

Tất cả Pod đều nói chuyện được với nhau.

---

## Ví dụ

```text
Frontend
   ↓
Backend
   ↓
Database
```

Yêu cầu:

```text
Frontend → Backend

Backend → Database

Frontend ✗ Database
```

---

## NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy

spec:
  podSelector:
    matchLabels:
      app: backend
```

---

## Tương tự AWS

| Kubernetes    | AWS            |
| ------------- | -------------- |
| NetworkPolicy | Security Group |

---

# 28. Namespace

## Namespace là gì?

Namespace dùng để phân chia tài nguyên trong cluster.

---

## Ví dụ

```text
Cluster

├── dev
├── staging
├── production
```

---

## Tạo Namespace

```bash
kubectl create namespace dev
```

---

## Deploy vào Namespace

```bash
kubectl apply -f app.yaml -n dev
```

---

## Liệt kê Namespace

```bash
kubectl get ns
```

---

## Lợi ích

* Tách môi trường
* Multi-team
* Resource quota
* Access control

---

# 29. HPA (Horizontal Pod Autoscaler)

## HPA là gì?

Tự động scale số lượng Pod.

---

## Trước HPA

```text
CPU tăng

↓

Admin scale thủ công
```

---

## Sau HPA

```text
CPU tăng

↓

HPA phát hiện

↓

Scale Pod
```

---

## Ví dụ

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler

spec:
  minReplicas: 2
  maxReplicas: 10

  metrics:
  - type: Resource

    resource:
      name: cpu

      target:
        type: Utilization
        averageUtilization: 70
```

---

## Flow

```text
CPU > 70%

↓

2 Pods

↓

4 Pods

↓

8 Pods
```

---

## Điều kiện

HPA cần:

```text
metrics-server
```

Kiểm tra:

```bash
kubectl top pods
kubectl top nodes
```

---

# Tổng kết kiến thức Production Kubernetes

| Chủ đề          | Vai trò               |
| --------------- | --------------------- |
| ConfigMap       | Config                |
| Secret          | Sensitive Data        |
| Liveness Probe  | Kiểm tra sống         |
| Readiness Probe | Kiểm tra nhận traffic |
| Startup Probe   | Kiểm tra khởi động    |
| Ingress         | Reverse Proxy         |
| PV              | Storage thật          |
| PVC             | Yêu cầu storage       |
| NetworkPolicy   | Firewall giữa Pod     |
| Namespace       | Phân vùng cluster     |
| HPA             | Auto Scaling Pod      |

Khi thiết kế hệ thống thực tế, flow thường sẽ là:

Internet
↓
Ingress
↓
Service
↓
Deployment
↓
Pods
↓
ConfigMap + Secret
↓
PVC
↓
PV

HPA giám sát Pods để scale tự động, còn NetworkPolicy kiểm soát traffic giữa các Pod.

# Những điều quan trọng cần nhớ cho buổi Lab

1. Pod là đơn vị deploy nhỏ nhất.
2. Deployment quản lý Pod.
3. ReplicaSet đảm bảo đủ số Pod.
4. Service cung cấp DNS và Load Balancing.
5. Labels + Selectors giúp Service tìm Pod.
6. Kubernetes có Self-Healing.
7. Scale bằng cách thay đổi replicas.
8. Rolling Update giúp deploy không downtime.
9. Rollback giúp quay lại version ổn định.
10. kubectl là công cụ quan trọng nhất khi làm việc với Kubernetes.
