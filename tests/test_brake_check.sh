#!/usr/bin/env bash
# Hard rule H1: the brake hook really blocks irreversible commands (exit 2)
# and lets ordinary ones through (exit 0). Runs every sample through the jq
# parser AND the grep/sed fallback parser. Also checks BRAKE_APPROVED=1.
set -u
ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HOOK="$ROOT/scripts/brake-check.sh"
[ -f "$HOOK" ] || { echo "FAIL: $HOOK missing"; exit 1; }

# JSON-encode a string without jq (handles backslash, quote, tab, newline).
json_str() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g' | awk 'BEGIN{ORS=""} NR>1{print "\\n"} {print}'
}
payload() {
  printf '{"session_id":"test","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s","description":"test"}}' "$(json_str "$1")"
}

DANGEROUS='git push origin main
git push --force origin main
git push -f
cd app && git push
FOO=1 git -C repo push origin HEAD
git reset --hard HEAD~3
git branch -D old-feature
git clean -fdx
rm -rf build/
rm -fr /tmp/x
sudo rm -r -f /var/data
find . -name "*.log" | xargs rm -rf
psql -c "DROP TABLE users;"
mysql -e "drop database prod"
sqlite3 app.db "TRUNCATE TABLE orders"
curl -X POST https://api.example.com/v1/orders -d @order.json
curl -X DELETE https://api.example.com/v1/items/42
curl --request PUT https://hooks.example.com/x
curl -d "a=1" https://forms.example.com/submit
http POST api.example.com/users name=x
echo "hello" | mail -s "Hi" someone@example.com
sendmail -t < message.txt
npm publish
pnpm publish --access public
terraform apply -auto-approve
terraform destroy
kubectl delete deployment web
aws s3 rm s3://bucket/key --recursive
aws ec2 terminate-instances --instance-ids i-123
aws dynamodb delete-table --table-name t
gcloud compute instances delete vm-1
gcloud run deploy svc --source .
vercel deploy --prod
gh pr merge 12 --squash'

SAFE='ls -la
git status
git log --oneline -5
git diff HEAD
git commit -m "prepare for git push later"
git fetch origin
git branch -d merged-branch
git reset --soft HEAD~1
rm notes.txt
rm -r empty-dir
echo "rm -rf is dangerous" > /dev/null
cat docs/BRAKES.md
grep -rn "sendmail" docs/
curl https://example.com
curl -X GET https://api.example.com/status
curl -X POST http://localhost:3000/api/test -d "{}"
curl -X DELETE http://127.0.0.1:8080/items/1
http POST :3000/users name=x
npm test
npm install
terraform plan
kubectl get pods
aws s3 ls s3://bucket
gcloud compute instances list
bash tests/run.sh'

fail=0; n=0
check() { # expected_rc mode command
  local want="$1" mode="$2" cmd="$3" got
  if [ "$mode" = "nojq" ]; then
    payload "$cmd" | BRAKE_NO_JQ=1 BRAKE_APPROVED=0 bash "$HOOK" >/dev/null 2>&1; got=$?
  else
    payload "$cmd" | BRAKE_APPROVED=0 bash "$HOOK" >/dev/null 2>&1; got=$?
  fi
  n=$((n + 1))
  if [ "$got" != "$want" ]; then
    echo "FAIL [$mode]: expected exit $want, got $got for: $cmd"; fail=$((fail + 1))
  fi
}

modes="nojq"; command -v jq >/dev/null 2>&1 && modes="jq nojq"
for mode in $modes; do
  while IFS= read -r c; do [ -n "$c" ] && check 2 "$mode" "$c"; done <<EOF_D
$DANGEROUS
EOF_D
  while IFS= read -r c; do [ -n "$c" ] && check 0 "$mode" "$c"; done <<EOF_S
$SAFE
EOF_S
done

# Block message must tell Claude how to proceed.
msg="$(payload 'git push origin main' | BRAKE_APPROVED=0 bash "$HOOK" 2>&1 >/dev/null)"
n=$((n + 1))
if ! printf '%s' "$msg" | grep -q 'BRAKE_APPROVED=1' || ! printf '%s' "$msg" | grep -qi 'explicit yes'; then
  echo "FAIL: block message doesn't explain explicit yes + BRAKE_APPROVED=1 re-run"; fail=$((fail + 1))
fi

# Approval: prefix in the command, and env var on the hook process.
n=$((n + 1))
payload 'BRAKE_APPROVED=1 git push origin main' | BRAKE_APPROVED=0 bash "$HOOK" >/dev/null 2>&1 \
  || { echo "FAIL: 'BRAKE_APPROVED=1 git push' prefix was not let through"; fail=$((fail + 1)); }
n=$((n + 1))
payload 'rm -rf build/' | BRAKE_APPROVED=1 bash "$HOOK" >/dev/null 2>&1 \
  || { echo "FAIL: BRAKE_APPROVED=1 in env did not let rm -rf through"; fail=$((fail + 1)); }
# A different var value must NOT approve.
n=$((n + 1))
payload 'BRAKE_APPROVED=yes git push' | BRAKE_APPROVED=0 bash "$HOOK" >/dev/null 2>&1; rc=$?
[ "$rc" = "2" ] || { echo "FAIL: BRAKE_APPROVED=yes (not 1) was treated as approval (exit $rc)"; fail=$((fail + 1)); }

# Non-Bash payload with no command -> allow.
n=$((n + 1))
printf '{"tool_name":"Read","tool_input":{"file_path":"x"}}' | bash "$HOOK" >/dev/null 2>&1 \
  || { echo "FAIL: payload without a command was blocked"; fail=$((fail + 1)); }

if [ $fail -gt 0 ]; then echo "$fail of $n brake checks failed"; exit 1; fi
echo "ok: $n brake checks passed (modes: $modes)"
