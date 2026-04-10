---
name: jira-edit
description: RDDP Jira 이슈를 조회하고 수정합니다.
argument-hint: "[RDDP-XXX]"
disable-model-invocation: true
---

# RDDP Jira Issue Editor

RDDP 프로젝트의 Jira 이슈를 조회하고 수정하는 스킬.

## Constants

- **cloudId**: `02341c53-1c71-47b2-b90a-4fba82691217`
- **projectKey**: `RDDP`

## 핵심 원칙: Suggest-then-Confirm

1. **각 섹션마다 추천 문구를 최소 3개 제안하고 사용자가 확인/수정한다**
   - 컨텍스트(이슈 제목, `$ARGUMENTS`, 참조 문서, 코드 등)에서 다양한 관점의 추천 문구 3개를 생성
   - `AskUserQuestion` 옵션에 추천 3개를 배치 (사용자는 "Other"로 직접 입력도 가능)
   - 추천은 각각 다른 관점/표현/상세도로 작성하여 선택지를 넓힌다
2. **추천할 근거가 없는 섹션은 빈 채로 질문한다** — 근거 없이 꾸며내지 않음
3. **사용자가 구체적으로 지시한 수정만 반영한다** — 지시하지 않은 필드/섹션은 변경하지 않음

## Flow

### Step 1: Identify Issue

- `$ARGUMENTS`에 이슈 키가 있으면 바로 조회:
  - `RDDP-123` 형태 → 그대로 사용
  - 숫자만 (`123`) → `RDDP-123`으로 변환
- `$ARGUMENTS`가 비어있으면:
  - `mcp__atlassian__searchJiraIssuesUsingJql`로 최근 이슈 10개를 검색
  - JQL: `project = RDDP ORDER BY updated DESC`
  - `fields`: `["summary", "status", "issuetype", "priority", "assignee", "updated"]`
  - `maxResults`: 10
  - 결과를 테이블로 보여주고 `AskUserQuestion`으로 선택:

```
| # | Key | 유형 | 상태 | 우선순위 | 제목 |
|---|-----|------|------|----------|------|
| 1 | RDDP-XXX | 작업 | 진행 중 | Medium | ... |
```

```
Question: "수정할 이슈를 선택하세요."
Options:
  - "1" — "RDDP-XXX: [제목]"
  - "2" — "RDDP-YYY: [제목]"
  - "3" — "RDDP-ZZZ: [제목]"
  (최대 4개, 나머지는 "Other"로 키 직접 입력)
```

- `$ARGUMENTS`에 참조 문서 URL이 있으면 함께 조회하여 컨텍스트로 활용한다.

### Step 2: Display Current Issue

`mcp__atlassian__getJiraIssue`로 이슈를 조회하여 현재 상태를 표시한다.

Output format:
```markdown
## RDDP-XXX: [제목]

- **유형**: 작업
- **상태**: 진행 중
- **우선순위**: Medium
- **담당자**: [이름]

### 설명
[현재 description 내용]
```

### Step 3: Collect Edit Request

사용자에게 수정할 내용을 질문한다.

```
Question: "어떤 내용을 수정하시겠습니까?"
Options:
  - "필드 수정" — "제목, 유형, 우선순위, 상태 등 필드를 변경합니다"
  - "설명 수정" — "Description 내용을 수정합니다"
  - "둘 다" — "필드와 설명 모두 수정합니다"
```

#### 3-A. 필드 수정

구체적으로 어떤 필드를 어떻게 바꿀지 질문한다.

#### 3-B. 설명 수정 — 빈 템플릿인 경우 (Suggest-then-Confirm)

컨텍스트(이슈 제목, `$ARGUMENTS`, 참조 문서)를 분석하여 각 섹션의 추천 문구를 생성한다.
**한 번에 최대 4개 섹션을 동시에 질문하여 빠르게 진행한다.**

##### 라운드 1: 제목 + 요약 + 배경 + 산출물

```
Question: "제목을 확인해주세요. (현재: [현재 제목])"
Options (3개 - 각각 다른 내용의 제목):
  - "유지" — "현재 제목을 그대로 사용합니다"
  - "[다른 표현의 제목 A]" — "다른 관점의 제목"
  - "[다른 표현의 제목 B]" — "또 다른 관점의 제목"
  (사용자는 Other로 직접 입력 가능)

Question: "요약(1~2줄)을 확인해주세요."
Options (3개 - 각각 다른 내용의 요약, 모두 간결하게):
  - "[요약 A]" — "관점 1"
  - "[요약 B]" — "관점 2"
  - "[요약 C]" — "관점 3"
  (사용자는 Other로 직접 입력 가능)

Question: "배경설명이 필요한가요?"
Options (3개 - 각각 다른 내용의 배경, 모두 간결하게):
  - "[배경 A]" — "관점 1"
  - "[배경 B]" — "관점 2"
  - "없음" — "배경설명 섹션을 생략합니다"
  (사용자는 Other로 직접 입력 가능)

Question: "예상 산출물 종류는?"
Options:
  - "코드" — "코드 산출물"
  - "문서" — "문서 산출물"
  - "코드 + 문서" — "둘 다"
```

##### 라운드 2: TO-BE + 작업목록 + 완료조건 + 추가섹션

```
Question: "목표 상태(TO-BE)를 확인해주세요."
Options (3개 - 각각 다른 내용의 목표, 모두 간결하게):
  - "[목표 A]" — "관점 1"
  - "[목표 B]" — "관점 2"
  - "[목표 C]" — "관점 3"
  (사용자는 Other로 직접 입력 가능)

Question: "작업 목록을 확인해주세요."
Options (3개 - 각각 다른 구성의 작업목록, 모두 간결하게):
  - "[작업목록 A]" — "구성 1"
  - "[작업목록 B]" — "구성 2"
  - "[작업목록 C]" — "구성 3"
  (사용자는 Other로 직접 입력 가능)

Question: "완료 조건을 확인해주세요."
Options (3개 - 각각 다른 내용의 완료조건, 모두 간결하게):
  - "[완료조건 A]" — "관점 1"
  - "[완료조건 B]" — "관점 2"
  - "[완료조건 C]" — "관점 3"
  (사용자는 Other로 직접 입력 가능)

Question: "추가 섹션이 필요한가요?"
Options:
  - "없음" — "이대로 진행합니다"
  - "AS-IS 추가" — "현재 상태를 기술합니다"
  - "연관 이슈 추가" — "관련 이슈 링크를 추가합니다"
  - "유입 경로 추가" — "이슈 유입 경로를 기술합니다"
```

**추천 문구 생성 규칙:**
- **최소 3개 추천**: 각 섹션마다 **다른 내용/관점**의 추천을 3개 제공
  - 모든 추천은 간결하게 작성 (1~3줄 bullet-point)
  - 상세도를 다르게 하는 게 아니라, **내용 자체가 다른 선택지**를 제공
  - 예: 요약 → "CI 워크플로우 구현" / "보호 파일 변경 감지 자동화" / "머지 전 사전 검증 파이프라인 구축"
- 컨텍스트(참조 문서, 코드, $ARGUMENTS, 이슈 제목)에서 근거를 찾을 수 있으면 → 3개 추천 문구 제안
- 근거가 부족하면 → 가능한 만큼 추천하되 최소 2개 이상 제공
- 추천 문구는 RDDP 스타일(간결한 bullet-point, 1~3줄)로 작성
- `AskUserQuestion` 옵션은 최대 4개이므로, 추천 3개 + "없음"(해당 시) 또는 추천 3개만 배치 (Other는 자동 제공됨)

#### 3-C. 설명 수정 — 기존 내용이 있는 경우

사용자에게 **구체적으로 어떤 부분을 수정할지** 질문한다.
사용자가 지시한 부분만 수정하고, 나머지는 그대로 유지한다.

### Step 4: Preview & Confirm

수정 내용을 정리하여 마크다운으로 보여주고 확인을 요청한다.

```
Question: "수정 내용을 확인해주세요."
Options:
  - "확인, 수정 적용" — "수정사항을 Jira에 반영합니다"
  - "수정 변경" — "수정 내용을 다시 조정합니다"
```

### Step 5: Apply Edit

`mcp__atlassian__editJiraIssue`를 호출하여 수정을 적용한다.

Parameters:
- `cloudId`: `02341c53-1c71-47b2-b90a-4fba82691217`
- `issueIdOrKey`: 이슈 키
- `fields`: 수정할 필드 객체

**필드 수정 예시:**
- 제목: `{"summary": "새 제목"}`
- 우선순위: `{"priority": {"name": "High"}}`
- 레이블: `{"labels": ["label1", "label2"]}`

**Description 수정 시:**
- 기존 설명 전체를 가져와서 요청된 부분만 수정
- 전체 description을 교체: `{"description": "수정된 전체 Markdown"}`
- RDDP 작성 스타일 유지 (간결한 bullet-point, 빈 섹션 생략, 한국어)
- Markdown 문자열로 먼저 시도
- 실패 시 에러 메시지를 사용자에게 안내

**상태 변경 시:**
- 상태는 `editJiraIssue`로 변경할 수 없음
- `mcp__atlassian__getTransitionsForJiraIssue`로 가능한 전환 목록을 조회
- `mcp__atlassian__transitionJiraIssue`로 상태 전환 실행

### Step 6: Confirm Result

`mcp__atlassian__getJiraIssue`로 수정된 이슈를 재조회하여 결과를 표시한다.

Output format:
```
이슈가 수정되었습니다.

- **Key**: RDDP-XXX
- **URL**: https://vntgcorp.atlassian.net/browse/RDDP-XXX
- **변경사항**: [변경된 필드 목록]
```
