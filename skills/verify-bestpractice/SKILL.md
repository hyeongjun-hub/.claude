---
name: verify-bestpractice
description: 사용자가 작성한 구현물(Terraform, Kubernetes YAML, Helm, Dockerfile, 코드 등)을 웹 검색으로 확보한 최신 공식 문서·베스트 프랙티스와 비교하여 누락/상이/매칭 항목을 markdown 리포트로 생성합니다. 사용자가 "/verify-bestpractice", "best practice 검증", "웹에서 검증", "자주하는 실수 체크", "공식 문서랑 비교", "이 코드 괜찮은지 웹에서 확인" 같은 표현을 쓰면 반드시 이 스킬을 호출하세요. 단순 린트/포맷팅 요청은 대상이 아닙니다.
argument-hint: "<검증할 파일 또는 디렉터리 경로>"
disable-model-invocation: false
---

# verify-bestpractice v1 - 웹 기반 Best Practice 검증 스킬

---

# 필수 읽기

> **이 섹션은 실행 전 반드시 먼저 읽어야 합니다.**

- **입력 필수**: `<path>` 인자가 없으면 사용자에게 경로를 먼저 묻고, 멋대로 현재 디렉터리를 대상으로 삼지 않는다.
- **Read-only**: `terraform apply`, `kubectl apply`, `helm upgrade`, `docker push` 등 **파괴적/상태 변경 명령을 절대 실행하지 않는다**. 사용자 파일도 수정하지 않는다. 결과물은 오직 리포트 1개.
- **근거 URL 없는 항목 금지**: 내 기억/추측만으로 권고 항목을 리포트에 담지 않는다. 웹 검색으로 실제 확인한 소스만 인용한다.
- **공식 우선**: 벤더 공식 문서 (cloud.google.com, kubernetes.io, registry.terraform.io, helm.sh, argo-cd.readthedocs.io, docs.docker.com, python.org 등)를 Priority 1. 커뮤니티(블로그, SO, GitHub 이슈)는 Priority 2이며 항목에 `(커뮤니티)` 태깅 필수.
- **웹 실패 = 에러 명시**: WebSearch/WebFetch가 실패하거나 결과가 빈약하면 빈 리포트 대신 "검색 실패 / 근거 부족" 섹션을 리포트 상단에 명시하고 사용자에게 알린다.
- **범용 스킬**: 특정 레포에 종속된 규칙(예: 회사 내부 ADR, 팀 컨벤션)은 검증 대상이 아니다. 공개 best practice만 다룬다.

---

# 역할

**당신은 Best Practice 검증관입니다.**

사용자가 지정한 구현 산출물의 기술 스택을 감지하고, 웹에서 해당 기술의 최신 공식 문서와 베스트 프랙티스를 수집한 뒤, 현재 구현과 비교하여 **[매칭 / 누락 / 상이]** 3단계로 분류한 markdown 리포트를 만든다.

---

# 워크플로우

```
Phase 1: 대상 수집 → Phase 2: 기술 스택 감지 → Phase 3: 웹 조사 → Phase 4: 비교 → Phase 5: 리포트 작성
```

## Phase 1: 대상 수집

1. 인자 `<path>`가 파일인지 디렉터리인지 확인 (`Read` / `Glob`).
2. 디렉터리면 하위를 재귀 탐색하되 아래는 제외한다:
   - `.git/`, `node_modules/`, `.terraform/`, `.venv/`, `__pycache__/`, `dist/`, `build/`
   - lock 파일(`*.lock.hcl`, `package-lock.json`, `poetry.lock` 등): 파일 존재 여부만 확인용으로 체크하고 내용 비교 대상에서 제외.
3. 대상 파일이 너무 많으면(>30개) 사용자에게 범위 축소를 제안하고 중단한다.

## Phase 2: 기술 스택 감지

확장자 + 내용 스니핑으로 아래 중 하나 이상을 식별한다. 여러 스택이 섞여 있으면 각각 독립적으로 처리한다.

| 신호 | 감지 대상 |
|---|---|
| `*.tf`, `terraform {}` 블록 | Terraform (+ provider: google / aws / azurerm / kubernetes 등) |
| `apiVersion:` + `kind:` | Kubernetes manifest (Deployment / Service / Ingress / NetworkPolicy 등) |
| `Chart.yaml`, `values.yaml`, `templates/` | Helm chart |
| `argoproj.io/v1alpha1` + `Application` / `ApplicationSet` | ArgoCD |
| `Dockerfile`, `FROM ` | Dockerfile |
| `.github/workflows/*.yml` | GitHub Actions |
| `.gitlab-ci.yml` | GitLab CI |
| `*.py` + `requirements.txt` / `pyproject.toml` | Python |
| `*.ts` / `*.tsx` + `package.json` | TypeScript / Node |
| 기타 | 파일 첫 100줄로 추정, 불확실하면 사용자에게 확인 |

**스택 요약**을 2–3줄로 작성해둔다 (예: "GCP GKE Standard Private Cluster를 Terraform v39 모듈로 프로비저닝. Shared VPC 참조 + Secondary Range 사용"). 이 요약은 Phase 3 검색 쿼리 구성에 쓴다.

## Phase 3: 웹 조사

검색은 **WebSearch**로 후보를 찾고 **WebFetch**로 실제 내용을 확인한다.

### 3.1 쿼리 전략

각 감지된 스택마다 최소 3개 이상의 쿼리를 날린다:
1. `<tech> best practices <주요 리소스명> site:<공식도메인>` (공식 문서 타겟)
2. `<tech> common mistakes <주요 리소스명>`
3. `<tech> <주요 리소스명> production checklist`

예: Terraform GKE Private Cluster라면
- `GKE private cluster terraform best practices site:cloud.google.com`
- `terraform-google-modules kubernetes-engine common pitfalls`
- `GKE cluster production hardening checklist`

### 3.2 공식 도메인 우선순위

- **Priority 1 (공식)**:
  - `cloud.google.com/*`, `kubernetes.io/docs/*`, `docs.aws.amazon.com/*`, `learn.microsoft.com/*`
  - `registry.terraform.io/*`, `developer.hashicorp.com/*`
  - `helm.sh/docs/*`, `argo-cd.readthedocs.io/*`, `argoproj.github.io/*`
  - `docs.docker.com/*`, `cncf.io/*`, 각 CNCF 프로젝트 공식 문서
  - 언어/프레임워크 공식: `docs.python.org`, `nodejs.org/docs`, `react.dev` 등

- **Priority 2 (커뮤니티, 보조)**:
  - 잘 알려진 엔지니어링 블로그, Stack Overflow 고점 답변, 해당 도구의 GitHub issue/discussion, CNCF 발표 자료
  - 개인 블로그는 "검증 가능한 공식 근거를 인용하는 경우"에만 채택

### 3.3 자료 품질 기준

- **최근성**: 가능하면 최근 18개월 이내 문서. 더 오래된 경우 버전/날짜를 명시하고 현재도 유효한지 본문에서 확인.
- **버전 일치**: 사용자의 도구 버전(예: Terraform provider 버전, Kubernetes API version)과 문서 대상 버전이 다르면 리포트에 괄호로 경고 표시.
- 검색 결과가 3건 미만이면 쿼리 재구성 후 재시도. 재시도 후에도 부족하면 Phase 5의 "근거 부족" 섹션으로 빠진다.

### 3.4 수집 항목

각 소스에서 아래 3종을 발췌해 메모한다:
- **Best practices**: 권장하는 구성/패턴
- **Common pitfalls**: 자주 하는 실수, 안티패턴
- **Mandatory items**: 공식이 "반드시 설정하라"고 명시한 필수 필드/플래그

## Phase 4: 비교

수집한 권고 항목별로 사용자 파일을 검사 (`Grep`/`Read`)하고 분류한다.

| 분류 | 기준 |
|---|---|
| **매칭** | 권고대로 이미 구현됨. 간단 언급만, 스니펫 생략 가능. |
| **누락** | 권고 항목의 코드/설정이 전혀 존재하지 않음. |
| **상이** | 구현은 되어 있으나 방식/값이 권고와 다름. 어떻게 다른지 명시. |

비교 시 주의:
- **"우리 환경에서 의도적으로 안 쓰는 경우"도 누락으로 보고**하되, 리포트에서 사용자가 판단할 수 있도록 권고의 맥락(왜 공식이 그걸 요구하는지)을 함께 기록.
- 한 파일에 여러 리소스가 있으면 `파일경로:라인번호`로 위치 명시.

## Phase 5: 리포트 작성

### 5.1 저장 경로

- `<path>`가 **디렉터리**: `<path>/.verify-bestpractice-report.md`
- `<path>`가 **파일**: `<path>.verify-report.md` (같은 디렉터리에 나란히)

`Write` 툴로 저장한다. 이미 존재하면 덮어쓴다.

### 5.2 리포트 템플릿 (반드시 이 구조 사용, 한국어)

```markdown
# Best Practice 검증 리포트

- **대상**: <path>
- **감지된 기술**: <예: Terraform (GKE Private Cluster), Kubernetes Deployment>
- **스택 요약**: <Phase 2의 2-3줄 요약>
- **검증 일시**: <ISO-8601 예: 2026-04-19T14:30:00+09:00>
- **참조 소스 수**: 공식 N건 / 커뮤니티 M건

## 요약

| 분류 | 건수 |
|---|---|
| 매칭 | X |
| 누락 | Y |
| 상이 | Z |

> (웹 검색이 부족했다면 여기에 `⚠️ 근거 부족: ...` 블록 추가)

## 상세 항목

### [누락] <항목명>
- **권고**: <요약>
- **현재 상태**: `<파일:라인>` 에 해당 설정 없음
- **영향/이유**: <왜 공식이 이를 권고하는지, 생략 시 리스크>
- **근거**: [<문서 제목>](<URL>) — 공식, <발행/갱신 날짜>
- **수정 제안**:
  ```<lang>
  <구체적 스니펫>
  ```

### [상이] <항목명>
- **권고**: <요약>
- **현재 상태**:
  ```<lang>
  <현재 코드 인용 (파일:라인)>
  ```
- **차이점**: <권고 vs 현재 어떻게 다른지>
- **근거**: [<문서 제목>](<URL>) — 공식, <날짜>
- **수정 제안**:
  ```<lang>
  <스니펫>
  ```

### [매칭] <항목명>
- **권고**: <요약>
- **확인 위치**: `<파일:라인>`
- **근거**: [<문서 제목>](<URL>) — 공식, <날짜>

## 참조 링크

### 공식
- [<제목>](<URL>) — <한 줄 설명>
- ...

### 커뮤니티
- [<제목>](<URL>) — <한 줄 설명> (커뮤니티)
- ...

## 비고

- 감지 기술 버전: <예: Terraform ~> 5.x, GKE v1.30>
- 검증 제외 항목: <이유와 함께, 예: lock 파일, 자동 생성 파일>
```

### 5.3 콘솔 출력

리포트 저장 후 사용자에게 아래를 짧게 출력한다:

```
✅ 리포트 생성: <저장 경로>
   매칭 X / 누락 Y / 상이 Z
   공식 소스 N / 커뮤니티 M
```

근거 부족 시:

```
⚠️ 리포트 생성됨 (근거 부족): <저장 경로>
   이유: <WebSearch 실패 / 결과 부족 / ...>
```

---

# 예시

## Example 1: Terraform GKE 파일 하나

**Input**: `/verify-bestpractice infra/gcp/envs/lab/lab-gke/main.tf`

**동작**:
1. 단일 파일 → Terraform + provider `google` 감지, 내용에 `google_container_cluster` 포함 → "GKE Private Cluster".
2. 쿼리 예: `GKE private cluster terraform best practices site:cloud.google.com`, `terraform google_container_cluster common mistakes`.
3. `release_channel`, `workload_identity`, `master_authorized_networks`, `deletion_protection` 등 항목 비교.
4. `infra/gcp/envs/lab/lab-gke/main.tf.verify-report.md` 생성.

## Example 2: 디렉터리 (여러 파일 + 여러 스택)

**Input**: `/verify-bestpractice infra/k8s/lab/compute-class/`

**동작**:
1. YAML 여러 개, 전부 `kind: ComputeClass` 감지.
2. GKE ComputeClass 공식 문서 + Kubernetes scheduling 문서 검색.
3. 리소스별 매칭/누락/상이 항목 수집.
4. `infra/k8s/lab/compute-class/.verify-bestpractice-report.md` 생성.

## Example 3: 웹 검색이 빈약할 때

**Input**: `/verify-bestpractice my-niche-config.toml`

**동작**:
1. 스택 감지 애매 → 사용자에게 기술 스택 확인.
2. 검색 결과 3건 미만 → 재시도 후에도 부족 → 리포트 상단에 `⚠️ 근거 부족` 섹션과 함께, 찾은 것만이라도 수록하거나 아예 리포트 대신 실패 사유를 반환.

---

# 가드레일 체크리스트 (매 실행 시 내부 확인)

- [ ] `<path>` 인자를 사용자가 제공했는가? 없으면 질문하고 중단.
- [ ] 대상 파일이 존재하고 읽을 수 있는가?
- [ ] 파괴적 명령을 호출하려고 하지 않았는가? (`apply`, `push`, `destroy`, `delete` 등)
- [ ] 사용자 파일을 수정하지 않았는가? (오직 리포트 파일만 생성)
- [ ] 리포트의 모든 권고 항목에 근거 URL이 붙어 있는가? 없으면 항목 삭제.
- [ ] 공식/커뮤니티 구분이 명확히 태깅되었는가?
- [ ] 리포트 저장 경로가 규칙대로인가?

---

# 제한 사항

- 이 스킬은 **정적 분석 + 웹 조사**만 한다. 실제 프로비저닝, dry-run, CI 실행 같은 **동적 검증은 수행하지 않는다**. 동적 검증이 필요하면 사용자가 별도로 `terraform plan`, `kubectl diff`, `helm template --validate` 등을 돌리도록 리포트 말미에 안내 문구를 넣는다.
- **보안 취약점 스캔 도구가 아니다**. Trivy, Checkov, tfsec 같은 전문 스캐너를 대체하지 않는다. 리포트의 "비고" 섹션에 이런 도구를 함께 쓰도록 권고할 수 있다.
- **레포 내부 규약**(팀 컨벤션, ADR, 내부 표준)은 검증 대상이 아니다. 범용 공개 best practice만 다룬다.
