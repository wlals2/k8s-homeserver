#!/bin/bash

# Kubernetes Dashboard 배포 스크립트
# 사용법: ./deploy.sh [apply|delete|token|status]

set -e

NAMESPACE="kubernetes-dashboard"
DASHBOARD_VERSION="v2.7.0"

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 배포 함수
deploy() {
    log_step "Kubernetes Dashboard 배포 시작..."
    echo ""
    
    # Namespace 생성
    log_info "Namespace 생성..."
    kubectl apply -f 00-namespace.yaml
    
    # ServiceAccount 및 RBAC 설정
    log_info "ServiceAccount 및 권한 설정..."
    kubectl apply -f 01-serviceaccount.yaml
    
    # Dashboard 배포 (공식 manifest)
    log_info "Dashboard 리소스 배포..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/${DASHBOARD_VERSION}/aio/deploy/recommended.yaml
    
    # NodePort로 변경
    log_info "Service를 NodePort로 변경..."
    kubectl patch svc kubernetes-dashboard -n ${NAMESPACE} \
        -p '{"spec": {"type": "NodePort", "ports": [{"port": 443, "nodePort": 30443, "targetPort": 8443}]}}'
    
    echo ""
    log_info "배포 완료!"
    echo ""
    
    # Pod가 준비될 때까지 대기
    log_info "Dashboard Pod가 준비될 때까지 대기 중..."
    kubectl wait --for=condition=ready pod -l k8s-app=kubernetes-dashboard -n ${NAMESPACE} --timeout=300s || true
    
    echo ""
    log_info "접속 정보:"
    echo "  URL: https://192.168.1.187:30443"
    echo ""
    log_warn "주의: 자체 서명 인증서이므로 브라우저에서 '안전하지 않음' 경고가 표시됩니다."
    log_warn "      '고급' → '계속 진행'을 선택하세요."
    echo ""
    log_info "토큰 확인: ./deploy.sh token"
}

# 삭제 함수
delete() {
    log_warn "Kubernetes Dashboard 삭제 중..."
    echo ""
    
    kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/${DASHBOARD_VERSION}/aio/deploy/recommended.yaml --ignore-not-found=true
    kubectl delete -f 01-serviceaccount.yaml --ignore-not-found=true
    
    log_warn "네임스페이스 삭제 여부를 확인하세요 (5초 대기)..."
    sleep 5
    kubectl delete -f 00-namespace.yaml --ignore-not-found=true
    
    log_info "삭제 완료"
}

# 토큰 확인 함수
get_token() {
    log_info "Dashboard 접속 토큰:"
    echo ""
    
    # Token 추출
    TOKEN=$(kubectl -n ${NAMESPACE} get secret admin-user-token -o jsonpath='{.data.token}' | base64 -d)
    
    if [ -z "$TOKEN" ]; then
        log_error "토큰을 찾을 수 없습니다. Dashboard가 배포되었는지 확인하세요."
        exit 1
    fi
    
    echo "======================================"
    echo "$TOKEN"
    echo "======================================"
    echo ""
    
    log_info "사용 방법:"
    echo "1. 브라우저로 https://192.168.1.187:30443 접속"
    echo "2. 'Token' 선택"
    echo "3. 위의 토큰을 복사하여 붙여넣기"
    echo "4. 'Sign in' 클릭"
    echo ""
    
    # 토큰을 파일로 저장
    echo "$TOKEN" > dashboard-token.txt
    log_info "토큰이 dashboard-token.txt 파일로 저장되었습니다."
}

# 상태 확인 함수
status() {
    log_info "Kubernetes Dashboard 상태:"
    echo ""
    
    echo "=== Pods ==="
    kubectl get pods -n ${NAMESPACE} -o wide
    echo ""
    
    echo "=== Services ==="
    kubectl get svc -n ${NAMESPACE}
    echo ""
    
    echo "=== ServiceAccounts ==="
    kubectl get sa -n ${NAMESPACE}
    echo ""
    
    log_info "접속 URL: https://192.168.1.187:30443"
    echo ""
    log_info "토큰 확인: ./deploy.sh token"
}

# Proxy 함수 (로컬 테스트용)
proxy() {
    log_info "kubectl proxy 시작..."
    echo ""
    log_info "다음 URL로 접속하세요:"
    echo "  http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
    echo ""
    log_warn "Ctrl+C로 종료"
    echo ""
    
    kubectl proxy
}

# 메인 로직
case "${1:-status}" in
    apply|deploy)
        deploy
        ;;
    delete|remove)
        delete
        ;;
    token)
        get_token
        ;;
    status)
        status
        ;;
    proxy)
        proxy
        ;;
    *)
        echo "사용법: $0 {apply|delete|token|status|proxy}"
        echo "  apply/deploy  - Dashboard 배포"
        echo "  delete/remove - Dashboard 삭제"
        echo "  token         - 접속 토큰 확인"
        echo "  status        - 현재 상태 확인 (기본값)"
        echo "  proxy         - kubectl proxy로 접속 (로컬 테스트용)"
        exit 1
        ;;
esac