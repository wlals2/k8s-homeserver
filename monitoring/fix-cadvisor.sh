#!/bin/bash

echo "=== 1. cAdvisor 로그 확인 ==="
CADVISOR_POD=$(kubectl get pods -n monitoring -l app=cadvisor -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n monitoring $CADVISOR_POD --tail=20

echo ""
echo "=== 2. Security Context 추가 ==="
kubectl patch daemonset cadvisor -n monitoring --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/securityContext",
    "value": {
      "privileged": true
    }
  }
]' 2>&1 | grep -v "already exists" || echo "Patch 적용됨"

echo ""
echo "=== 3. hostNetwork와 hostPID 추가 ==="
kubectl patch daemonset cadvisor -n monitoring --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/hostNetwork", "value": true},
  {"op": "add", "path": "/spec/template/spec/hostPID", "value": true}
]' 2>&1 | grep -v "already exists" || echo "Patch 적용됨"

echo ""
echo "=== 4. 30초 대기 ==="
sleep 30

echo ""
echo "=== 5. 최종 상태 ==="
kubectl get pods -n monitoring -o wide

echo ""
echo "=== 6. cAdvisor 상태 확인 ==="
kubectl get pods -n monitoring -l app=cadvisor
