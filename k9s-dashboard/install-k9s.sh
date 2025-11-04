#!/bin/bash

# K9s 설치 스크립트
# Kubernetes CLI 터미널 UI

set -e

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# K9s 버전
K9S_VERSION="v0.32.4"

log_info "K9s ${K9S_VERSION} 설치 시작..."
echo ""

# 1. 이전 버전 확인
if command -v k9s &> /dev/null; then
    CURRENT_VERSION=$(k9s version -s 2>/dev/null | head -1 || echo "unknown")
    log_warn "K9s가 이미 설치되어 있습니다: ${CURRENT_VERSION}"
    read -p "재설치하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "설치를 취소합니다."
        exit 0
    fi
fi

# 2. 임시 디렉토리 생성
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# 3. K9s 다운로드
log_info "K9s 다운로드 중..."
wget -q --show-progress \
    "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" \
    -O k9s.tar.gz

if [ $? -ne 0 ]; then
    log_error "다운로드 실패"
    exit 1
fi

# 4. 압축 해제
log_info "압축 해제 중..."
tar -xzf k9s.tar.gz

# 5. 설치
log_info "K9s 설치 중..."
sudo mv k9s /usr/local/bin/
sudo chmod +x /usr/local/bin/k9s

# 6. 정리
cd ~
rm -rf "$TEMP_DIR"

# 7. 설치 확인
log_info "설치 확인 중..."
if command -v k9s &> /dev/null; then
    K9S_INSTALLED_VERSION=$(k9s version -s 2>/dev/null | head -1)
    log_info "K9s 설치 완료!"
    echo ""
    echo "======================================"
    echo "  버전: ${K9S_INSTALLED_VERSION}"
    echo "  위치: $(which k9s)"
    echo "======================================"
    echo ""
else
    log_error "설치 확인 실패"
    exit 1
fi

# 8. 설정 디렉토리 생성
log_info "설정 디렉토리 생성 중..."
mkdir -p ~/.config/k9s

# 9. 기본 설정 파일 생성 (선택)
if [ ! -f ~/.config/k9s/config.yml ]; then
    log_info "기본 설정 파일 생성 중..."
    cat > ~/.config/k9s/config.yml << 'EOF'
k9s:
  # 리프레시 간격 (초)
  refreshRate: 2
  
  # 최대 로그 버퍼 크기
  maxConnRetry: 5
  
  # 로그 설정
  logger:
    tail: 100
    buffer: 5000
    sinceSeconds: 60
    
  # UI 설정
  ui:
    # 스킨 (기본값: default)
    skin: default
    enableMouse: false
    headless: false
    logoless: false
    crumbsless: false
    reactive: false
    noIcons: false
EOF
    log_info "설정 파일 생성 완료: ~/.config/k9s/config.yml"
fi

echo ""
log_info "K9s 사용 방법:"
echo ""
echo "  1. 시작하기:"
echo "     $ k9s"
echo ""
echo "  2. 특정 네임스페이스로 시작:"
echo "     $ k9s -n monitoring"
echo "     $ k9s -n nextcloud"
echo ""
echo "  3. 주요 단축키:"
echo "     :pods       - Pod 목록"
echo "     :svc        - Service 목록"
echo "     :deploy     - Deployment 목록"
echo "     :ns         - Namespace 전환"
echo "     l           - 로그 보기"
echo "     s           - 쉘 접속"
echo "     d           - Describe"
echo "     y           - YAML 보기"
echo "     /           - 검색"
echo "     ?           - 도움말"
echo "     q           - 종료"
echo ""
echo "  4. 별칭 설정 (선택):"
echo "     echo 'alias k=\"k9s\"' >> ~/.bashrc"
echo "     source ~/.bashrc"
echo ""

log_info "설치 완료! 'k9s' 명령어로 시작하세요."