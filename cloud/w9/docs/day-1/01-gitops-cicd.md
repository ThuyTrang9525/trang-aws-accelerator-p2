# GitOps & CI/CD — GitHub Actions + ArgoCD

## Mục tiêu Day 1

1. Hiểu GitOps là gì và tại sao nó thay đổi cách deploy.
2. Nắm vững GitHub Actions: plan-on-PR, apply-on-merge.
3. So sánh ArgoCD vs Flux.
4. Hiểu App-of-Apps pattern, Sync Waves, và rollback strategy.

---

## 1. GitOps là gì?

**GitOps** là một practice trong đó Git repository là **nguồn sự thật duy nhất** (single source of truth) cho cả application code lẫn infrastructure/config.

Nguyên tắc cốt lõi (theo OpenGitOps):

1. **Declarative** — Hệ thống được mô tả bằng trạng thái mong muốn (desired state), không phải bằng lệnh thực thi.
2. **Versioned & Immutable** — Mọi thay đổi đều có lịch sử trong Git.
3. **Pulled Automatically** — Agent tự pull và apply thay đổi từ Git.
4. **Continuously Reconciled** — Agent liên tục so sánh desired state vs actual state và tự sửa.

So sánh với cách deploy truyền thống:

```text
Traditional (Push-based):
Developer → CI → kubectl apply → Cluster
          (CI có quyền ghi vào cluster)

GitOps (Pull-based):
Developer → Git → ArgoCD/Flux → Cluster
          (Cluster tự pull từ Git)
```

Lợi ích GitOps:

- Audit trail: mọi thay đổi production đều có Git commit.
- Rollback: chỉ cần `git revert`, không cần nhớ lệnh deploy cũ.
- Consistency: dev/staging/prod đều từ Git, không bao giờ lệch.
- Security: CI/CD không cần credentials của cluster.
- Self-healing: nếu ai sửa trực tiếp cluster, agent sẽ tự đưa về trạng thái đúng.

---

## 2. GitHub Actions — Tổng quan

**GitHub Actions** là CI/CD platform tích hợp sẵn trong GitHub.

Thành phần cơ bản:

```text
Workflow (.github/workflows/xxx.yml)
  └── Trigger (on: push, pull_request, ...)
  └── Job (runs-on: ubuntu-latest)
       └── Step 1: actions/checkout@v4
       └── Step 2: hashicorp/setup-terraform@v3
       └── Step 3: terraform plan
       └── ...
```

Ví dụ workflow file cơ bản:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: npm test
```

---

## 3. Pattern: Plan-on-PR + Apply-on-Merge

Đây là pattern GitOps chuẩn nhất cho Terraform trên GitHub.

### Luồng làm việc

```text
1. Developer tạo feature branch
2. Push code & mở Pull Request
3. GitHub Actions chạy terraform plan → comment kết quả vào PR
4. Reviewer đọc plan output trong PR
5. Merge PR vào main
6. GitHub Actions chạy terraform apply tự động
```

### Tại sao pattern này tốt?

- **Visibility**: Plan output ngay trong PR, reviewer thấy infra thay đổi gì trước khi merge.
- **Safety**: Không apply bừa vào production khi còn đang review.
- **Automation**: Sau khi merge, apply tự động, không cần ai chạy lệnh tay.
- **Audit**: Git history ghi rõ ai merge PR nào → ai trigger apply production.

### Cấu trúc workflow thực tế

```yaml
# .github/workflows/terraform.yml
name: Terraform CI/CD

on:
  pull_request:
    branches: [main]
    paths:
      - 'infra/**'
  push:
    branches: [main]
    paths:
      - 'infra/**'

permissions:
  id-token: write      # OIDC với AWS
  contents: read
  pull-requests: write # comment vào PR

jobs:
  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    defaults:
      run:
        working-directory: infra/

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
          aws-region: ap-southeast-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.9.0"

      - name: Terraform Init
        run: terraform init

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color -out=tfplan
        continue-on-error: true  # plan fail không block PR ngay, đọc output trước

      - name: Comment Plan on PR
        uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Terraform Plan 📖

            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\`

            *Pushed by: @${{ github.actor }}*`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });

      - name: Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1

  terraform-apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    environment: production     # yêu cầu manual approval nếu cấu hình
    defaults:
      run:
        working-directory: infra/

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
          aws-region: ap-southeast-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.9.0"

      - name: Terraform Init
        run: terraform init

      - name: Terraform Apply
        run: terraform apply -auto-approve -input=false
```

### OIDC thay vì AWS Access Key

Không nên lưu `AWS_ACCESS_KEY_ID` và `AWS_SECRET_ACCESS_KEY` trong GitHub Secrets vì:

- Secret rotate khó.
- Nếu bị lộ, attacker có long-lived credential.

OIDC (OpenID Connect) cho phép GitHub Actions nhận JWT token và assume IAM Role trực tiếp:

```text
GitHub Actions Job
  → Request OIDC token từ GitHub
  → AWS STS: AssumeRoleWithWebIdentity
  → Nhận temporary credentials (tồn tại 1 giờ)
  → Chạy terraform apply
```

IAM Trust Policy cho OIDC:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:my-org/my-repo:ref:refs/heads/main"
    }
  }
}
```

---

## 4. ArgoCD vs Flux

Cả hai đều implement GitOps pull model cho Kubernetes. Sự khác biệt nằm ở triết lý thiết kế.

### ArgoCD

**ArgoCD** là GitOps controller với UI đồ họa đẹp, thiết kế theo hướng "Application-centric".

Đặc điểm:

- Web UI trực quan để xem sync status, diff, rollback.
- Mỗi app được định nghĩa bằng `Application` CRD.
- Declarative config HOẶC có thể tạo app qua UI/CLI.
- RBAC tích hợp (ai được sync app nào).
- Notification hỗ trợ (Slack, email, ...).
- Single cluster hoặc multi-cluster.

Ví dụ `Application` resource:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/my-org/my-repo.git
    targetRevision: main
    path: k8s/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true        # xoá resource không còn trong Git
      selfHeal: true     # tự sửa nếu có drift
    syncOptions:
      - CreateNamespace=true
```

### Flux

**Flux** là GitOps toolkit, thiết kế theo hướng "operator composition" — nhiều controller nhỏ kết hợp.

Đặc điểm:

- Không có Web UI mặc định (dùng Weave GitOps nếu cần UI).
- Dùng nhiều CRD: `GitRepository`, `Kustomization`, `HelmRelease`, `ImageAutomation`.
- CLI-first (`flux` CLI mạnh).
- Native Kustomize và Helm support.
- Multi-tenancy tốt hơn theo thiết kế.
- Bootstrap cluster bằng `flux bootstrap github`.

Ví dụ Flux resources:

```yaml
# GitRepository — nguồn Git
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: my-repo
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/my-org/my-repo
  ref:
    branch: main
---
# Kustomization — apply path từ GitRepository
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: my-repo
  path: k8s/overlays/prod
  prune: true
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: my-app
      namespace: production
```

### Bảng so sánh ArgoCD vs Flux

| Tiêu chí | ArgoCD | Flux |
|---|---|---|
| Web UI | Có (built-in, rất đẹp) | Cần Weave GitOps (addon) |
| Architecture | Monolithic app | Modular operators |
| CRD chính | `Application` | `GitRepository`, `Kustomization`, `HelmRelease` |
| Multi-cluster | Có | Có |
| RBAC | Tích hợp sẵn | Kubernetes RBAC |
| Helm support | Có | Có (native `HelmRelease`) |
| OCI Registry | Có | Có |
| Learning curve | Thấp hơn (UI giúp nhiều) | Cao hơn (CLI + nhiều CRD) |
| Community | Lớn, CNCF graduated | Lớn, CNCF graduated |
| Phù hợp | Team cần UI, visibility | Team thích CLI, K8s-native |

### Khi nào chọn cái nào?

- Chọn **ArgoCD** nếu team cần UI để xem trạng thái sync, rollback nhanh, hoặc có nhiều app cần quản lý trực quan.
- Chọn **Flux** nếu team thích GitOps thuần túy, không phụ thuộc UI, cần Helm và ImageAutomation tốt, hoặc đang build platform cho nhiều team.
- Nhiều công ty dùng **cả hai** hoặc dùng chung tool cho toàn cluster.

---

## 5. App-of-Apps Pattern

**App-of-Apps** là pattern để quản lý nhiều ArgoCD Application bằng chính ArgoCD.

### Vấn đề khi không dùng App-of-Apps

Nếu có 20 ứng dụng, cần tạo 20 `Application` CRD riêng lẻ bằng tay hoặc script. Khó quản lý, không có single source of truth cho infra layer.

### Giải pháp App-of-Apps

Tạo một "parent" Application trỏ vào một thư mục chứa nhiều Application manifest.

```text
Git repo
└── apps/
    ├── root-app.yaml          ← parent App (chỉ ArgoCD cài lần đầu)
    └── templates/
        ├── frontend.yaml      ← Application cho frontend
        ├── backend.yaml       ← Application cho backend
        ├── database.yaml      ← Application cho database
        └── monitoring.yaml    ← Application cho monitoring
```

**Parent Application** (`root-app.yaml`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/my-org/gitops-repo.git
    targetRevision: main
    path: apps/templates
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Child Application** (`apps/templates/frontend.yaml`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/my-org/gitops-repo.git
    targetRevision: main
    path: k8s/apps/frontend/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: frontend
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Luồng khi thêm app mới

```text
1. Tạo file apps/templates/new-service.yaml
2. Commit & push lên Git
3. ArgoCD root-app phát hiện file mới
4. ArgoCD tự tạo Application "new-service"
5. Application "new-service" tự sync manifest vào cluster
```

Không cần chạy `kubectl apply` hay click UI để tạo app mới.

### ApplicationSet — phiên bản nâng cao

**ApplicationSet** là extension của App-of-Apps, tự generate nhiều Application từ template + generator.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-addons
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: dev
            url: https://dev-cluster.example.com
          - cluster: staging
            url: https://staging-cluster.example.com
          - cluster: prod
            url: https://prod-cluster.example.com
  template:
    metadata:
      name: '{{cluster}}-monitoring'
    spec:
      project: default
      source:
        repoURL: https://github.com/my-org/gitops-repo
        targetRevision: main
        path: 'cluster-addons/monitoring'
      destination:
        server: '{{url}}'
        namespace: monitoring
```

Generator này tạo ra 3 Application tự động (dev-monitoring, staging-monitoring, prod-monitoring).

---

## 6. Sync Waves

**Sync Waves** giải quyết vấn đề ordering khi deploy nhiều resource cùng lúc.

### Vấn đề

Khi ArgoCD sync một Application có nhiều resource, thứ tự apply không đảm bảo. Ví dụ:

```text
Nếu deploy cùng lúc:
- Deployment (cần ConfigMap)
- ConfigMap
→ Deployment có thể bị lỗi vì ConfigMap chưa có
```

Hoặc ở level multi-app:

```text
Cần deploy theo thứ tự:
1. Namespace + RBAC
2. CRD
3. Database
4. Backend
5. Frontend
```

### Giải pháp: Sync Waves

Thêm annotation `argocd.argoproj.io/sync-wave` vào resource.

Wave thấp hơn được apply trước. Wave mặc định là 0.

```yaml
# Wave 1: Namespace trước
apiVersion: v1
kind: Namespace
metadata:
  name: production
  annotations:
    argocd.argoproj.io/sync-wave: "-2"
---
# Wave 2: CRD
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: mycrds.example.com
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
---
# Wave 3: ConfigMap (mặc định 0)
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  annotations:
    argocd.argoproj.io/sync-wave: "0"
---
# Wave 4: Database
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  annotations:
    argocd.argoproj.io/sync-wave: "1"
---
# Wave 5: Backend (chờ database healthy)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  annotations:
    argocd.argoproj.io/sync-wave: "2"
---
# Wave 6: Frontend (chờ backend healthy)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  annotations:
    argocd.argoproj.io/sync-wave: "3"
```

### Cơ chế hoạt động

```text
ArgoCD bắt đầu sync
  → Apply tất cả resource ở wave -2
  → Chờ chúng healthy
  → Apply tất cả resource ở wave -1
  → Chờ chúng healthy
  → Apply wave 0
  → ...
  → Tất cả healthy → Sync thành công
```

Nếu một resource ở wave N fail health check, ArgoCD dừng lại và không apply các wave tiếp theo.

### Sync Hooks

Ngoài waves, ArgoCD có **Sync Hooks** để chạy job tại các điểm trong sync lifecycle:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    argocd.argoproj.io/hook: PreSync        # chạy trước khi sync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: my-app:latest
          command: ["python", "manage.py", "migrate"]
      restartPolicy: Never
```

Hook types:

| Hook | Thời điểm chạy |
|---|---|
| `PreSync` | Trước khi sync bắt đầu |
| `Sync` | Trong quá trình sync (cùng với resource) |
| `PostSync` | Sau khi tất cả resource healthy |
| `SyncFail` | Khi sync fail |
| `Skip` | Bỏ qua resource này |

---

## 7. Rollback Strategy

Khi có sự cố, có hai hướng rollback chính.

### 7.1. `git revert` — GitOps Rollback

**`git revert`** tạo commit mới để đảo ngược thay đổi. Đây là cách GitOps thuần túy.

```bash
# Xem lịch sử commit
git log --oneline

# abc1234 feat: update backend image to v2.1.0
# def5678 feat: update frontend image to v3.0.0
# ...

# Revert commit cụ thể (không xoá history)
git revert abc1234 --no-edit

# Push lên main
git push origin main
```

Khi push lên main:

```text
GitHub Actions apply OR ArgoCD sync
  → Detect thay đổi trong Git
  → Apply trạng thái mới (là trạng thái cũ sau revert)
  → Cluster trở về v2.0.0
```

**Ưu điểm `git revert`:**

- Audit trail đầy đủ — có thể thấy cả commit deploy lẫn commit rollback.
- Không phá Git history.
- Rollback theo GitOps đúng cách.
- Có thể revert nhiều commit cùng lúc.

**Nhược điểm:**

- Chậm hơn — phải chờ ArgoCD/CI sync lại.
- Không rollback realtime trong khủng hoảng.

### 7.2. `kubectl rollout undo` — Imperative Rollback

**`kubectl rollout undo`** rollback trực tiếp Deployment trong cluster, không qua Git.

```bash
# Xem rollout history
kubectl rollout history deployment/backend -n production

# REVISION  CHANGE-CAUSE
# 1         image: backend:v1.0.0
# 2         image: backend:v2.1.0   ← hiện tại (lỗi)

# Rollback về revision trước
kubectl rollout undo deployment/backend -n production

# Rollback về revision cụ thể
kubectl rollout undo deployment/backend -n production --to-revision=1

# Xem status
kubectl rollout status deployment/backend -n production
```

**Ưu điểm `kubectl rollout undo`:**

- Rất nhanh — không cần chờ sync pipeline.
- Hữu ích trong tình huống production down.
- Kubernetes giữ sẵn ReplicaSet cũ.

**Nhược điểm:**

- **Drift** với GitOps — Git vẫn có manifest cũ (bị lỗi), cluster đã rollback.
- Nếu ArgoCD selfHeal = true → ArgoCD sẽ **đè lại** version lỗi từ Git!
- Không có audit trail trong Git.

### 7.3. So sánh hai cách rollback

| Tiêu chí | `git revert` | `kubectl rollout undo` |
|---|---|---|
| Tốc độ | Chậm hơn (pipeline) | Ngay lập tức |
| Git history | Rõ ràng, clean | Không có dấu vết |
| GitOps compliance | Đúng cách | Vi phạm GitOps |
| Phù hợp | Rollback bình thường | Emergency only |
| ArgoCD selfHeal | Hoạt động đúng | Có thể bị override |

### 7.4. Best Practice Rollback

**Quy trình rollback production đúng chuẩn:**

```text
1. Phát hiện sự cố
2. (Tùy chọn) kubectl rollout undo để giảm downtime ngay
3. NGAY SAU ĐÓ: git revert commit lỗi → push → verify sync
4. Nếu dùng ArgoCD selfHeal: pause sync trước khi kubectl rollout undo
5. Sau khi git revert sync xong: resume sync
```

**ArgoCD Rollback qua UI:**

ArgoCD cũng có tính năng rollback built-in:

```bash
# CLI rollback ArgoCD về sync ID cụ thể
argocd app rollback my-app <sync-id>
```

Khi rollback qua ArgoCD UI/CLI:

- ArgoCD apply lại resource tại commit cũ trong Git history.
- ArgoCD tự động disable auto-sync (để tránh ngay lập tức sync lại version lỗi).
- Vẫn không cập nhật Git — cần git revert để đồng bộ.

---

## 8. Tóm tắt luồng GitOps hoàn chỉnh

```text
Developer
  │
  ├── Tạo branch feature/update-backend-v2
  ├── Update k8s/apps/backend/deployment.yaml
  ├── Mở Pull Request
  │
  │   GitHub Actions (PR trigger)
  │   ├── Lint YAML
  │   ├── Validate Kubernetes manifests
  │   ├── terraform plan (nếu có infra change)
  │   └── Comment plan vào PR
  │
  ├── Team review & approve PR
  ├── Merge vào main
  │
  │   GitHub Actions (push trigger)
  │   └── terraform apply (nếu có infra change)
  │
  │   ArgoCD
  │   ├── Phát hiện Git thay đổi (polling hoặc webhook)
  │   ├── Sync Application
  │   ├── Apply theo Sync Waves
  │   └── Report sync status
  │
  └── Monitor kết quả
       ├── ArgoCD UI: xem sync status
       ├── Grafana: xem metrics
       └── Loki: xem logs
```

---

## 9. Checklist Day 1

- [ ] Giải thích được GitOps khác CI/CD truyền thống thế nào.
- [ ] Hiểu tại sao dùng OIDC thay vì long-lived AWS credentials.
- [ ] Viết được workflow GitHub Actions có plan-on-PR và apply-on-merge.
- [ ] So sánh được ArgoCD và Flux trên ít nhất 5 tiêu chí.
- [ ] Giải thích được App-of-Apps pattern giải quyết vấn đề gì.
- [ ] Giải thích được Sync Waves hoạt động thế nào.
- [ ] Phân biệt được `git revert` và `kubectl rollout undo`.
- [ ] Biết khi nào nên dùng từng cách rollback.
- [ ] Hiểu tại sao `kubectl rollout undo` nguy hiểm khi dùng ArgoCD selfHeal.
