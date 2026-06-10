# Progressive Delivery — Argo Rollouts & Canary Deployment

## Mục tiêu Day 3

1. Hiểu Progressive Delivery là gì và tại sao cần thiết.
2. Nắm Argo Rollouts và Rollout CRD thay thế Deployment như thế nào.
3. Cấu hình Canary deployment với traffic splitting chi tiết.
4. Hiểu AnalysisTemplate — tự động đánh giá chất lượng deploy bằng Prometheus.
5. Định nghĩa abort criteria và tích hợp với burn rate SLO.

---

## 1. Progressive Delivery là gì?

**Progressive Delivery** là kỹ thuật deploy mới theo từng bước nhỏ, kiểm soát rủi ro bằng cách chỉ expose một phần traffic cho version mới trước khi rollout toàn bộ.

### Vấn đề với Kubernetes Deployment mặc định

Khi update Deployment với `RollingUpdate`:

```text
Old: [v1][v1][v1][v1][v1][v1][v1][v1][v1][v1]  ← 10 pods
                   ↓ deploy v2
Mid: [v1][v1][v1][v2][v2][v2][v2][v2][v2][v2]  ← mix
End: [v2][v2][v2][v2][v2][v2][v2][v2][v2][v2]  ← 100% v2
```

Kubernetes RollingUpdate:
- Không kiểm soát được bao nhiêu % traffic vào v2.
- Không tự động đánh giá chất lượng v2.
- Không tự động rollback khi metrics xấu.
- Tất cả xảy ra trong vài phút — không đủ thời gian để phát hiện lỗi tinh vi.

### Progressive Delivery giải quyết thế nào

```text
Step 1:  [v1×90][v2×10]  → 10% traffic vào v2, chờ 10 phút, analyze
Step 2:  [v1×75][v2×25]  → 25% traffic, chờ 10 phút, analyze
Step 3:  [v1×50][v2×50]  → 50% traffic, chờ 10 phút, analyze
Step 4:  [v1×25][v2×75]  → 75% traffic, analyze
Step 5:  [v2×100]        → 100% promote nếu tất cả OK

Nếu bất kỳ step nào phát hiện metrics xấu → tự động abort → rollback về v1
```

### Các pattern Progressive Delivery

| Pattern | Mô tả | Khi nào dùng |
|---|---|---|
| **Canary** | Tăng dần % traffic vào version mới | Deploy thường ngày, risk trung bình |
| **Blue/Green** | Chạy song song 2 môi trường, switch traffic | Zero-downtime, cần verify trước khi switch |
| **A/B Testing** | Route traffic theo user segment (header, cookie) | Experiment tính năng mới |
| **Shadow** | Duplicate traffic sang version mới nhưng không trả response cho user | Test v2 dưới production load, zero risk |

---

## 2. Argo Rollouts

**Argo Rollouts** là Kubernetes controller thêm khả năng progressive delivery vào cluster.

### 2.1. Cài đặt

```bash
# Cài Argo Rollouts controller
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Cài kubectl plugin
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Verify
kubectl argo rollouts version
```

### 2.2. Rollout CRD vs Deployment

Argo Rollouts thêm Custom Resource `Rollout` — gần như identical với `Deployment` nhưng có thêm `strategy` nâng cao.

**Deployment cũ:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 10
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: my-org/backend:v1.0.0
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

**Rollout CRD thay thế:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout                    # ← đổi từ Deployment sang Rollout
metadata:
  name: backend
spec:
  replicas: 10
  selector:
    matchLabels:
      app: backend
  template:                      # ← giống hệt Deployment pod spec
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: my-org/backend:v1.0.0
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "256Mi"
  strategy:                      # ← đây là phần khác biệt
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 10m}
        - setWeight: 25
        - pause: {duration: 10m}
        - setWeight: 50
        - pause: {duration: 10m}
        - setWeight: 75
        - pause: {duration: 10m}
```

### 2.3. Migration từ Deployment sang Rollout

```bash
# Cách 1: Xoá Deployment, tạo Rollout (có downtime ngắn)
kubectl delete deployment backend
kubectl apply -f rollout-backend.yaml

# Cách 2: Convert in-place (không downtime)
# Scale Deployment về 0 rồi tạo Rollout với replicas đầy đủ
kubectl scale deployment backend --replicas=0
kubectl apply -f rollout-backend.yaml
kubectl delete deployment backend
```

> Lưu ý: Rollout quản lý ReplicaSet riêng — không share với Deployment cũ.

---

## 3. Rollout CRD — Chi tiết

### 3.1. Canary Strategy cơ bản

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: backend
  namespace: production
spec:
  replicas: 10
  revisionHistoryLimit: 3        # giữ 3 ReplicaSet cũ để rollback nhanh
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        version: stable            # label giúp traffic routing
    spec:
      containers:
        - name: backend
          image: my-org/backend:v1.0.0
  strategy:
    canary:
      # Tên Service cho canary và stable traffic
      canaryService: backend-canary    # Service trỏ vào pods canary (v2)
      stableService: backend-stable   # Service trỏ vào pods stable (v1)

      # Traffic routing qua ingress / service mesh
      trafficRouting:
        nginx:
          stableIngress: backend-ingress

      steps:
        - setWeight: 5            # 5% traffic → canary
        - pause: {duration: 5m}
        - setWeight: 20
        - pause: {duration: 10m}
        - setWeight: 40
        - pause: {duration: 10m}
        - setWeight: 60
        - pause: {duration: 10m}
        - setWeight: 80
        - pause: {duration: 10m}
        # Sau step cuối, tự động promote 100%

      # Giữ tối đa bao nhiêu canary pod khi rollout
      maxSurge: "20%"
      maxUnavailable: 0
```

### 3.2. Traffic Routing Options

Argo Rollouts hỗ trợ nhiều traffic routing provider:

```text
Nginx Ingress Controller  → annotation-based weight
AWS ALB Ingress           → target group weights
Istio                     → VirtualService weight
Linkerd                   → TrafficSplit SMI
Gateway API               → HTTPRoute weight
```

**Nginx Ingress example:**

```yaml
# Ingress cho stable (được Argo Rollouts quản lý annotation tự động)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend-stable    # Argo Rollouts sẽ tự thêm canary weight annotation
                port:
                  number: 80
```

Khi Argo Rollouts set canary weight 20%:

```text
Tự động thêm annotation vào Ingress:
nginx.ingress.kubernetes.io/canary: "true"
nginx.ingress.kubernetes.io/canary-weight: "20"
```

**Istio VirtualService example:**

```yaml
strategy:
  canary:
    canaryService: backend-canary
    stableService: backend-stable
    trafficRouting:
      istio:
        virtualService:
          name: backend-vs
          routes:
            - primary    # tên route trong VirtualService
```

```yaml
# VirtualService (Argo Rollouts tự update weight)
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-vs
spec:
  hosts:
    - backend-stable
  http:
    - name: primary
      route:
        - destination:
            host: backend-stable
          weight: 100     # ← Argo tự update
        - destination:
            host: backend-canary
          weight: 0       # ← Argo tự update
```

---

## 4. AnalysisTemplate

**AnalysisTemplate** là CRD định nghĩa cách Argo Rollouts tự động đánh giá chất lượng canary deployment bằng cách query metrics.

### 4.1. Tại sao cần AnalysisTemplate?

Không có AnalysisTemplate:

```text
Step: pause {duration: 10m}
→ Chờ 10 phút
→ Tiếp tục step tiếp theo
→ Không biết trong 10 phút đó có lỗi gì không
→ Phụ thuộc hoàn toàn vào human review
```

Với AnalysisTemplate:

```text
Step: analysis (chạy AnalysisTemplate)
→ Query Prometheus mỗi phút trong 10 phút
→ Nếu error rate < 1% → PASS → tiếp tục step tiếp theo
→ Nếu error rate > 1% → FAIL → tự động abort và rollback
```

### 4.2. AnalysisTemplate CRD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: canary-analysis
  namespace: production
spec:
  args:
    # Arguments được truyền vào từ Rollout (để reuse template)
    - name: service-name
    - name: canary-hash
      valueFrom:
        podTemplateHashValue: Latest    # tự lấy hash của canary ReplicaSet
    - name: namespace
      value: production

  metrics:
    # ——— Metric 1: Error Rate ———
    - name: error-rate
      interval: 1m                  # query mỗi 1 phút
      count: 10                     # query tổng 10 lần (= 10 phút)
      failureLimit: 1               # cho phép fail tối đa 1 lần (có thể spike ngắn)
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(
              rate(
                http_requests_total{
                  namespace="{{ args.namespace }}",
                  app="{{ args.service-name }}",
                  rollouts_pod_template_hash="{{ args.canary-hash }}",
                  status=~"5.."
                }[1m]
              )
            )
            /
            sum(
              rate(
                http_requests_total{
                  namespace="{{ args.namespace }}",
                  app="{{ args.service-name }}",
                  rollouts_pod_template_hash="{{ args.canary-hash }}"
                }[1m]
              )
            )
      successCondition: result[0] <= 0.01   # error rate <= 1%
      failureCondition: result[0] > 0.05    # error rate > 5% → immediate fail

    # ——— Metric 2: Latency P99 ———
    - name: latency-p99
      interval: 1m
      count: 10
      failureLimit: 2
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            histogram_quantile(
              0.99,
              sum by (le) (
                rate(
                  http_request_duration_seconds_bucket{
                    namespace="{{ args.namespace }}",
                    app="{{ args.service-name }}",
                    rollouts_pod_template_hash="{{ args.canary-hash }}"
                  }[1m]
                )
              )
            )
      successCondition: result[0] <= 0.5    # p99 latency <= 500ms
      failureCondition: result[0] > 1.0     # p99 > 1s → fail

    # ——— Metric 3: Success Rate tuyệt đối ———
    - name: success-rate
      interval: 1m
      count: 10
      failureLimit: 0              # zero tolerance — fail 1 lần là abort ngay
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(
              rate(
                http_requests_total{
                  namespace="{{ args.namespace }}",
                  app="{{ args.service-name }}",
                  rollouts_pod_template_hash="{{ args.canary-hash }}",
                  status=~"2.."
                }[1m]
              )
            )
            /
            sum(
              rate(
                http_requests_total{
                  namespace="{{ args.namespace }}",
                  app="{{ args.service-name }}",
                  rollouts_pod_template_hash="{{ args.canary-hash }}"
                }[1m]
              )
            )
      successCondition: result[0] >= 0.99   # >= 99% success rate
      failureCondition: result[0] < 0.95    # < 95% → fail ngay
```

### 4.3. Kết hợp AnalysisTemplate vào Rollout

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: backend
  namespace: production
spec:
  replicas: 10
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
  strategy:
    canary:
      canaryService: backend-canary
      stableService: backend-stable
      trafficRouting:
        nginx:
          stableIngress: backend-ingress

      analysis:
        # Background analysis: chạy song song với các step
        # Liên tục monitor trong suốt rollout
        startingStep: 2            # bắt đầu analyze từ step thứ 2
        templates:
          - templateName: canary-analysis
        args:
          - name: service-name
            value: backend
          - name: namespace
            value: production

      steps:
        - setWeight: 5
        - pause: {duration: 5m}   # step 1: không analyze
        - setWeight: 20           # step 2: bắt đầu background analysis
        - pause: {duration: 10m}
        - setWeight: 40
        - pause: {duration: 10m}
        - setWeight: 60
        - pause: {duration: 10m}
        - setWeight: 80
        - pause: {duration: 10m}
```

### 4.4. Inline Analysis Step

Ngoài background analysis, có thể dùng analysis như một step cụ thể:

```yaml
steps:
  - setWeight: 20
  - pause: {duration: 5m}

  # Chạy analysis trước khi tăng weight
  - analysis:
      templates:
        - templateName: canary-analysis
      args:
        - name: service-name
          value: backend
      # Analysis này phải PASS thì mới đến step tiếp theo
      # Nếu FAIL → abort rollout

  - setWeight: 50
  - pause: {duration: 5m}
  - analysis:
      templates:
        - templateName: canary-analysis
      args:
        - name: service-name
          value: backend
  - setWeight: 80
  - pause: {duration: 5m}
```

---

## 5. Abort Criteria

**Abort criteria** là điều kiện khiến Argo Rollouts tự động dừng rollout và rollback về stable version.

### 5.1. Các cách trigger abort

**Cách 1: AnalysisRun fail**

Khi metric vượt `failureCondition` hoặc quá `failureLimit`:

```text
AnalysisRun status: Failed
  → Rollout tự động set status: Degraded
  → Scale canary về 0
  → Scale stable về full replicas
  → Traffic 100% về stable
```

**Cách 2: Manual abort**

```bash
# Abort rollout ngay lập tức
kubectl argo rollouts abort backend -n production

# Xem trạng thái
kubectl argo rollouts get rollout backend -n production --watch
```

**Cách 3: Abort qua annotation**

```bash
kubectl patch rollout backend -n production \
  --type merge \
  -p '{"spec":{"template":{"metadata":{"annotations":{"rollout.argoproj.io/abort":"true"}}}}}'
```

### 5.2. Abort và Rollback flow

```text
Abort triggered
     │
     ▼
Argo Rollouts set canary weight = 0%
     │
     ▼
Scale canary ReplicaSet → 0 pods
     │
     ▼
Scale stable ReplicaSet → full replicas (e.g., 10)
     │
     ▼
Rollout phase: Degraded
     │
     ▼
Cần manual "retry" hoặc deploy version fix
```

Sau khi abort, để retry deploy (ví dụ đã fix bug, push image mới):

```bash
# Retry với image đã sửa
kubectl argo rollouts set image backend backend=my-org/backend:v2.0.1 -n production

# Hoặc retry rollout (dùng lại image hiện tại)
kubectl argo rollouts retry rollout backend -n production
```

### 5.3. DryRun Analysis

Trong giai đoạn đầu, có thể set analysis ở chế độ `dryRun` để xem kết quả mà không abort thật:

```yaml
analysis:
  templates:
    - templateName: canary-analysis
  dryRun:
    - metricName: error-rate    # metric này chạy nhưng không abort nếu fail
```

Hữu ích để:
- Calibrate threshold trước khi enable abort thật.
- Debug query Prometheus.
- Quan sát behavior của analysis mà không ảnh hưởng rollout.

---

## 6. Tích hợp với Burn Rate SLO

Đây là tích hợp mạnh nhất — dùng burn rate làm abort criteria cho canary.

### 6.1. Tại sao tích hợp burn rate?

Thay vì chỉ nhìn instantaneous error rate (có thể nhiễu), burn rate cho biết:

```text
"Canary version này đang tiêu hao error budget
 nhanh hơn bình thường bao nhiêu lần?"
```

Nếu burn rate của canary > ngưỡng → rollout này sẽ ảnh hưởng SLO → abort ngay.

### 6.2. AnalysisTemplate với Burn Rate

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: burn-rate-analysis
  namespace: production
spec:
  args:
    - name: service-name
    - name: canary-hash
      valueFrom:
        podTemplateHashValue: Latest
    - name: namespace
      value: production
    - name: error-budget-threshold   # SLO error budget = 1 - SLO_target
      value: "0.001"                 # 0.1% cho SLO 99.9%

  metrics:
    # ——— Fast Burn Rate: 5 phút ———
    - name: fast-burn-rate
      interval: 1m
      count: 15                       # chạy 15 phút
      failureLimit: 2
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            (
              sum(
                rate(
                  http_requests_total{
                    namespace="{{ args.namespace }}",
                    app="{{ args.service-name }}",
                    rollouts_pod_template_hash="{{ args.canary-hash }}",
                    status=~"5.."
                  }[5m]
                )
              )
              /
              sum(
                rate(
                  http_requests_total{
                    namespace="{{ args.namespace }}",
                    app="{{ args.service-name }}",
                    rollouts_pod_template_hash="{{ args.canary-hash }}"
                  }[5m]
                )
              )
            ) / {{ args.error-budget-threshold }}
      # Burn rate > 14x → sẽ hết budget trong ~2 ngày → abort
      successCondition: result[0] <= 14
      failureCondition: result[0] > 14

    # ——— Slow Burn Rate: 1 giờ ———
    - name: slow-burn-rate
      interval: 5m
      count: 6                        # chạy 30 phút
      failureLimit: 1
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            (
              sum(
                rate(
                  http_requests_total{
                    namespace="{{ args.namespace }}",
                    app="{{ args.service-name }}",
                    rollouts_pod_template_hash="{{ args.canary-hash }}",
                    status=~"5.."
                  }[1h]
                )
              )
              /
              sum(
                rate(
                  http_requests_total{
                    namespace="{{ args.namespace }}",
                    app="{{ args.service-name }}",
                    rollouts_pod_template_hash="{{ args.canary-hash }}"
                  }[1h]
                )
              )
            ) / {{ args.error-budget-threshold }}
      # Burn rate > 2x trong 1h → warning level → abort canary
      successCondition: result[0] <= 2
      failureCondition: result[0] > 2

    # ——— Latency Burn Rate ———
    - name: latency-burn-rate
      interval: 1m
      count: 15
      failureLimit: 2
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            # Tỷ lệ request vi phạm latency SLO (> 300ms)
            # so với latency error budget (5% = 0.05)
            (
              1 -
              sum(
                rate(
                  http_request_duration_seconds_bucket{
                    namespace="{{ args.namespace }}",
                    app="{{ args.service-name }}",
                    rollouts_pod_template_hash="{{ args.canary-hash }}",
                    le="0.3"
                  }[5m]
                )
              )
              /
              sum(
                rate(
                  http_request_duration_seconds_count{
                    namespace="{{ args.namespace }}",
                    app="{{ args.service-name }}",
                    rollouts_pod_template_hash="{{ args.canary-hash }}"
                  }[5m]
                )
              )
            ) / 0.05
      # Latency burn rate > 14x → abort
      successCondition: result[0] <= 14
      failureCondition: result[0] > 14
```

### 6.3. Rollout với Burn Rate Analysis

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: backend
  namespace: production
spec:
  replicas: 10
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: my-org/backend:v2.0.0
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
  strategy:
    canary:
      canaryService: backend-canary
      stableService: backend-stable
      trafficRouting:
        nginx:
          stableIngress: backend-ingress

      # Background analysis chạy từ đầu đến cuối rollout
      analysis:
        startingStep: 1
        templates:
          - templateName: burn-rate-analysis
        args:
          - name: service-name
            value: backend
          - name: namespace
            value: production
          - name: error-budget-threshold
            value: "0.001"   # SLO 99.9%

      steps:
        # Step 1: 5% canary — phát hiện lỗi rõ ràng
        - setWeight: 5
        - pause: {duration: 5m}

        # Step 2: 20% canary — đủ traffic để burn rate query có ý nghĩa
        - setWeight: 20
        - pause: {duration: 10m}

        # Step 3: 40%
        - setWeight: 40
        - pause: {duration: 10m}

        # Step 4: 60%
        - setWeight: 60
        - pause: {duration: 10m}

        # Step 5: 80% — gần như full traffic, vẫn có thể rollback
        - setWeight: 80
        - pause: {duration: 10m}

        # Sau step 5: nếu analysis vẫn PASS → promote 100%
      maxSurge: "20%"
      maxUnavailable: 0
```

### 6.4. Tại sao burn rate tốt hơn raw error rate cho canary?

```text
Tình huống 1: Canary có 2% error rate
  Raw check: 2% > 1% threshold → FAIL → abort
  Burn rate: 2% / 0.1% = 20× > 14× → FAIL → abort
  → Cả hai đều abort, OK

Tình huống 2: Traffic thấp ban đêm, canary có 0.5% error rate
  Raw check: 0.5% < 1% threshold → PASS → tiếp tục
  Burn rate: 0.5% / 0.1% = 5× > 2× (warning) → FAIL → abort
  → Burn rate phát hiện được vấn đề mà raw check bỏ qua

Tình huống 3: Canary có spike ngắn 3% error rate (5 giây)
  Raw 1m check: 3% > 1% → FAIL → abort (false positive)
  Burn rate 5m: trung bình 0.05% / 0.1% = 0.5× → PASS
  → Burn rate ít false positive hơn
```

---

## 7. AnalysisRun — Theo dõi kết quả

Mỗi lần Rollout chạy analysis, Argo Rollouts tạo `AnalysisRun` object.

```bash
# Xem AnalysisRun
kubectl get analysisrun -n production

# NAME                          STATUS      AGE
# backend-5d8f9b7-canary-burn   Running     3m
# backend-4c7e8a6-canary-burn   Successful  2d

# Xem chi tiết
kubectl describe analysisrun backend-5d8f9b7-canary-burn -n production

# Xem qua Argo Rollouts plugin
kubectl argo rollouts get rollout backend -n production
```

Output `kubectl argo rollouts get rollout`:

```text
Name:            backend
Namespace:       production
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          3/10
  SetWeight:     20
  ActualWeight:  20
Images:          my-org/backend:v1.0.0 (stable)
                 my-org/backend:v2.0.0 (canary)
Replicas:
  Desired:       10
  Current:       10
  Updated:       2
  Ready:         10
  Available:     10

NAME                                    KIND        STATUS     AGE    INFO
⟳ backend                               Rollout     ॥ Paused   10m
├──# revision:2                                                      canary
│  ├──⧉ backend-7d9f8b5-canary         ReplicaSet  ✔ Healthy  10m   canary,2/2
│  └──⊞ backend-7d9f8b5-canary-burn    AnalysisRun ✔ Running  8m    ✔ 7/8
└──# revision:1                                                      stable
   └──⧉ backend-6c8e7a4               ReplicaSet  ✔ Healthy  2d    stable,8/8
```

### 7.1. AnalysisRun status

| Status | Ý nghĩa |
|---|---|
| `Running` | Đang thu thập và đánh giá metrics |
| `Successful` | Tất cả metrics PASS → rollout tiếp tục |
| `Failed` | Metric FAIL quá failureLimit → rollout abort |
| `Inconclusive` | Không đủ data để kết luận (ví dụ không có traffic) |
| `Error` | Query Prometheus lỗi (network, PromQL syntax sai) |

> **Lưu ý quan trọng:** Status `Inconclusive` mặc định **không abort** rollout — Argo Rollouts coi như PASS. Cần set `inconclusiveLimit` nếu muốn abort khi không đủ data.

```yaml
metrics:
  - name: error-rate
    inconclusiveLimit: 1    # nếu query trả về không có data > 1 lần → abort
    provider:
      prometheus:
        ...
```

---

## 8. Notification khi Rollout Events

Argo Rollouts tích hợp với Argo CD Notifications để gửi thông báo.

```yaml
# rollout-notification-template.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argo-rollouts-notification-cm
  namespace: argo-rollouts
data:
  template.rollout-aborted: |
    message: |
      Rollout {{.rollout.metadata.name}} đã bị ABORT!
      Namespace: {{.rollout.metadata.namespace}}
      Reason: {{.rollout.status.message}}
      Image canary: {{range .rollout.spec.template.spec.containers}}{{.image}}{{end}}
      Lúc: {{now | date "2006-01-02 15:04:05"}}

  template.rollout-completed: |
    message: |
      ✅ Rollout {{.rollout.metadata.name}} HOÀN THÀNH!
      Version mới đã promote 100%.

  trigger.on-rollout-aborted: |
    - send: [rollout-aborted]
      when: rollout.status.phase == "Degraded"

  trigger.on-rollout-completed: |
    - send: [rollout-completed]
      when: rollout.status.phase == "Healthy"
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: backend
  annotations:
    notifications.argoproj.io/subscribe.on-rollout-aborted.slack: deployments
    notifications.argoproj.io/subscribe.on-rollout-completed.slack: deployments
```

---

## 9. Tích hợp với ArgoCD (GitOps end-to-end)

```text
Git repo
  └── k8s/apps/backend/
        ├── rollout.yaml           ← Rollout CRD
        ├── analysis-template.yaml ← AnalysisTemplate
        ├── services.yaml          ← canary + stable Service
        └── ingress.yaml           ← Ingress

ArgoCD Application
  └── sync Rollout CRD → cluster
  └── Argo Rollouts controller detect thay đổi image
  └── Bắt đầu canary steps + analysis
```

**Lưu ý quan trọng khi dùng ArgoCD + Argo Rollouts:**

ArgoCD sẽ thấy ReplicaSet canary và stable có `replicas` khác với spec trong Rollout → ArgoCD báo "OutOfSync".

Cần thêm `ignoreDifferences` vào ArgoCD Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backend
spec:
  ignoreDifferences:
    - group: argoproj.io
      kind: Rollout
      jsonPointers:
        - /spec/paused
    - group: apps
      kind: ReplicaSet
      jsonPointers:
        - /spec/replicas
  syncPolicy:
    automated:
      prune: true
      selfHeal: true   # Cẩn thận: selfHeal có thể conflict với rollout đang chạy
```

> **Best practice**: Trong quá trình rollout đang chạy, tạm pause ArgoCD sync để tránh ArgoCD override trạng thái giữa chừng.

---

## 10. Luồng hoàn chỉnh Progressive Delivery

```text
Developer
  │
  ├── Update image tag trong rollout.yaml
  ├── git commit + push → PR
  │
  │   GitHub Actions (PR)
  │   └── Validate YAML + dry-run
  │
  ├── Merge PR vào main
  │
  │   ArgoCD
  │   └── Detect change → Sync Rollout manifest
  │
  │   Argo Rollouts Controller
  │   ├── Detect image thay đổi
  │   ├── Tạo canary ReplicaSet (v2)
  │   ├── Step 1: setWeight 5% → 0.5 pods canary (làm tròn lên 1)
  │   ├── pause 5 phút
  │   ├── Background AnalysisRun bắt đầu query Prometheus
  │   ├── Step 2: setWeight 20% → 2 pods canary
  │   ├── ...
  │   │
  │   │   Nếu AnalysisRun PASS tất cả steps:
  │   │   └── Promote: canary trở thành stable
  │   │       Scale stable (v2) → 10 pods
  │   │       Scale old stable (v1) → 0 pods
  │   │       Xoá canary ReplicaSet
  │   │
  │   │   Nếu AnalysisRun FAIL tại bất kỳ step nào:
  │   │   └── Abort: canary → 0 pods
  │   │       Stable (v1) giữ 10 pods
  │   │       Notify Slack #deployments
  │   │       Rollout phase: Degraded
  │
  └── Monitor trong Grafana
       ├── Dashboard: Rollout status + burn rate canary vs stable
       ├── Alert: burn rate > 14x → SLO_HighBurnRate_Critical
       └── Traces: so sánh latency canary vs stable trong Tempo
```

---

## 11. Canary Dashboard trong Grafana

Panel cần có để theo dõi canary deployment:

```text
Row: Canary vs Stable Comparison
  ┌────────────────────────┬────────────────────────┐
  │ Error Rate: Stable     │ Error Rate: Canary      │
  │ 0.02%                  │ 0.85%  ← theo dõi sát  │
  └────────────────────────┴────────────────────────┘
  ┌────────────────────────┬────────────────────────┐
  │ P99 Latency: Stable    │ P99 Latency: Canary     │
  │ 120ms                  │ 245ms                   │
  └────────────────────────┴────────────────────────┘
  ┌────────────────────────────────────────────────────┐
  │ Traffic Split (%) — graph over time               │
  │  stable: 80% ──────────────────────────────────  │
  │  canary: 20% ──────────────────────────────────  │
  └────────────────────────────────────────────────────┘
  ┌────────────────────────────────────────────────────┐
  │ Burn Rate: Canary (5m, 1h) vs threshold (14×, 2×) │
  └────────────────────────────────────────────────────┘
```

PromQL để so sánh canary vs stable:

```promql
# Error rate theo pod template hash
sum by (rollouts_pod_template_hash) (
  rate(http_requests_total{app="backend", status=~"5.."}[5m])
)
/
sum by (rollouts_pod_template_hash) (
  rate(http_requests_total{app="backend"}[5m])
)

# P99 latency so sánh
histogram_quantile(0.99,
  sum by (le, rollouts_pod_template_hash) (
    rate(http_request_duration_seconds_bucket{app="backend"}[5m])
  )
)
```

Argo Rollouts tự động inject label `rollouts_pod_template_hash` vào tất cả pods — dùng label này để phân biệt canary và stable trong Prometheus query.

---

## 12. Checklist Day 3

- [ ] Giải thích được Progressive Delivery giải quyết vấn đề gì mà Kubernetes RollingUpdate không làm được.
- [ ] Phân biệt được Canary, Blue/Green, A/B Testing, Shadow deployment.
- [ ] Cài được Argo Rollouts và kubectl plugin.
- [ ] Hiểu sự khác biệt giữa `Deployment` CRD và `Rollout` CRD.
- [ ] Viết được Rollout manifest với canary steps đầy đủ.
- [ ] Hiểu cách traffic routing hoạt động với Nginx Ingress và Istio.
- [ ] Viết được AnalysisTemplate với Prometheus query cho error rate.
- [ ] Viết được AnalysisTemplate với Prometheus query cho latency p99.
- [ ] Giải thích được `successCondition` và `failureCondition` trong AnalysisTemplate.
- [ ] Hiểu `failureLimit` và `inconclusiveLimit` khác nhau thế nào.
- [ ] Giải thích được tại sao burn rate tốt hơn raw error rate làm abort criteria.
- [ ] Viết được burn rate query trong AnalysisTemplate.
- [ ] Biết cách manual abort và retry một Rollout.
- [ ] Hiểu `DryRun` analysis dùng khi nào.
- [ ] Biết cách cấu hình `ignoreDifferences` trong ArgoCD khi dùng Argo Rollouts.
- [ ] Biết label `rollouts_pod_template_hash` dùng để phân biệt canary vs stable trong Prometheus.
