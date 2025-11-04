#!/bin/bash

# Nextcloud 배포 스크립트
# 사용법: ./deploy.sh [apply|delete|status|migrate]

set -e

NAMESPACE="nextcloud"
MANIFESTS_DIR="$(dirname "$0")"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 스토리지 디렉토리 생성
create_storage_dirs() {
    log_info "스토리지 디렉토리 생성 중..."
    sudo mkdir -p /data/k8s/nextcloud/{db,app,data}
    sudo chown -R $(id -u):$(id -g) /data/k8s/nextcloud
    log_info "스토리지 디렉토리 생성 완료"
}

# 기존 Docker 데이터 마이그레이션
migrate_data() {
    log_step "기존 Docker 데이터 마이그레이션"
    
    DOCKER_DATA_DIR="$HOME/docker/nextcloud"
    K8S_DATA_DIR="/data/k8s/nextcloud"
    
    if [ ! -d "$DOCKER_DATA_DIR" ]; then
        log_warn "Docker 데이터 디렉토리를 찾을 수 없습니다: $DOCKER_DATA_DIR"
        log_info "새로운 설치로 진행합니다."
        return
    fi
    
    log_warn "기존 Docker 데이터를 K8s로 마이그레이션합니다."
    log_warn "이 작업은 시간이 걸릴 수 있습니다..."
    echo ""
    
    # 백업 생성
    BACKUP_DIR="$HOME/nextcloud-backup-$(date +%Y%m%d-%H%M%S)"
    log_info "백업 생성 중: $BACKUP_DIR"
    sudo cp -a "$DOCKER_DATA_DIR" "$BACKUP_DIR"
    log_info "백업 완료"
    echo ""
    
    # 데이터 복사
    if [ -d "$DOCKER_DATA_DIR/db" ]; then
        log_info "MariaDB 데이터 복사 중..."
        sudo cp -a "$DOCKER_DATA_DIR/db/"* "$K8S_DATA_DIR/db/" 2>/dev/null || true
        log_info "MariaDB 데이터 복사 완료"
    fi
    
    if [ -d "$DOCKER_DATA_DIR/nextcloud" ]; then
        log_info "Nextcloud 애플리케이션 데이터 복사 중..."
        sudo cp -a "$DOCKER_DATA_DIR/nextcloud/"* "$K8S_DATA_DIR/app/" 2>/dev/null || true
        log_info "Nextcloud 애플리케이션 데이터 복사 완료"
    fi
    
    if [ -d "$DOCKER_DATA_DIR/data" ]; then
        log_info "사용자 데이터 복사 중..."
        sudo cp -a "$DOCKER_DATA_DIR/data/"* "$K8S_DATA_DIR/data/" 2>/dev/null || true
        log_info "사용자 데이터 복사 완료"
    fi
    
    # 권한 설정
    log_info "권한 설정 중..."
    sudo chown -R 33:33 "$K8S_DATA_DIR/app" 2>/dev/null || true  # www-data
    sudo chown -R 999:999 "$K8S_DATA_DIR/db" 2>/dev/null || true  # mysql
    sudo chown -R 33:33 "$K8S_DATA_DIR/data" 2>/dev/null || true  # www-data
    log_info "권한 설정 완료"
    
    echo ""
    log_info "데이터 마이그레이션 완료!"
    log_info "백업 위치: $BACKUP_DIR"
    echo ""
}

# 배포 함수
deploy() {
    log_step "Nextcloud 배포 시작..."
    echo ""
    
    # 스토리지 디렉토리 생성
    create_storage_dirs
    
    # Manifest 파일 순서대로 적용
    log_info "Namespace 생성..."
    kubectl apply -f "${MANIFESTS_DIR}/00-namespace.yaml"
    
    log_info "Storage 설정..."
    kubectl apply -f "${MANIFESTS_DIR}/01-storage.yaml"
    
    log_info "Secrets 생성..."
    kubectl apply -f "${MANIFESTS_DIR}/02-secrets.yaml"
    
    log_info "MariaDB 배포..."
    kubectl apply -f "${MANIFESTS_DIR}/03-mariadb.yaml"
    
    log_info "MariaDB가 준비될 때까지 대기 중..."
    kubectl wait --for=condition=ready pod -l app=nextcloud-db -n ${NAMESPACE} --timeout=300s || true
    sleep 10
    
    log_info "Nextcloud 배포..."
    kubectl apply -f "${MANIFESTS_DIR}/04-nextcloud.yaml"
    
    echo ""
    log_info "배포 완료!"
    echo ""
    log_info "서비스 접근 정보:"
    echo "  - Nextcloud: http://192.168.1.187:30888"
    echo ""
    log_warn "초기 설정 안내:"
    echo "  1. 브라우저로 http://192.168.1.187:30888 접속"
    echo "  2. 관리자 계정 생성"
    echo "  3. 데이터베이스는 이미 설정되어 있습니다"
    echo ""
    log_info "Pod 준비 상태 확인: kubectl get pods -n ${NAMESPACE} -w"
}

# 삭제 함수
delete() {
    log_warn "Nextcloud 스택 삭제 중..."
    echo ""
    
    log_warn "주의: 데이터는 삭제되지 않습니다 (/data/k8s/nextcloud)"
    echo ""
    
    kubectl delete -f "${MANIFESTS_DIR}/04-nextcloud.yaml" --ignore-not-found=true
    sleep 5
    kubectl delete -f "${MANIFESTS_DIR}/03-mariadb.yaml" --ignore-not-found=true
    kubectl delete -f "${MANIFESTS_DIR}/02-secrets.yaml" --ignore-not-found=true
    kubectl delete -f "${MANIFESTS_DIR}/01-storage.yaml" --ignore-not-found=true
    
    log_warn "네임스페이스 삭제 여부를 확인하세요 (5초 대기)..."
    sleep 5
    kubectl delete -f "${MANIFESTS_DIR}/00-namespace.yaml" --ignore-not-found=true
    
    echo ""
    log_info "삭제 완료"
    log_info "데이터를 완전히 삭제하려면: sudo rm -rf /data/k8s/nextcloud"
}

# 상태 확인 함수
status() {
    log_info "Nextcloud 상태:"
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
    
    echo "=== Secrets ==="
    kubectl get secrets -n ${NAMESPACE}
    echo ""
    
    log_info "Nextcloud 접속: http://192.168.1.187:30888"
}

# 로그 확인 함수
logs() {
    echo "선택하세요:"
    echo "1) Nextcloud 로그"
    echo "2) MariaDB 로그"
    echo "3) 전체 로그"
    read -p "선택 (1-3): " choice
    
    case $choice in
        1)
            kubectl logs -n ${NAMESPACE} -l app=nextcloud -f --tail=100
            ;;
        2)
            kubectl logs -n ${NAMESPACE} -l app=nextcloud-db -f --tail=100
            ;;
        3)
            echo "=== Nextcloud 로그 ==="
            kubectl logs -n ${NAMESPACE} -l app=nextcloud --tail=50
            echo ""
            echo "=== MariaDB 로그 ==="
            kubectl logs -n ${NAMESPACE} -l app=nextcloud-db --tail=50
            ;;
        *)
            log_error "잘못된 선택입니다."
            exit 1
            ;;
    esac
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
    migrate)
        create_storage_dirs
        migrate_data
        ;;
    logs)
        logs
        ;;
    *)
        echo "사용법: $0 {apply|delete|status|migrate|logs}"
        echo "  apply/deploy  - Nextcloud 스택 배포"
        echo "  delete/remove - Nextcloud 스택 삭제"
        echo "  status        - 현재 상태 확인 (기본값)"
        echo "  migrate       - Docker 데이터를 K8s로 마이그레이션"
        echo "  logs          - 로그 확인"
        exit 1
        ;;
esac