#!/usr/bin/env bash
# Prints yes/no for each persona x action x environment using impersonation.
set -uo pipefail
declare -A WHO=([developer]=roboshop-developers [devops]=roboshop-devops [auditor]=roboshop-auditors)
CHECKS=("get pods" "get secrets" "create pods/exec" "patch deployments" "delete pods" "create deployments" "create rolebindings")
printf "%-10s %-22s %-6s %-6s %-6s\n" PERSONA ACTION dev qa prod
for p in developer devops auditor; do
  for c in "${CHECKS[@]}"; do
    row=""
    for e in dev qa prod; do
      r=$(kubectl auth can-i $c -n roboshop-$e --as="$p@example.com" --as-group="${WHO[$p]}" 2>/dev/null); row+=$(printf "%-6s " "$r")
    done
    printf "%-10s %-22s %s\n" "$p" "$c" "$row"
  done
done
