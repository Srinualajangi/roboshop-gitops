#!/usr/bin/env bash
# Usage: gen-app.sh NAME CONTAINER_PORT SERVICE_PORT HEALTH_PATH [KEY=VALUE ...]
# Prints a Deployment + Service for one RoboShop service. HEALTH_PATH "-" = tcp probe, "none" = no probe/no service.
set -euo pipefail
NAME=$1 CPORT=$2 SPORT=$3 HEALTH=$4; shift 4
ENV_YAML=""
for kv in "$@"; do ENV_YAML+="            - {name: ${kv%%=*}, value: \"${kv#*=}\"}"$'\n'; done
if [ "$HEALTH" = "none" ]; then PROBE=""
elif [ "$HEALTH" = "-" ]; then PROBE="          readinessProbe: {tcpSocket: {port: $CPORT}, periodSeconds: 5}"
else PROBE="          readinessProbe: {httpGet: {path: $HEALTH, port: $CPORT}, periodSeconds: 5, failureThreshold: 3}
          startupProbe: {httpGet: {path: $HEALTH, port: $CPORT}, periodSeconds: 5, failureThreshold: 36}"
fi
cat <<YAML
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: $NAME, namespace: roboshop-dev, labels: {app: $NAME, tier: api}}
spec:
  replicas: 1
  selector: {matchLabels: {app: $NAME}}
  template:
    metadata: {labels: {app: $NAME, tier: api}}
    spec:
      imagePullSecrets: [{name: ecr-pull}]
      containers:
        - name: $NAME
          image: $REGISTRY/roboshop/$NAME:$IMAGE_TAG
          ports: [{containerPort: $CPORT, name: http}]
          env:
${ENV_YAML:-            []}
          resources: {requests: {cpu: 50m, memory: 192Mi}, limits: {memory: 192Mi}}
$PROBE
YAML
[ "$HEALTH" = "none" ] && exit 0
cat <<YAML
---
apiVersion: v1
kind: Service
metadata: {name: $NAME, namespace: roboshop-dev, labels: {app: $NAME}}
spec:
  selector: {app: $NAME}
  ports: [{name: http, port: $SPORT, targetPort: $CPORT}]
YAML
