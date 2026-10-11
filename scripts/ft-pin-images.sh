#!/usr/bin/env bash
# fast-track kit: write the images you just built into the environments, by DIGEST (immutable), in one commit.
# Run ON THE WORKSTATION inside ~/work/roboshop-gitops after  ~/work/roboshop-app/scripts/build-push.sh all
#   scripts/ft-pin-images.sh                 -> dev qa prod  (golden setup: seed all three once)
#   scripts/ft-pin-images.sh dev             -> dev only     (normal life: then promote with scripts/promote.sh)
# Reads ~/work/roboshop-app/build/digests.txt  lines: "<svc> <sha7> <registry>/roboshop/<svc>@sha256:..."
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
DIG=${DIGESTS:-$HOME/work/roboshop-app/build/digests.txt}
ENVS=${*:-dev qa prod}
[ -s "$DIG" ] || { echo "no $DIG - run ~/work/roboshop-app/scripts/build-push.sh all first"; exit 1; }
command -v yq >/dev/null || { echo "yq missing (installed by steps/tools.sh)"; exit 1; }

ACCOUNT=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}
for e in $ENVS; do   # a fresh kit still has the account placeholder in _common.yaml
  sed -i "s/__AWS_ACCOUNT_ID__/$ACCOUNT/" "envs/$e/_common.yaml"
done

n=0; sha=""
while read -r svc sha ref; do
  [ -n "${svc:-}" ] || continue
  digest=${ref#*@}
  [[ "$digest" == sha256:* ]] || { echo "skip $svc: no digest in '$ref'"; continue; }
  for e in $ENVS; do
    f="envs/$e/$svc.yaml"; [ -f "$f" ] || { echo "skip $f (not found)"; continue; }
    T="$sha" D="$digest" yq -i '.image.tag = strenv(T) | .image.digest = strenv(D)' "$f"
    n=$((n+1))
  done
  printf '  %-10s %s  %s\n' "$svc" "$sha" "${digest:0:19}..."
done < "$DIG"

left=$(grep -l 'not-built-yet' envs/*/*.yaml 2>/dev/null | tr '\n' ' ' || true)
[ -z "$left" ] || echo "⚠️  still not pinned (not in digests.txt): $left"
git add envs
if git diff --cached --quiet; then echo "nothing changed"; exit 0; fi
git commit -q -m "deploy($(echo $ENVS | tr ' ' ',')): pin images @ ${sha} by digest ($n files)"
echo "committed $(git rev-parse --short HEAD) - publish it to GitHub; Argo CD picks it up within ~1 min (dev),"
echo "qa/prod are manual-sync: run  bash ~/work/roboshop-infra/workstation/steps/root-app.sh  (DR sync) or sync in the UI."
