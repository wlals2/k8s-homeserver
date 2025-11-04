#!/bin/bash

# 모니터링 스택 배포 스크립트
# 사용법: ./deploy.sh [apply|delete|status]

set -e

NAMESPACE="monitoring"
MANIFESTS_DIR="$(dirname "$0")"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 스토리지 디렉토리 생성
create_storage_dirs() {
    log_info "스토리지 디렉토리 생성 중..."
    sudo mkdir -p /data/k8s/monitoring/{prometheus,grafana,pushgateway}
    sudo chown -R $(id -u):$(id -g) /data/k8s/monitoring
    log_info "스토리지 디렉토리 생성 완료"
}

# 배포 함수
deploy() {
    log_info "모니터링 스택 배포 시작..."
    
    # 스토리지 디렉토리 생성
    create_storage_dirs
    
    # Manifest 파일 순서대로 적용
    log_info "Namespace 생성..."
    kubectl apply -f "${MANIFESTS_DIR}/00-namespace.yaml"
    
    log_info "Storage 설정..."
    kubectl apply -f "${MANIFESTS_DIR}/01-storage.yaml"
    
    log_info "Prometheus ConfigMap 적용..."
    kubectl apply -f "${MANIFESTS_DIR}/02-prometheus-config.yaml"
    
    log_info "Prometheus 배포..."
    kubectl apply -f "${MANIFESTS_DIR}/03-prometheus.yaml"
    
    log_info "Grafana 배포..."
    kubectl apply -f "${MANIFESTS_DIR}/04-grafana.yaml"
    
    log_info "Node Exporter 배포..."
    kubectl apply -f "${MANIFESTS_DIR}/05-node-exporter.yaml"
    
    log_info "cAdvisor 배포..."
    kubectl apply -f "${MANIFESTS_DIR}/06-cadvisor.yaml"
    
    log_info "Pushgateway 배포..."
    kubectl apply -f "${MANIFESTS_DIR}/07-pushgateway.yaml"
    
    log_info "배포 완료!"
    echo ""
    log_info "서비스 접근 정보:"
    echo "  - Prometheus: http://192.168.1.187:30090"
    echo "  - Grafana:    http://192.168.1.187:30300 (admin/admin)"
    echo "  - Pushgateway: http://192.168.1.187:30091"
    echo ""
    log_info "상태 확인: kubectl get all -n ${NAMESPACE}"
}

# 삭제 함수
delete() {
    log_warn "모니터링 스택 삭제 중..."
    
    kubectl delete -f "${MANIFESTS_DIR}/07-pushgateway.yaml" --ignore-not-found=true
    kubectl delete -f "${MANIFESTS_DIR}/06-cadvisor.yaml" --ignore-not-found=true
    kubectl delete -f "${MANIFESTS_DIR}/05-node-exporter.yaml" --ignore-not-found=true
    kubectl delete -f "${MANIFESTS_DIR}/04-grafana.yaml" --ignore-not-found=true
    kubectl delete -f "${MANIFESTS_DIR}/03-prometheus.yaml" --ignore-not-found=true
    kubectl delete -f "${MANIFESTS_DIR}/02-prometheus-config.yaml" --ignore-not-found=true
    kubectl delete -f "${MANIFESTS_DIR}/01-storage.yaml" --ignore-not-found=true
    
    log_warn "네임스페이스 삭제 여부를 확인하세요 (5초 대기)..."
    sleep 5
    kubectl delete -f "${MANIFESTS_DIR}/00-namespace.yaml" --ignore-not-found=true
    
    log_info "삭제 완료"
}

# 상태 확인 함수
status() {
    log_info "모니터링 스택 상태:"
    echo ""
    
    echo "=== Pods ==="
    kubectl get pods -n ${NAMESPACE} -o wide
    echo ""
    
    echo "=== Services ==="
    kubectl get svc -n ${NAMESPACE}
    echo ""
    
    echo "=== PVC ==="
    kubectl get pvc -n ${NAMESPACE}
    echo ""
    
    echo "=== PV ==="
    kubectl get pv | grep monitoring
}

# 메인 로직
case "${1:-status}" in
    apply|deploy)
        deploy
        ;;
    delete|remove)
        delete
        ;;
    status)
        status
        ;;
    *)
        echo "사용법: $0 {apply|delete|status}"
        echo "  apply/deploy  - 모니터링 스택 배포"
        echo "  delete/remove - 모니터링 스택 삭제"
        echo "  status        - 현재 상태 확인 (기본값)"
        exit 1
        ;;
esac