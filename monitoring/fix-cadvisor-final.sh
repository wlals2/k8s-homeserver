#!/bin/bash

echo "=== 1. 기존 cAdvisor 삭제 ==="
kubectl delete daemonset cadvisor -n monitoring

echo ""
echo "=== 2. 새로운 cAdvisor 배포 (cgroup 마운트 포함) ==="
cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cadvisor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: cadvisor
  template:
    metadata:
      labels:
        app: cadvisor
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: cadvisor
        image: gcr.io/cadvisor/cadvisor:v0.47.0
        securityContext:
          privileged: true
        args:
          - --housekeeping_interval=10s
          - --docker_only=false
        ports:
        - name: http
          containerPort: 8080
          hostPort: 8080
          protocol: TCP
        volumeMounts:
        - name: rootfs
          mountPath: /rootfs
          readOnly: true
        - name: var-run
          mountPath: /var/run
          readOnly: false
        - name: sys
          mountPath: /sys
          readOnly: true
        - name: docker
          mountPath: /var/lib/docker
          readOnly: true
        - name: disk
          mountPath: /dev/disk
          readOnly: true
        - name: cgroup
          mountPath: /sys/fs/cgroup
          readOnly: true
        resources:
          requests:
            memory: 128Mi
            cpu: 100m
          limits:
            memory: 512Mi
            cpu: 300m
      volumes:
      - name: rootfs
        hostPath:
          path: /
      - name: var-run
        hostPath:
          path: /var/run
      - name: sys
        hostPath:
          path: /sys
      - name: docker
        hostPath:
          path: /var/lib/docker
      - name: disk
        hostPath:
          path: /dev/disk
      - name: cgroup
        hostPath:
          path: /sys/fs/cgroup
YAML

echo ""
echo "=== 3. 30초 대기 ==="
sleep 30

echo ""
echo "=== 4. cAdvisor 상태 확인 ==="
kubectl get pods -n monitoring -l app=cadvisor -o wide

echo ""
echo "=== 5. 로그 확인 ==="
CADVISOR_POD=$(kubectl get pods -n monitoring -l app=cadvisor -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$CADVISOR_POD" ]; then
  echo "Pod: $CADVISOR_POD"
  kubectl logs -n monitoring $CADVISOR_POD --tail=10
fi

echo ""
echo "=== 6. 전체 모니터링 스택 상태 ==="
kubectl get pods -n monitoring -o wide
