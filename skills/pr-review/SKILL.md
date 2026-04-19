---
name: pr-review
description: GitHub PR URL을 받아 VNTG RND-INFRA 레포의 CLAUDE.md 컨텍스트를 활용해 자동 코드 리뷰를 수행하고, /tmp/pr[번호].md 에 리뷰 결과를 저장한 뒤 md2html 스킬로 HTML까지 생성한다. 사용자가 "/pr-review <URL>", "이 PR 리뷰해줘", "PR 자동 리뷰", "이 PR 검토하고 HTML로" 같은 표현으로 PR URL (github.com/*/pull/* 형태)을 공유하면 반드시 이 스킬을 호출하라. 단순히 PR 내용을 묻는 질문 (예: "이 PR 뭐하는거야?") 은 대상이 아니다.
---

# pr-review — VNTG RND-INFRA PR 자동 리뷰

GitHub PR URL을 받아 **VNTG R&D 인프라 팀의 프로젝트 컨벤션을 기반으로** 리뷰를 생성하고, 마크다운 + HTML 두 가지 형태로 산출한다.

## 언제 쓰는가

사용자가 다음 중 하나라도 하면 이 스킬을 호출한다.

- `github.com/VntgCorp/RND-INFRA/pull/<번호>` 같은 URL을 공유하며 리뷰 요청
- `/pr-review <URL>` 명시적 호출
- "이 PR 리뷰해줘", "PR 자동 리뷰해서 html로 보여줘" 같은 자연어 요청

## 입력과 산출물

**입력**: GitHub PR URL (`https://github.com/<owner>/<repo>/pull/<N>`)

**산출물**:
1. `/tmp/pr<N>.md` — 리뷰 마크다운
2. `/tmp/pr<N>.html` — md2html 스킬로 변환한 신문 스타일 HTML

## 워크플로우

### 1단계 — 컨텍스트 로드

VNTG RND-INFRA 레포의 프로젝트 규약/네트워크 구조/도구 역할을 리뷰 기준으로 삼는다.

```bash
cat /Users/johyeongjun/VntgCorp/RND-INFRA/.claude/CLAUDE.md
```

CLAUDE.md 내용은 리뷰 근거로 **인용**한다. 예: "이 변경은 CLAUDE.md의 `도구별 역할 (ADR-009)` 규칙에 따라 Terraform 레이어에서 처리하는 것이 맞음" 같은 식으로 레포 컨벤션을 근거로 판단한다.

### 2단계 — PR 정보 수집

`gh` CLI로 PR 메타/본문/diff/기존 코멘트를 수집한다. URL에서 PR 번호를 추출해 `<N>` 으로 사용.

```bash
# PR 메타 + 본문
gh pr view <URL> --json title,author,state,baseRefName,headRefName,additions,deletions,body,labels

# 변경 파일 목록
gh pr diff <URL> --name-only

# 전체 diff (크면 저장 후 offset 읽기)
gh pr diff <URL>

# 기존 리뷰 코멘트 (Gemini/동료 지적사항 포함)
gh api repos/<owner>/<repo>/pulls/<N>/comments --jq '.[] | {user: .user.login, path: .path, body: .body}'
```

diff가 클 경우 파일 단위로 나눠 읽는다. 이미 남아있는 동료/봇 리뷰 코멘트는 **중복 지적 방지**를 위해 반드시 확인하고, 이미 반영된 지적은 다시 언급하지 않는다.

### 3단계 — 리뷰 작성

아래 구조로 `/tmp/pr<N>.md` 를 작성한다. 섹션 순서와 제목은 그대로 유지한다 — md2html 템플릿의 Fact Strip / Section 번호 매핑이 이 구조를 전제로 한다.

```markdown
# PR #<N> 리뷰: <PR 제목>

> **author**: <저자> | **base**: <base> ← **head**: <head> | **+<additions>/-<deletions>** | 파일 <수>개

## 개요

PR이 무엇을 바꾸고 왜 바꾸는지 2~3문장 요약. CLAUDE.md의 어느 레이어/도구에 영향을 주는지 명시.

## 강점

- 잘 된 부분을 3~5개 bullet로. 단순 칭찬이 아니라 **왜 좋은 선택인지 근거**를 함께 쓴다.

## 지적 사항

각 지적은 심각도 태그(High/Medium/Low)를 붙이고, **현재 코드 → 문제 → 권장 수정**의 순서로 서술한다.

### 1. (High) <제목>

현재 코드/설정 인용 (code block 권장)

문제: ...

권장: ...

### 2. (Medium) ...

### 3. (Low) ...

## VNTG 컨벤션 체크

| 항목 | 상태 | 근거 |
|---|---|---|
| 네이밍 규약 | OK / 위반 | CLAUDE.md의 어느 규칙 |
| 도구 레이어 (ADR-009) | OK / 위반 | ... |
| 네트워크 규칙 (Shared VPC / PSC / Pod CIDR) | OK / 해당없음 | ... |
| ADR/RDDP 참조 | 필요 / 있음 / 없음 | ... |

## 리스크

- 런타임 영향, 롤백 가능성, 블라스트 반경을 간략히. 문서 PR이면 "문서 변경만, 런타임 영향 없음"이라고 명시.

## 결론

**Approve / Request changes / Comment** 중 하나를 명시하고, merge 전 반드시 해결되어야 할 항목(blocking)과 nice-to-have를 구분한다.
```

### 4단계 — 파일 저장

```bash
# 리뷰 마크다운 저장 (숫자만 추출해서 pr<N>.md)
# 예: https://github.com/VntgCorp/RND-INFRA/pull/99 → /tmp/pr99.md
```

마크다운은 Write 툴로 `/tmp/pr<N>.md` 에 쓴다. 오버라이트해도 된다 (같은 PR을 재리뷰할 수도 있음).

### 5단계 — HTML 변환

md2html 스킬을 호출하여 HTML 생성.

```
Skill: md2html
args: /tmp/pr<N>.md /tmp/pr<N>.html
```

HTML 생성이 끝나면 사용자에게 두 파일 경로를 모두 알려주고, HTML을 열고 싶으면 `open /tmp/pr<N>.html` 로 열 수 있음을 안내한다.

## 리뷰 작성 원칙

**왜를 쓴다.** "이 부분이 이상합니다"가 아니라 "CLAUDE.md의 X 규칙에 따르면 ~여야 하는데 현재 ~이므로 Y 문제가 발생할 수 있음"처럼 **근거 + 영향**을 명시한다. VNTG 컨벤션 위반은 CLAUDE.md의 해당 섹션을 인용한다.

**중복 지적 회피.** 이미 Gemini-code-assist나 동료 리뷰어가 남긴 지적 중 저자가 반영한 항목은 "기존 지적 반영 확인" 정도로만 짧게 언급하고, 중복해서 다시 제기하지 않는다.

**심각도 태그.**
- **High**: merge 전 반드시 해결. forces replacement, 보안 사고, 서비스 단절, 규약 정면 위반.
- **Medium**: 반영 권장이나 blocking은 아님. 유지보수성/일관성/관측성 개선.
- **Low**: nice-to-have. 오탈자, 주석, 사소한 리팩토링 기회.

**심각도가 없으면 빼라.** 지적할 게 없는데 억지로 채우지 않는다. "강점" 섹션이 더 길어도 괜찮다.

**결론은 반드시 명시.** Approve / Request changes / Comment 중 하나. 애매하게 끝내지 않는다.

## 실패 케이스 대응

- `gh` 인증 실패: 사용자에게 `gh auth login` 안내
- PR URL이 private repo이고 접근 불가: 에러 메시지와 함께 중단
- diff가 너무 커서 컨텍스트 초과: 주요 파일만 샘플링하고 "전체 파일은 리뷰하지 못했음" 을 리뷰 상단에 명시
- PR이 draft/closed 상태: 상태를 리뷰 상단에 표기하고 계속 진행

## 관련 스킬

- `review` (내장): 단일 PR 일반 리뷰. 이 스킬은 그걸 VNTG 컨벤션 + md2html 자동화로 확장한 버전.
- `md2html`: 마지막 단계의 HTML 변환. 이 스킬은 반드시 md2html 스킬을 호출해 HTML까지 만든다.
