---
name: md2html
description: Markdown 파일을 "impeccable" 신문/에디토리얼 스타일 단일 HTML 파일로 변환한다. 사용자가 /md2html [경로] 를 호출하거나, "이 md를 impeccable 스타일로", "neo-editorial HTML로 변환" 등으로 요청할 때 사용한다.
---

# md2html — Impeccable Editorial Template

Markdown 문서 한 개를 뉴스페이퍼/에디토리얼 스타일의 단일 HTML 파일로 변환한다.
템플릿의 핵심 철학은 "카드 없는 계층 — 구분선과 여백, 폰트 계단으로 계층을 만든다"이다.

## 호출

```
/md2html <md 파일 경로> [출력 경로]
```

출력 경로를 생략하면 같은 디렉토리에 `<원본이름>.html` 로 저장한다.

## 변환 원칙

**의미 재구성 변환이다.** 단순 md→html 변환이 아니라, md 내용을 해석해 템플릿의 각 슬롯(Lead / Fact Strip / Section / Pullquote / Table / Code)에 **의도적으로 배치**한다.

1. **템플릿 원본 로드**: `~/.claude/skills/md2html/template.html` 을 읽는다. 이 파일의 `<style>` 블록과 전체 구조를 그대로 유지하는 것이 최우선이다. CSS를 수정하지 않는다.
2. **폰트 링크 유지**: Playfair Display / Inter / JetBrains Mono Google Fonts 링크를 그대로 둔다.
3. **placeholder 치환**: `{{TITLE}}`, `{{HEADING}}`, `{{HEADING_EM}}`, `{{DESCRIPTION}}`, `{{DATE}}`, `{{BADGE}}` 를 실제 값으로 치환한다.
4. **섹션 자동 번호 부여**: `01`, `02`, `03` … — 원본 md의 H2 순서대로 증가.
5. **파비콘 경로 제거**: `href="/gemini_html/favicon.svg"` 줄은 삭제한다 (로컬에서 404 난다).

## Markdown → 템플릿 슬롯 매핑

| Markdown | 템플릿 위치 | 비고 |
|---|---|---|
| 첫 H1 (`# 제목`) | `.lead h1` | 제목을 두 부분으로 나눌 수 있으면 뒷부분을 `<em>` 으로 (`HEADING_EM`). 콜론/대시 기준. |
| H1 바로 다음 문단 | `.lead-deck` | description. 1-3문장이 이상적. 길면 요약. |
| H2 (`## 섹션`) | `.doc-section` + `section-heading` | 각 H2마다 새 섹션. 번호 자동. |
| H2 직후 문단 | `.section-lead` | 섹션 서론 1문장. |
| H3 (`### 항목`) + 문단 | `.two-col > .col-item` 의 title/body | 같은 섹션 안 H3가 2개면 two-col, 1개면 단일 col. 3개 이상이면 two-col 여러 줄 or 목록 변환. |
| Blockquote (`>`) | `.pullquote` | 마지막 줄이 `— 출처` 형태면 `<cite>` 로 분리. |
| `\|...\|` 표 | `.table-wrap > table` | 그대로 변환. |
| 펜스 코드 블록 | `pre.code` | 언어 태그는 무시하고 검정 배경 그대로. |
| 인라인 코드 | `code.inline` | |
| 문서 내 "숫자 + 레이블" 형태 불릿 리스트 | `.facts` (Fact Strip) | 예: `- 99.9% 가용성`, `- 3ms 지연` 처럼 수치 지표 4개 내외가 연속으로 있으면 Fact Strip 으로 승격. |
| 일반 `-` / `*` 불릿 | `<ul>` 로 기본 변환 | 단, Fact Strip 승격 케이스 제외 |

## Lead 영역 상세 규칙

- `lead-eyebrow`: md 문서 제목 톤에 맞는 짧은 배지 (예: "ADR", "RFC", "TECHNICAL NOTE", "DESIGN"). md 파일 경로/파일명에서 유추. 유추 불가 시 "DOCUMENT".
- `masthead-name`: 프로젝트/문서군 이름. md 파일 상위 디렉토리명 또는 문서 시리즈명.
- `DATE`: 문서 내 날짜가 있으면 사용, 없으면 오늘 날짜 (YYYY-MM-DD).
- `BADGE`: eyebrow와 동일하게.
- `lead-byline`: 작성자/출처가 md 프론트매터나 문서 내에 있으면 사용, 없으면 기본값 ("작성일: DATE", "출처: 공식 문서 기반").

## Fact Strip 판단

md 문서 초반(H1 다음 ~ 첫 H2 전) 또는 중간에 다음 패턴이 있으면 Fact Strip 으로 추출한다:
- 3-4개의 숫자 중심 지표가 연속
- 예: `- **99.9%** 가용성`, `- **3ms** p99 지연` 등

Fact Strip은 최대 4개 항목. 4개 초과면 상위 4개만 선택.

## H3가 많은 섹션 처리

한 H2 섹션 안에 H3가 3개 이상이면:
- 2개씩 묶어서 `.two-col` 을 여러 줄 스택, **또는**
- 내용이 짧으면 표(`table`) 로 재구성

판단은 내용 밀도 기준. 각 H3 본문이 100자 이하면 표, 그 이상이면 two-col 스택.

## 출력 후 동작

1. HTML 파일 저장 완료를 사용자에게 알린다 (파일 경로만).
2. `open <파일>` 명령을 **제안만** 하고, 직접 실행하지 않는다 (사용자가 원할 때만).
3. 템플릿 CSS는 자급자족(Google Fonts 제외). 별도 에셋 없이 단일 파일로 완결된다.

## 주의

- 템플릿의 `<style>` 블록은 절대 수정하지 않는다. 슬롯 구조만 채운다.
- 보라색/그라디언트/이모지 강조를 추가하지 않는다 (템플릿 철학에 위배).
- 원본 md에 없는 내용을 창작하지 않는다. 재구성은 허용, 날조는 금지.
- placeholder가 한 번도 치환되지 않은 채 결과가 나오는 경우는 실패로 간주하고 재확인한다.
