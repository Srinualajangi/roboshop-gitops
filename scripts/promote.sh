#!/usr/bin/env bash
# Promote ONE service's image digest from one env to the next as ONE reviewable commit.
# usage: scripts/promote.sh <service> <from> <to>      e.g. scripts/promote.sh catalogue dev qa
set -euo pipefail
svc=${1:?usage: promote.sh <service> <from> <to>}; from=${2:?}; to=${3:?}

case "$from->$to" in
  "dev->qa"|"qa->prod") ;;
  *) echo "REFUSED: only dev->qa or qa->prod (got $from->$to). Skipping qa skips the tests that run there."; exit 1 ;;
esac

cd "$(git rev-parse --show-toplevel)"
[ -z "$(git status --porcelain)" ] || { echo "REFUSED: working tree is not clean"; exit 1; }
git checkout -q main && git pull -q --ff-only

src="envs/$from/$svc.yaml"; dst="envs/$to/$svc.yaml"
[ -f "$src" ] && [ -f "$dst" ] || { echo "REFUSED: $src or $dst missing"; exit 1; }
digest=$(yq '.image.digest' "$src"); tag=$(yq '.image.tag' "$src"); old=$(yq '.image.digest' "$dst")
[[ "$digest" == sha256:* ]] || { echo "REFUSED: $src has no image.digest"; exit 1; }
[ "$digest" != "$old" ] || { echo "Nothing to do: $to already runs $digest"; exit 0; }

# The digest must really exist in ECR (and must not have CRITICAL findings — Phase 6 adds that check).
aws ecr describe-images --repository-name "roboshop/$svc" --image-ids imageDigest="$digest" >/dev/null \
  || { echo "REFUSED: $digest not found in ECR roboshop/$svc"; exit 1; }

branch="promote-$to-$svc-$(date +%Y%m%d-%H%M%S)"
git checkout -q -b "$branch"
D="$digest" T="$tag" yq -i '.image.digest = strenv(D) | .image.tag = strenv(T)' "$dst"
changed=$(git diff --name-only | wc -l)
[ "$changed" -eq 1 ] || { echo "REFUSED: expected exactly 1 changed file, got $changed"; git checkout -q -- .; git checkout -q main; git branch -q -D "$branch"; exit 1; }

git commit -q -am "promote($to): $svc $tag" \
  -m "Promotes ${digest} from $from to $to." \
  -m "Rollback: git revert <this commit>   (previous digest: ${old})"
echo "Created $branch:"; git show --stat --oneline HEAD | head -5
echo
echo "Next: git push -u origin $branch  ->  open a PR  ->  merge  ->  argocd app sync $svc-$to"
