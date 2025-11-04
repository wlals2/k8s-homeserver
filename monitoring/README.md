# Monitoring Stack for Kubernetes

Docker Compose에서 K8s로 마이그레이션한 모니터링 스택입니다.

## 📦 포함된 서비스

| 서비스 | 설명 | 포트 | 접근 URL |
|--------|------|------|----------|
| Prometheus | 메트릭 수집 및 저장 | 30090 | http://192.168.1.187:30090 |
| Grafana | 대시보드 및 시각화 | 30300 | http://192.168.1.187:30300 |
| Node Exporter | 시스템 메트릭 수집 | 9100 | DaemonSet (모든 노드) |
| cAdvisor | 컨테이너 메트릭 수집 | 8080 | DaemonSet (모든 노드) |
| Pushgateway | 배치 작업 메트릭 수집 | 30091 | http://192.168.1.187:30091 |

## 🚀 배포 방법

### 1. 빠른 배포
```bash
cd ~/project/k8s/monitoring
chmod +x deploy.sh
./deploy.sh apply
```

### 2. 수동 배포
```bash
# 스토리지 디렉토리 생성
sudo mkdir -p /data/k8s/monitoring/{prometheus,grafana,pushgateway}
sudo chown -R $(id -u):$(id -g) /data/k8s/monitoring

# Manifest 적용
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-storage.yaml
kubectl apply -f 02-prometheus-config.yaml
kubectl apply -f 03-prometheus.yaml
kubectl apply -f 04-grafana.yaml
kubectl apply -f 05-node-exporter.yaml
kubectl apply -f 06-cadvisor.yaml
kubectl apply -f 07-pushgateway.yaml
```

## 📊 상태 확인

```bash
# 스크립트 사용
./deploy.sh status

# 또는 수동으로
kubectl get all -n monitoring
kubectl get pvc -n monitoring
kubectl get pv | grep monitoring
```

## 🔍 Pod 로그 확인

```bash
# Prometheus 로그
kubectl logs -n monitoring -l app=prometheus -f

# Grafana 로그
kubectl logs -n monitoring -l app=grafana -f

# Node Exporter 로그 (특정 노드)
kubectl logs -n monitoring -l app=node-exporter --tail=50
```

## 📍 접속 정보

### Prometheus
- **URL**: http://192.168.1.187:30090
- **설정**: `/etc/prometheus/prometheus.yml` (ConfigMap)
- **데이터 보존**: 30일
- **스토리지**: /data/k8s/monitoring/prometheus

### Grafana
- **URL**: http://192.168.1.187:30300
- **계정**: admin / admin
- **데이터소스 추가**:
  1. Configuration → Data Sources
  2. Add data source → Prometheus
  3. URL: `http://prometheus:9090`
  4. Save & Test

### Pushgateway
- **URL**: http://192.168.1.187:30091
- **메트릭 푸시 예제**:
```bash
# Hugo 빌드 메트릭 전송 (기존 스크립트 호환)
cat <<EOF | curl --data-binary @- http://192.168.1.187:30091/metrics/job/hugo_build
# TYPE hugo_build_duration_seconds gauge
hugo_build_duration_seconds 2.5
# TYPE hugo_build_timestamp gauge
hugo_build_timestamp $(date +%s)
EOF
```

## 🔧 트러블슈팅

### PVC가 Pending 상태인 경우
```bash
# PV 상태 확인
kubectl get pv

# PVC 이벤트 확인
kubectl describe pvc -n monitoring

# 스토리지 디렉토리 권한 확인
ls -la /data/k8s/monitoring/
```

### Pod가 시작되지 않는 경우
```bash
# Pod 이벤트 확인
kubectl describe pod -n monitoring <pod-name>

# Pod 로그 확인
kubectl logs -n monitoring <pod-name>

# Node 스케줄링 확인
kubectl get pods -n monitoring -o wide
```

### Prometheus가 target을 발견하지 못하는 경우
```bash
# Prometheus UI에서 Status → Targets 확인
# 또는 ConfigMap 다시 적용
kubectl delete configmap prometheus-config -n monitoring
kubectl apply -f 02-prometheus-config.yaml
kubectl rollout restart deployment prometheus -n monitoring
```

## 🗑️ 삭제

```bash
# 스크립트 사용
./deploy.sh delete

# 또는 수동으로
kubectl delete namespace monitoring

# 데이터 삭제 (선택)
sudo rm -rf /data/k8s/monitoring
```

## 📝 Docker Compose와의 차이점

| 항목 | Docker Compose | Kubernetes |
|------|----------------|------------|
| 네트워크 | bridge | Service (ClusterIP/NodePort) |
| 볼륨 | Named volumes | PV/PVC (HostPath) |
| 재시작 정책 | `restart: unless-stopped` | K8s 자동 관리 |
| Node Exporter | 단일 컨테이너 | DaemonSet (모든 노드) |
| cAdvisor | 단일 컨테이너 | DaemonSet (모든 노드) |
| 포트 | 직접 매핑 | NodePort (30000-32767) |

## 🎯 다음 단계

1. **Grafana 대시보드 설정**
   - Node Exporter Full 대시보드 (ID: 1860)
   - Kubernetes Cluster Monitoring (ID: 315)
   
2. **Alert Manager 추가** (선택)
   - Slack, Email 알림 설정
   
3. **Ingress 설정** (선택)
   - 단일 도메인으로 모든 서비스 접근

## 🔗 관련 문서

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Node Exporter Guide](https://github.com/prometheus/node_exporter)