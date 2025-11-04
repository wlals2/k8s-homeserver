# Nextcloud on Kubernetes

Docker Compose에서 K8s로 마이그레이션한 Nextcloud 개인 클라우드입니다.

## 📦 포함된 서비스

| 서비스 | 설명 | 내부 포트 | 접근 URL |
|--------|------|-----------|----------|
| Nextcloud | 개인 클라우드 애플리케이션 | 80 | http://192.168.1.187:30888 |
| MariaDB | 데이터베이스 | 3306 | 내부 전용 (ClusterIP) |

## 🚀 배포 방법

### 옵션 1: 새로운 설치 (깨끗한 시작)

```bash
cd ~/project/k8s/nextcloud
chmod +x deploy.sh
./deploy.sh apply
```

### 옵션 2: 기존 Docker 데이터 마이그레이션

기존 Docker Compose로 실행하던 Nextcloud 데이터를 K8s로 옮기려면:

```bash
cd ~/project/k8s/nextcloud
chmod +x deploy.sh

# 1. 먼저 데이터 마이그레이션
./deploy.sh migrate

# 2. 그 다음 배포
./deploy.sh apply
```

**마이그레이션 과정:**
- Docker 데이터 백업: `~/nextcloud-backup-YYYYMMDD-HHMMSS/`
- DB 데이터: `/data/k8s/nextcloud/db/`
- 앱 데이터: `/data/k8s/nextcloud/app/`
- 사용자 데이터: `/data/k8s/nextcloud/data/`

## 📊 상태 확인

```bash
# 스크립트 사용
./deploy.sh status

# Pod 상태 감시
kubectl get pods -n nextcloud -w

# 로그 확인
./deploy.sh logs
```

## 🔍 트러블슈팅

### Nextcloud Pod가 CrashLoopBackOff 상태

```bash
# 로그 확인
kubectl logs -n nextcloud -l app=nextcloud --tail=100

# 일반적인 원인:
# 1. DB가 준비되지 않음 - MariaDB Pod 확인
# 2. 권한 문제 - 아래 명령어로 수정
sudo chown -R 33:33 /data/k8s/nextcloud/{app,data}
sudo chown -R 999:999 /data/k8s/nextcloud/db

# Pod 재시작
kubectl rollout restart deployment nextcloud -n nextcloud
```

### MariaDB 연결 실패

```bash
# MariaDB 상태 확인
kubectl get pods -n nextcloud -l app=nextcloud-db

# MariaDB 로그 확인
kubectl logs -n nextcloud -l app=nextcloud-db --tail=50

# Secret 확인
kubectl get secret nextcloud-secrets -n nextcloud -o yaml

# MariaDB 재시작
kubectl rollout restart deployment nextcloud-db -n nextcloud
```

### Trusted Domain 에러

브라우저에서 접속 시 "Access through untrusted domain" 에러가 발생하면:

```bash
# Nextcloud Pod에 접속
kubectl exec -it -n nextcloud deployment/nextcloud -- bash

# config.php 수정
vi /var/www/html/config/config.php

# trusted_domains 배열에 추가
'trusted_domains' =>
  array (
    0 => '192.168.1.187:30888',
    1 => '192.168.1.187',
    2 => 'localhost',
  ),

# 또는 occ 명령어 사용
php occ config:system:set trusted_domains 1 --value=192.168.1.187:30888
```

### 데이터 권한 문제

```bash
# Nextcloud 데이터 디렉토리 권한 수정
sudo chown -R 33:33 /data/k8s/nextcloud/app
sudo chown -R 33:33 /data/k8s/nextcloud/data

# Pod 재시작
kubectl rollout restart deployment nextcloud -n nextcloud
```

## 📍 초기 설정 가이드

### 1. 처음 접속 (새로운 설치)

1. **브라우저로 접속**: http://192.168.1.187:30888
2. **관리자 계정 생성**:
   - 사용자명: 원하는 관리자 이름
   - 비밀번호: 안전한 비밀번호
3. **데이터베이스 설정**:
   - 데이터베이스 종류: MySQL/MariaDB
   - 데이터베이스 사용자: `nextcloud`
   - 데이터베이스 비밀번호: `nextcloud_password`
   - 데이터베이스 이름: `nextcloud`
   - 데이터베이스 호스트: `nextcloud-db:3306`
4. **설치 완료** 버튼 클릭

### 2. 마이그레이션 후 접속

기존 Docker 데이터를 마이그레이션한 경우:
- 기존 계정 정보로 로그인
- 모든 파일과 설정이 유지됨

## 🔧 유지보수

### Nextcloud 업그레이드

```bash
# 이미지 버전 변경
kubectl set image deployment/nextcloud nextcloud=nextcloud:28 -n nextcloud

# 또는 manifest 수정 후
kubectl apply -f 04-nextcloud.yaml

# 업그레이드 진행 상황 확인
kubectl rollout status deployment/nextcloud -n nextcloud
```

### 백업

```bash
# 전체 데이터 백업
sudo tar -czf nextcloud-backup-$(date +%Y%m%d).tar.gz /data/k8s/nextcloud/

# 데이터베이스만 백업
kubectl exec -n nextcloud deployment/nextcloud-db -- \
  mysqldump -u root -pnextcloud_root_password nextcloud > nextcloud-db-backup.sql
```

### 복원

```bash
# 전체 데이터 복원
sudo tar -xzf nextcloud-backup-YYYYMMDD.tar.gz -C /

# 데이터베이스 복원
kubectl exec -i -n nextcloud deployment/nextcloud-db -- \
  mysql -u root -pnextcloud_root_password nextcloud < nextcloud-db-backup.sql

# Pod 재시작
kubectl rollout restart deployment/nextcloud -n nextcloud
kubectl rollout restart deployment/nextcloud-db -n nextcloud
```

## 🗑️ 삭제

```bash
# 서비스만 삭제 (데이터 유지)
./deploy.sh delete

# 데이터까지 완전 삭제
./deploy.sh delete
sudo rm -rf /data/k8s/nextcloud
```

## 📝 Docker Compose와의 차이점

| 항목 | Docker Compose | Kubernetes |
|------|----------------|------------|
| 포트 | 8888:80 | NodePort 30888 |
| 네트워크 | nextcloud_net (bridge) | Service (ClusterIP) |
| 볼륨 | ./db, ./nextcloud, ./data | PV/PVC (HostPath) |
| 재시작 | unless-stopped | Always (K8s 기본) |
| 헬스체크 | 없음 | Liveness/Readiness Probe |
| 의존성 | depends_on | InitContainer 또는 대기 |

## 🎯 성능 최적화

### 리소스 조정

현재 설정:
- **Nextcloud**: 200m CPU / 512Mi RAM (요청), 2 CPU / 2Gi RAM (제한)
- **MariaDB**: 200m CPU / 512Mi RAM (요청), 1 CPU / 2Gi RAM (제한)

사용량에 따라 `04-nextcloud.yaml`과 `03-mariadb.yaml`의 `resources` 섹션을 수정하세요.

### Redis 캐시 추가 (선택)

성능 향상을 위해 Redis를 추가할 수 있습니다:
```bash
# Redis Deployment 추가 (별도 manifest 필요)
# config.php에 Redis 설정 추가
```

## 🔗 관련 문서

- [Nextcloud Documentation](https://docs.nextcloud.com/)
- [Nextcloud Admin Manual](https://docs.nextcloud.com/server/latest/admin_manual/)
- [MariaDB in Kubernetes](https://mariadb.com/kb/en/kubernetes/)

## 💡 추가 기능

### 외부 접근 설정 (선택)

현재는 내부 네트워크에서만 접근 가능합니다. 외부에서 접근하려면:

1. **Ingress Controller 설치** (Nginx Ingress)
2. **Let's Encrypt로 SSL 설정**
3. **도메인 연결**

자세한 내용은 Ingress 설정 문서를 참고하세요.