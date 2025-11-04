#!/bin/bash

echo "=== 1. 디렉토리 생성 및 권한 설정 ==="
sudo mkdir -p /mnt/data/{grafana,prometheus,pushgateway}
sudo chown -R 472:472 /mnt/data/grafana
sudo chown -R 65534:65534 /mnt/data/prometheus
sudo chown -R 65534:65534 /mnt/data/pushgateway
sudo chmod -R 755 /mnt/data/{grafana,prometheus,pushgateway}

echo "=== 2. 디렉토리 확인 ==="
ls -la /mnt/data/

echo "=== 3. Pod 재시작 ==="
kubectl delete pod -n monitoring -l app=grafana
kubectl delete pod -n monitoring -l app=prometheus
kubectl rollout restart daemonset -n monitoring cadvisor
kubectl rollout restart daemonset -n monitoring node-exporter

echo "=== 4. 30초 대기 후 상태 확인 ==="
sleep 30
kubectl get pods -n monitoring

echo ""
echo "Worker 노드의 DNS 문제는 각 노드에 직접 접속해서 해결해야 합니다:"
echo "  ssh k8s-worker1"
echo "  sudo bash -c 'echo \"nameserver 8.8.8.8\" >> /etc/resolv.conf'"
