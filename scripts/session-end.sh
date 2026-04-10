#!/bin/bash
cd ~/.claude
LOG=~/.claude/.sync.log

# lock 파일 대기 (최대 6초)
for i in 1 2 3; do
  [ ! -f .git/index.lock ] && break
  sleep 2
done
if [ -f .git/index.lock ]; then
  echo "[$(date '+%m-%d %H:%M')] index.lock still exists, skipping" >> "$LOG"
  exit 0
fi

git add -A

# 변경사항 있으면 커밋 (hostname + timestamp)
git diff --cached --quiet || git commit -m "auto-sync [$(hostname -s)] $(date '+%m-%d %H:%M')" >/dev/null 2>&1

# unpushed 커밋이 있으면 백그라운드 push
if [ -n "$(git log origin/main..HEAD --oneline 2>/dev/null)" ]; then
  nohup git push origin main --quiet 2>>"$LOG" &
fi
