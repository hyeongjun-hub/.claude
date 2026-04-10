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

# rebase 중간 상태 정리
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  git rebase --abort 2>/dev/null
  echo "[$(date '+%m-%d %H:%M')] rebase abort (stale state)" >> "$LOG"
fi

# uncommitted 변경이 있으면 먼저 커밋 (이전 세션 강제 종료 대비)
git add -A
git diff --cached --quiet || git commit -m "auto-sync [$(hostname -s)] $(date '+%m-%d %H:%M')" >/dev/null 2>&1

# pull
git pull --rebase origin main --quiet 2>/dev/null || {
  git rebase --abort 2>/dev/null
  echo "[$(date '+%m-%d %H:%M')] pull conflict, aborted" >> "$LOG"
  true
}

# unpushed 커밋이 있으면 push
if [ -n "$(git log origin/main..HEAD --oneline 2>/dev/null)" ]; then
  nohup git push origin main --quiet 2>>"$LOG" &
fi
