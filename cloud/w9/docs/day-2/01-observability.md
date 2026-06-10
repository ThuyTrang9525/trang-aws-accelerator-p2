# Observability — SLO/SLI/OTel + Prometheus + Grafana + Loki

## Mục tiêu Day 2

1. Phân biệt Monitoring vs Observability.
2. Hiểu SLI, SLO, SLA và cách xây dựng SLO methodology thực tế.
3. Nắm OpenTelemetry (OTel) SDK + Collector end-to-end.
4. Hiểu Prometheus, Grafana, Loki hoạt động ra sao và kết hợp thế nào.
5. Hiểu Multi-window burn rate alert — fast burn + slow burn.

---

## 1. Monitoring vs Observability

Hai khái niệm hay bị nhầm lẫn:

| Monitoring | Observability |
|---|---|
| Biết *cái gì* đang sai | Hiểu *tại sao* nó sai |
| Dashboard + alert đã định sẵn | Query bất kỳ câu hỏi từ dữ liệu |
| Reactive | Proactive + investigative |
| Ví dụ: CPU > 80% → alert | Ví dụ: Trace cho thấy slow DB query ở request /checkout |

**Ba trụ cột của Observability (Three Pillars):**

```text
Metrics       → Số liệu theo thời gian (latency p99, error rate, RPS)
Logs          → Sự kiện có text, có timestamp (error message, request log)
Traces        → Luồng request qua nhiều service (distributed tracing)
```

Trong thực tế hiện đại còn có:

- **Profiles** — CPU/memory flamegraph theo thời gian.
- **Events** — Kubernetes events, deploy events.

---

## 2. SLI, SLO, SLA — Định nghĩa

### SLI — Service Level Indicator

**SLI** là metric cụ thể đo chất lượng dịch vụ từ góc độ user.

Công thức chung:

```text
SLI = (số lượng good events) / (tổng số events) × 100%
```

Ví dụ SLI phổ biến:

| Loại SLI | Ví dụ |
|---|---|
| Availability | % request trả về HTTP 2xx hoặc 3xx |
| Latency | % request hoàn thành dưới 300ms |
| Error rate | % request không trả về 5xx |
| Throughput | % khoảng thời gian RPS > threshold |
| Durability | % data objects được đọc thành công |

### SLO — Service Level Objective

**SLO** là mục tiêu nội bộ đặt ra cho SLI.

```text
SLO: availability SLI >= 99.9% trong rolling 30 ngày
SLO: latency SLI (< 300ms) >= 95% trong rolling 30 ngày
```

SLO không phải cam kết với khách hàng — đó là mục tiêu engineering nội bộ.

### SLA — Service Level Agreement

**SLA** là cam kết pháp lý/hợp đồng với khách hàng.

```text
SLA: uptime >= 99.5% / tháng
     Vi phạm → hoàn tiền, penalty
```

Thực tế:

```text
SLO > SLA (buffer an toàn)
SLI = metric thực tế đo được

Ví dụ:
SLA: 99.5% uptime
SLO: 99.9% availability (internal target)
SLI: 99.95% (thực tế đo được tuần này)
```

### Error Budget

**Error budget** = phần "được phép lỗi" còn lại trong kỳ SLO.

```text
SLO: 99.9% availability trong 30 ngày
Tổng thời gian: 30 × 24 × 60 = 43,200 phút
Error budget:   0.1% × 43,200 = 43.2 phút downtime được phép

Nếu đã down 30 phút → còn 13.2 phút error budget
Nếu hết error budget → freeze deploy, focus on reliability
```

Error budget thúc đẩy sự cân bằng giữa velocity và reliability.

---

## 3. SLO Methodology thực tế

### 3.1. Availability SLO

Đo tỷ lệ request thành công.

**Prometheus metric:**

```promql
# Tổng request 5xx trong 5 phút
sum(rate(http_requests_total{status=~"5.."}[5m]))

# Tổng request trong 5 phút
sum(rate(http_requests_total[5m]))

# SLI availability (trong PromQL)
1 - (
  sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))
)
```

**Ví dụ SLO availability:**

```text
SLO: 99.9% availability trong rolling 30 ngày
Nghĩa là: tối đa 0.1% request được phép fail (5xx)
```

### 3.2. Latency SLO

Đo tỷ lệ request đáp ứng được threshold latency.

**Sử dụng histogram metric:**

```promql
# Tỷ lệ request hoàn thành dưới 300ms trong 5 phút
sum(rate(http_request_duration_seconds_bucket{le="0.3"}[5m]))
/
sum(rate(http_request_duration_seconds_count[5m]))
```

**Ví dụ SLO latency:**

```text
SLO: 95% request hoàn thành < 300ms trong rolling 30 ngày
SLO: 99% request hoàn thành < 1000ms trong rolling 30 ngày
```

> Lưu ý: Luôn dùng histogram (không dùng gauge hay summary) để đo latency vì histogram có thể aggregate across instances.

---

## 4. Multi-Window Burn Rate Alert

Đây là kỹ thuật alerting tiên tiến nhất cho SLO, được Google SRE Book đề xuất.

### 4.1. Burn Rate là gì?

**Burn rate** = tốc độ tiêu thụ error budget so với tốc độ bình thường.

```text
Burn rate = 1  → đang tiêu budget vừa đủ đúng tốc độ (hết đúng cuối kỳ)
Burn rate = 2  → đang tiêu gấp đôi (hết budget trước kỳ 2 lần)
Burn rate = 14 → cực kỳ nhanh, sẽ hết budget trong vài giờ
```

Công thức:

```text
Burn rate = error_rate_hiện_tại / error_rate_cho_phép

Với SLO 99.9%:
error_rate_cho_phép = 0.1%

Nếu error_rate_hiện_tại = 1.4%:
burn rate = 1.4% / 0.1% = 14x
```

Với burn rate 14x:

```text
Sẽ hết error budget sau: 30 ngày / 14 = ~2.1 ngày
```

### 4.2. Vấn đề với single-window alert

**Window quá ngắn (1h):**

```text
Alert nhanh nhưng false positive nhiều
Spike ngắn 5 phút tạo alert → không phải real incident
```

**Window quá dài (6h):**

```text
Alert chậm → khi alert bắn, đã burn nhiều budget rồi
Latency phát hiện cao
```

### 4.3. Multi-Window Burn Rate: Fast + Slow

Google SRE khuyến nghị dùng **hai window cùng lúc** cho mỗi mức severity.

**Cơ chế hoạt động:**

```text
Alert bắn KHI VÀ CHỈ KHI cả hai điều kiện đúng:
  - Window ngắn (fast): burn rate cao → phát hiện nhanh
  - Window dài (slow): burn rate cao → giảm false positive
```

**Hai mức severity:**

| Severity | Fast window | Slow window | Burn rate threshold | Hành động |
|---|---|---|---|---|
| **Critical (Page)** | 5 phút | 1 giờ | 14x | Wake oncall ngay lập tức |
| **Warning (Ticket)** | 30 phút | 6 giờ | 2x | Tạo ticket, fix trong giờ làm |

**Tại sao threshold 14x cho Critical?**

```text
SLO window: 30 ngày
Burn rate 14x → hết budget sau: 30 / 14 ≈ 2.1 ngày

Nếu không phát hiện trong 5 phút → mất 5 phút × 14 = 70 phút equivalent budget
→ Đủ để cần page ngay
```

**Tại sao threshold 2x cho Warning?**

```text
Burn rate 2x → hết budget sau: 30 / 2 = 15 ngày
→ Không nguy hiểm ngay nhưng cần fix sớm
```

### 4.4. Ví dụ Prometheus Alert Rules

```yaml
# alerts/slo-burn-rate.yml
groups:
  - name: slo.burn_rate
    rules:
      # ——— Tính error rate ———
      # (dùng recording rule để cache, tránh tính lại nhiều lần)
      - record: job:slo_errors:rate5m
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total[5m]))

      - record: job:slo_errors:rate30m
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[30m]))
          /
          sum(rate(http_requests_total[30m]))

      - record: job:slo_errors:rate1h
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[1h]))
          /
          sum(rate(http_requests_total[1h]))

      - record: job:slo_errors:rate6h
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[6h]))
          /
          sum(rate(http_requests_total[6h]))

      # ——— Critical: Fast burn (page) ———
      # SLO 99.9% → error budget = 0.001
      # Threshold 14x → 0.001 × 14 = 0.014
      - alert: SLO_HighBurnRate_Critical
        expr: |
          job:slo_errors:rate5m > (14 * 0.001)
          and
          job:slo_errors:rate1h > (14 * 0.001)
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "SLO Critical: error budget burning too fast"
          description: |
            Current 5m error rate: {{ $value | humanizePercentage }}
            Burn rate: {{ printf "%.1f" (div $value 0.001) }}x
            At this rate, error budget will be exhausted in
            {{ printf "%.1f" (div 720 (div $value 0.001)) }} hours.

      # ——— Warning: Slow burn (ticket) ———
      # Threshold 2x → 0.001 × 2 = 0.002
      - alert: SLO_HighBurnRate_Warning
        expr: |
          job:slo_errors:rate30m > (2 * 0.001)
          and
          job:slo_errors:rate6h > (2 * 0.001)
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "SLO Warning: elevated error budget consumption"
          description: |
            Current 30m error rate: {{ $value | humanizePercentage }}
            Burn rate: {{ printf "%.1f" (div $value 0.001) }}x
```

**Giải thích `for: 2m` và `for: 15m`:**

- `for: 2m`: alert phải ở trạng thái firing liên tục 2 phút mới thực sự gửi thông báo → thêm lớp giảm noise.
- `for: 15m`: warning cần firing 15 phút → chắc chắn không phải spike ngắn.

### 4.5. Bảng tóm tắt Multi-Window Burn Rate

```text
SLO: 99.9% (error budget = 0.1% = 43.2 phút/tháng)

┌─────────────┬───────────┬───────────┬──────────────┬─────────────────────────┐
│ Severity    │ Fast win  │ Slow win  │ Burn rate    │ Budget consumed if fire │
├─────────────┼───────────┼───────────┼──────────────┼─────────────────────────┤
│ Critical    │ 5 min     │ 1 hour    │ 14×          │ 2% in 1h (≈ 0.86 min)  │
│ Warning     │ 30 min    │ 6 hours   │ 2×           │ 5% in 6h (≈ 2.16 min)  │
└─────────────┴───────────┴───────────┴──────────────┴─────────────────────────┘
```

---

## 5. OpenTelemetry (OTel)

**OpenTelemetry** là CNCF standard để generate, collect, và export telemetry data (traces, metrics, logs).

### 5.1. Tại sao cần OTel?

Trước OTel, mỗi vendor có SDK riêng:

```text
Datadog SDK → chỉ gửi được cho Datadog
Jaeger client → chỉ gửi được cho Jaeger
Zipkin client → chỉ gửi được cho Zipkin
```

Khi muốn đổi vendor → phải refactor toàn bộ instrumentation code.

Với OTel:

```text
OTel SDK → OTel Collector → bất kỳ backend (Datadog, Jaeger, Prometheus, Loki, ...)
```

Thay đổi backend chỉ cần đổi config Collector, không đụng application code.

### 5.2. Kiến trúc OTel

```text
Application
  └── OTel SDK (instrument code)
        │
        │  OTLP (gRPC hoặc HTTP)
        ▼
  OTel Collector
    ├── Receivers   (nhận data từ SDK, Prometheus scrape, ...)
    ├── Processors  (batch, filter, enrich, sample)
    └── Exporters   (gửi đến backend)
          ├── Prometheus exporter  → Prometheus pull
          ├── Loki exporter        → Loki push
          ├── OTLP exporter        → Tempo / Jaeger / Zipkin
          └── Datadog exporter     → Datadog
```

### 5.3. OTel SDK — Instrument Application

**Python example:**

```python
# requirements.txt
# opentelemetry-api==1.26.0
# opentelemetry-sdk==1.26.0
# opentelemetry-exporter-otlp==1.26.0
# opentelemetry-instrumentation-fastapi==0.47b0

from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter

# Setup Tracer
tracer_provider = TracerProvider()
tracer_provider.add_span_processor(
    BatchSpanProcessor(
        OTLPSpanExporter(endpoint="http://otel-collector:4317")
    )
)
trace.set_tracer_provider(tracer_provider)
tracer = trace.get_tracer(__name__)

# Setup Meter
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint="http://otel-collector:4317"),
    export_interval_millis=60_000
)
meter_provider = MeterProvider(metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)
meter = metrics.get_meter(__name__)

# Tạo custom metric
http_requests_counter = meter.create_counter(
    name="http_requests_total",
    description="Total HTTP requests",
    unit="1"
)

request_duration = meter.create_histogram(
    name="http_request_duration_seconds",
    description="HTTP request duration",
    unit="s"
)

# Dùng trong code
import time
from fastapi import FastAPI, Request

app = FastAPI()

@app.middleware("http")
async def observability_middleware(request: Request, call_next):
    start = time.time()

    with tracer.start_as_current_span(
        f"{request.method} {request.url.path}",
        attributes={
            "http.method": request.method,
            "http.url": str(request.url),
        }
    ) as span:
        response = await call_next(request)
        duration = time.time() - start

        span.set_attribute("http.status_code", response.status_code)

        http_requests_counter.add(1, {
            "method": request.method,
            "status": str(response.status_code),
            "path": request.url.path
        })

        request_duration.record(duration, {
            "method": request.method,
            "path": request.url.path
        })

        return response
```

**Node.js example:**

```javascript
// tracing.js — load TRƯỚC app code
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-grpc');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');

const sdk = new NodeSDK({
  serviceName: 'my-service',
  traceExporter: new OTLPTraceExporter({
    url: 'http://otel-collector:4317',
  }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: 'http://otel-collector:4317',
    }),
    exportIntervalMillis: 60000,
  }),
  instrumentations: [
    getNodeAutoInstrumentations(), // tự động instrument Express, HTTP, DB, ...
  ],
});

sdk.start();
```

### 5.4. OTel Collector Config

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

  # Nhận Prometheus metrics từ app khác
  prometheus:
    config:
      scrape_configs:
        - job_name: 'legacy-app'
          static_configs:
            - targets: ['legacy-app:8080']

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024

  # Thêm resource attributes
  resource:
    attributes:
      - key: deployment.environment
        value: production
        action: insert

  # Memory limiter để không bị OOM
  memory_limiter:
    check_interval: 5s
    limit_mib: 512

exporters:
  # Metrics → Prometheus
  prometheus:
    endpoint: "0.0.0.0:8889"
    namespace: otel

  # Traces → Tempo (Grafana)
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true

  # Logs → Loki
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    labels:
      attributes:
        service.name: "service_name"
        deployment.environment: "environment"

  # Debug (local dev)
  debug:
    verbosity: detailed

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch, resource]
      exporters: [otlp/tempo, debug]

    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch, resource]
      exporters: [prometheus]

    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch, resource]
      exporters: [loki]
```

### 5.5. OTLP Protocol

**OTLP (OpenTelemetry Protocol)** là protocol chuẩn để truyền telemetry data.

| Protocol | Port | Dùng khi |
|---|---|---|
| gRPC | 4317 | Performance cao, trong cluster |
| HTTP/JSON | 4318 | Debug, firewall hạn chế gRPC |

---

## 6. Prometheus

**Prometheus** là hệ thống monitoring và alerting, đặc biệt tốt cho metrics dạng time-series.

### 6.1. Kiến trúc Prometheus

```text
Prometheus Server
  ├── Scraper — định kỳ pull metrics từ targets
  ├── TSDB — time-series database lưu metrics
  ├── Rule Engine — evaluate recording rules + alert rules
  └── HTTP API — PromQL query

Targets (expose /metrics endpoint):
  ├── Application (với OTel hoặc Prometheus client library)
  ├── Node Exporter (host metrics: CPU, RAM, disk)
  ├── Kube State Metrics (Kubernetes object states)
  └── Blackbox Exporter (endpoint probing)

Alertmanager
  ├── Nhận alert từ Prometheus
  ├── Deduplication + grouping
  ├── Routing (who gets which alert)
  └── Notification (Slack, PagerDuty, email)
```

### 6.2. Prometheus Config

```yaml
# prometheus.yml
global:
  scrape_interval: 15s      # Pull metrics mỗi 15 giây
  evaluation_interval: 15s  # Evaluate rules mỗi 15 giây

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - "alerts/*.yml"

scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:8889']

  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      # Chỉ scrape pod có annotation prometheus.io/scrape: "true"
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: (.+)
        replacement: $1
```

### 6.3. PromQL cơ bản

```promql
# Rate request trong 5 phút
rate(http_requests_total[5m])

# Tổng rate theo status code
sum by (status) (rate(http_requests_total[5m]))

# Latency p99
histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))

# Error rate
sum(rate(http_requests_total{status=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))

# CPU usage
1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))

# Memory usage %
1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
```

### 6.4. Metric Types

| Type | Ý nghĩa | Ví dụ |
|---|---|---|
| Counter | Chỉ tăng, reset khi restart | `http_requests_total` |
| Gauge | Có thể tăng/giảm | `memory_usage_bytes` |
| Histogram | Phân bổ giá trị theo bucket | `http_request_duration_seconds` |
| Summary | Quantile tính sẵn tại client | Ít dùng trong Prometheus |

> **Best practice**: Dùng Histogram cho latency vì có thể aggregate across instances. Summary tính quantile tại client — không aggregate được.

---

## 7. Grafana

**Grafana** là platform visualize metrics, logs, traces từ nhiều datasource.

### 7.1. Datasources phổ biến

```text
Prometheus  → Metrics (PromQL)
Loki        → Logs (LogQL)
Tempo       → Traces (TraceQL)
CloudWatch  → AWS metrics
Elasticsearch → Logs + Search
```

### 7.2. Grafana Dashboard structure

```text
Dashboard
  └── Row 1: Overview
       ├── Panel: Request rate (graph)
       ├── Panel: Error rate (stat)
       └── Panel: Latency p99 (gauge)
  └── Row 2: Infrastructure
       ├── Panel: CPU usage (heatmap)
       └── Panel: Memory usage (graph)
  └── Row 3: SLO
       ├── Panel: Error budget remaining (stat)
       └── Panel: Burn rate (graph)
```

### 7.3. Grafana Alerting

Grafana có thể tạo alert dựa trên bất kỳ datasource:

```yaml
# Grafana alert rule (JSON model)
{
  "title": "High Error Rate",
  "condition": "B",
  "data": [
    {
      "refId": "A",
      "datasourceUid": "prometheus",
      "model": {
        "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m]))"
      }
    },
    {
      "refId": "B",
      "datasourceUid": "__expr__",
      "model": {
        "type": "threshold",
        "conditions": [{"evaluator": {"params": [0.05], "type": "gt"}}]
      }
    }
  ],
  "for": "5m",
  "labels": {"severity": "critical"},
  "annotations": {
    "summary": "Error rate exceeds 5%"
  }
}
```

### 7.4. Grafana Stack (LGTM)

```text
L — Loki    (logs)
G — Grafana (visualization)
T — Tempo   (traces)
M — Mimir   (long-term Prometheus metrics storage)
```

---

## 8. Loki — Log Aggregation

**Loki** là hệ thống log aggregation của Grafana Labs, thiết kế theo nguyên tắc "like Prometheus but for logs".

### 8.1. Tại sao Loki khác Elasticsearch?

| Elasticsearch | Loki |
|---|---|
| Index toàn bộ nội dung log | Chỉ index labels (metadata) |
| Powerful full-text search | LogQL (label-first search) |
| RAM heavy | Lightweight |
| Cost cao ở scale | Cost thấp hơn nhiều |
| Phù hợp: search nhiều | Phù hợp: query theo service/pod |

### 8.2. Kiến trúc Loki

```text
Log Sources
  ├── Promtail (DaemonSet scrape pod logs)
  ├── OTel Collector (push logs qua OTLP)
  ├── Fluentd / Fluent Bit
  └── Application trực tiếp push qua HTTP API

      ↓

Loki Distributor → Ingester → Object Storage (S3)
                            ↓
                         Querier → Grafana
```

### 8.3. Promtail config

```yaml
# promtail-config.yaml
server:
  http_listen_port: 9080

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
    pipeline_stages:
      # Parse JSON log nếu app log JSON
      - json:
          expressions:
            level: level
            message: message
            trace_id: trace_id
      # Set label từ JSON field
      - labels:
          level:
          trace_id:
      # Drop debug logs để giảm volume
      - drop:
          expression: '.*level="debug".*'
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
      - source_labels: [__meta_kubernetes_container_name]
        target_label: container
```

### 8.4. LogQL — Query logs trong Loki

```logql
# Xem log của service cụ thể
{namespace="production", app="backend"}

# Filter có keyword "error"
{namespace="production", app="backend"} |= "error"

# Parse JSON và filter theo level
{namespace="production", app="backend"}
  | json
  | level = "error"

# Đếm error theo 5 phút
sum(rate({namespace="production", app="backend"} |= "error" [5m]))

# Filter bằng regex
{app="backend"} |~ "user_id=\\d+"

# Exclude pattern
{app="backend"} != "health check"

# Kết hợp metric và log (correlated alerting)
sum by (trace_id) (
  rate({app="backend"} | json | level="error" [5m])
)
```

### 8.5. Log-to-Trace Correlation

Khi log và trace có cùng `trace_id`, Grafana có thể link từ log entry → trace:

```json
{
  "timestamp": "2024-06-09T14:30:00Z",
  "level": "error",
  "message": "Database connection timeout",
  "trace_id": "abc123def456",
  "span_id": "789xyz",
  "service": "backend",
  "user_id": "12345"
}
```

Trong Grafana, cấu hình Loki datasource với "Derived Fields":

```text
Field name: trace_id
Regex: "trace_id"="(\w+)"
URL: http://tempo:3200/d/${__value.raw}
```

Click vào trace_id trong log entry → mở trace trong Tempo ngay lập tức.

---

## 9. Observability Stack hoàn chỉnh

### 9.1. Kiến trúc tổng thể

```text
                    APPLICATION LAYER
┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
│Frontend │  │Backend  │  │Worker   │  │Database │
│(OTel SDK│  │(OTel SDK│  │(OTel SDK│  │Exporter │
│ Node.js)│  │ Python) │  │  Go)    │  │         │
└────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘
     │             │            │             │
     └─────────────┴────────────┴─────────────┘
                          │ OTLP gRPC
                          ▼
               ┌─────────────────────┐
               │   OTel Collector    │
               │  (DaemonSet/Sidecar)│
               └──┬──────┬──────┬───┘
                  │      │      │
           metrics│  logs│traces│
                  ▼      ▼      ▼
          ┌──────────┐ ┌────┐ ┌───────┐
          │Prometheus│ │Loki│ │ Tempo │
          └────┬─────┘ └─┬──┘ └───┬───┘
               │          │        │
               └──────────┴────────┘
                          │
                    ┌──────────┐
                    │ Grafana  │
                    │Dashboard │
                    │ Alerting │
                    └──────────┘
                          │
               ┌──────────┴──────────┐
               │                     │
       ┌───────────────┐   ┌──────────────────┐
       │ Alertmanager  │   │ PagerDuty / Slack │
       └───────────────┘   └──────────────────┘
```

### 9.2. Docker Compose để chạy local

```yaml
# docker-compose.yml
version: '3.8'
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.104.0
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
      - "8889:8889"   # Prometheus metrics

  prometheus:
    image: prom/prometheus:v2.53.0
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alerts:/etc/prometheus/alerts
    ports:
      - "9090:9090"

  loki:
    image: grafana/loki:3.1.0
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml

  tempo:
    image: grafana/tempo:2.5.0
    command: ["-config.file=/etc/tempo.yaml"]
    ports:
      - "3200:3200"   # Tempo HTTP
      - "4319:4317"   # OTLP gRPC (avoid conflict)

  grafana:
    image: grafana/grafana:11.1.0
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
    ports:
      - "3000:3000"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning
    depends_on:
      - prometheus
      - loki
      - tempo

  alertmanager:
    image: prom/alertmanager:v0.27.0
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
```

---

## 10. SLO Dashboard trong Grafana

Các panel cần có trong SLO dashboard:

```text
Row: SLO Overview
  ┌────────────────────┬────────────────────┬────────────────────┐
  │ Availability SLI   │ Error Budget Left  │ Burn Rate (1h)     │
  │ 99.95% ✓          │ 73.2%              │ 0.4×               │
  └────────────────────┴────────────────────┴────────────────────┘

Row: Request Metrics
  ┌────────────────────────────────────────────────────────────────┐
  │ Request Rate (graph, split by status)                         │
  └────────────────────────────────────────────────────────────────┘
  ┌────────────────────────────────────────────────────────────────┐
  │ Latency p50 / p95 / p99 (graph)                               │
  └────────────────────────────────────────────────────────────────┘

Row: Error Budget
  ┌────────────────────────────────────────────────────────────────┐
  │ Error Budget Burn Rate (multi-line: 5m, 1h, 6h windows)      │
  └────────────────────────────────────────────────────────────────┘
```

**PromQL cho Error Budget remaining:**

```promql
# % error budget còn lại trong 30 ngày
1 - (
  sum(increase(http_requests_total{status=~"5.."}[30d]))
  /
  (sum(increase(http_requests_total[30d])) * 0.001)
)
```

---

## 11. Best Practices

### OTel

- Dùng **auto-instrumentation** trước, chỉ manual instrument những gì cần thêm.
- Set `OTEL_SERVICE_NAME`, `OTEL_RESOURCE_ATTRIBUTES` qua environment variables — không hardcode trong code.
- Dùng **sampling** cho traces ở môi trường có load cao (tail-based sampling tốt hơn head-based).
- Deploy OTel Collector dưới dạng **DaemonSet** trong Kubernetes (1 collector/node).

### Prometheus

- Dùng **recording rules** cho PromQL query phức tạp dùng trong alert — giảm tải query engine.
- Set `--storage.tsdb.retention.time=90d` hợp lý.
- Dùng **Thanos** hoặc **Mimir** nếu cần long-term storage hoặc multi-cluster.
- Label cardinality: tránh label có nhiều giá trị khác nhau (user_id, request_id) — gây memory explosion.

### Loki

- Thiết kế label cẩn thận: chỉ dùng label có cardinality thấp (namespace, app, level, env).
- Không dùng IP address hoặc user_id làm label.
- Dùng structured logging (JSON) để LogQL parse được.

### SLO

- Bắt đầu với **1-2 SLO** quan trọng nhất, đừng đo tất cả mọi thứ ngay.
- SLO nên phản ánh **user experience**, không phải system metrics.
- Review và điều chỉnh SLO target sau mỗi quarter.
- **Error budget policy** phải rõ ràng: khi hết budget thì ai quyết định gì.

---

## 12. Checklist Day 2

- [ ] Giải thích được sự khác biệt giữa Monitoring và Observability.
- [ ] Phân biệt được SLI, SLO, SLA và Error Budget.
- [ ] Tính được Error Budget từ SLO target.
- [ ] Giải thích được Burn Rate là gì và tại sao quan trọng.
- [ ] Giải thích được tại sao cần multi-window burn rate alert.
- [ ] Hiểu được Fast burn (5min/1h, 14×) và Slow burn (30min/6h, 2×).
- [ ] Viết được Prometheus alert rule cho burn rate.
- [ ] Giải thích được OTel SDK → Collector → Backend pipeline.
- [ ] Phân biệt được Traces, Metrics, Logs và khi nào dùng cái nào.
- [ ] Hiểu được sự khác biệt giữa Loki và Elasticsearch.
- [ ] Biết LogQL cơ bản để query log trong Grafana.
- [ ] Biết PromQL cơ bản: rate(), sum(), histogram_quantile().
- [ ] Hiểu được Metric Types: Counter, Gauge, Histogram.
- [ ] Biết tại sao Histogram tốt hơn Summary cho latency.
- [ ] Hiểu cách Log-to-Trace correlation hoạt động.
