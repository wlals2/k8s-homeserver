#!/bin/bash

echo "=== 1. cAdvisor rootfs를 read-write로 변경 ==="
kubectl get daemonset cadvisor -n monitoring -o yaml | \
  sed 's/readOnly: true/readOnly: false/g' | \
  kubectl apply -f -

echo ""
echo "=== 2. Grafana initContainer 추가 ==="
kubectl patch deployment grafana -n monitoring --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/initContainers",
    "value": [
      {
        "name": "init-chown-data",
        "image": "busybox:latest",
        "command": ["sh", "-c", "chown -R 472:472 /var/lib/grafana && chmod -R 755 /var/lib/grafana"],
        "volumeMounts": [
          {
            "name": "grafana-data",
            "mountPath": "/var/lib/grafana"
          }
        ]
      }
    ]
  }
]'

echo ""
echo "=== 3. Prometheus initContainer 추가 ==="
kubectl patch deployment prometheus -n monitoring --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/initContainers",
    "value": [
      {
        "name": "init-chown-data",
        "image": "busybox:latest",
        "command": ["sh", "-c", "chown -R 65534:65534 /prometheus && chmod -R 755 /prometheus"],
        "volumeMounts": [
          {
            "name": "prometheus-data",
            "mountPath": "/prometheus"
          }
        ]
      }
    ]
  }
]'

echo ""
echo "=== 4. 모든 Pod 재시작 ==="
kubectl delete pod -n monitoring -l app=grafana
kubectl delete pod -n monitoring -l app=prometheus
kubectl rollout restart daemonset cadvisor -n monitoring

echo ""
echo "=== 5. 30초 대기 ==="
sleep 30

echo ""
echo "=== 6. 최종 상태 확인 ==="
kubectl get pods -n monitoring -o wide

echo ""
echo "=== 7. 실패한 Pod가 있다면 로그 확인 ==="
kubectl get pods -n monitoring --field-selector=status.phase!=Running -o name | while read pod; do
  echo ">>> $pod <<<"
  kubectl logs -n monitoring $pod --tail=5 2>&1 || echo "로그 없음"
  echo ""
done
