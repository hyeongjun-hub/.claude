---
name: curriculum
description: This skill should be used when the user asks to create a learning curriculum, study plan, or course content for a technology or tool (e.g., "/curriculum Kubernetes", "/curriculum ArgoCD", "커리큘럼 만들어줘", "학습 계획 만들어줘"). Generates comprehensive HTML-based learning curricula with modules, quizzes, capstone projects, and architecture diagrams.
version: 1.0.0
---

# 학습 커리큘럼 생성 스킬

사용자가 지정한 기술에 대한 포괄적인 학습 커리큘럼을 생성합니다.

## 사용법

```
/curriculum [기술명]
```

예시: `/curriculum Kubernetes`, `/curriculum ArgoCD`, `/curriculum Ansible`

## 실행 단계

### 1단계: 개요 생성
초급부터 고급까지 5-7개 모듈로 구성된 학습 개요를 생성합니다.

### 2단계: 각 모듈 콘텐츠 생성
각 모듈에 대해 다음을 생성합니다:
- **개념 설명**: 핵심 개념과 이론
- **실습 연습**: 직접 해볼 수 있는 예제와 실습
- **일반적인 실수**: 초보자가 자주 하는 실수와 해결 방법
- **퀴즈 질문**: 학습 내용 확인을 위한 인터랙티브 퀴즈 (아래 퀴즈 구현 가이드 참고)

### 3단계: 캡스톤 프로젝트 생성
모든 모듈을 통합하는 종합 프로젝트를 설계합니다:
- 프로젝트 요구사항
- 단계별 구현 가이드
- 예상 결과물
- 평가 기준

### 4단계: 보조 자료 생성
- **아키텍처 다이어그램**: CSS(flexbox/grid + border + ::before/::after 화살표)로 시각화. ASCII/Mermaid 사용 금지. 박스, 화살표, 흐름을 순수 HTML+CSS로 구현하여 시각적으로 명확하게 표현할 것.
- **파일 구조 다이어그램**: 디렉토리/파일 트리도 CSS(들여쓰기 + border-left + ::before 커넥터)로 구현. `<pre>` 텍스트 트리 사용 금지.
- **빠른 참조 치트시트**: 핵심 명령어와 개념 요약

## 출력 구조

```
curriculum/[기술명]/
├── manifest.json           # 모든 콘텐츠 목록
├── index.html              # 메인 페이지 (네비게이션)
├── overview.html           # 커리큘럼 개요
├── modules/
│   ├── 01-introduction/
│   │   ├── concept.html    # 개념 설명
│   │   ├── practice.html   # 실습 연습
│   │   ├── mistakes.html   # 일반적인 실수
│   │   └── quiz.html       # 퀴즈
│   ├── 02-.../
│   └── ...
├── capstone/
│   └── project.html        # 캡스톤 프로젝트
├── resources/
│   ├── architecture.html   # 아키텍처 다이어그램
│   └── cheatsheet.html     # 빠른 참조 치트시트
└── styles.css              # 공통 스타일
```

## 완료 후 작업

1. 포트가 사용 가능한지 확인: `lsof -i :8080`
2. 로컬 서버 시작: `python3 -m http.server 8080 -d curriculum/[기술명]`
3. curl로 서버 확인: `curl -s http://localhost:8080 | head`
4. 브라우저에서 열기

## 콘텐츠 가이드라인

- 모든 콘텐츠는 한글로 작성
- 실용적이고 실무에서 바로 적용 가능한 예제 사용
- 단계별로 난이도 증가
- 각 모듈은 독립적으로 학습 가능하도록 구성
- HTML은 반응형 디자인으로 모바일에서도 읽기 좋게
- 실습 환경은 Docker Desktop(Kubernetes 활성화) 또는 minikube를 기본으로 구성. Kubernetes 관련 실습이 포함된 모듈에서는 로컬 K8s 클러스터 기반의 hands-on 예제를 제공할 것.

## 퀴즈 구현 가이드

퀴즈는 단순 정답 공개가 아닌, **선택지를 클릭하면 정답/오답 피드백**이 나오는 인터랙티브 방식으로 구현한다.

### 필수 동작
1. 각 선택지는 클릭 가능한 버튼/라디오 형태
2. **정답 클릭 시**: 선택지가 초록색으로 변하고, 해설이 표시됨
3. **오답 클릭 시**: 선택지가 빨간색으로 변하고, 정답이 초록색으로 하이라이트되며, 해설이 표시됨
4. 한번 선택하면 해당 문제는 재선택 불가 (중복 클릭 방지)
5. 퀴즈 하단에 **총 점수 표시** (예: "5문제 중 3문제 정답")

### 참고 HTML/JS 구조

```html
<div class="quiz-item" id="q1">
  <h4>Q1. 질문 내용</h4>
  <div class="quiz-options">
    <button class="quiz-option" onclick="selectAnswer('q1', this, false)">A. 오답 보기</button>
    <button class="quiz-option" onclick="selectAnswer('q1', this, true)">B. 정답 보기</button>
    <button class="quiz-option" onclick="selectAnswer('q1', this, false)">C. 오답 보기</button>
    <button class="quiz-option" onclick="selectAnswer('q1', this, false)">D. 오답 보기</button>
  </div>
  <div class="quiz-explanation" id="q1-exp">해설 내용</div>
</div>

<div id="quiz-score" class="quiz-score"></div>

<script>
let totalQuestions = 0;
let correctCount = 0;
let answeredCount = 0;

function selectAnswer(qId, btn, isCorrect) {
  var q = document.getElementById(qId);
  if (q.classList.contains('answered')) return;
  q.classList.add('answered');
  answeredCount++;
  totalQuestions = document.querySelectorAll('.quiz-item').length;

  if (isCorrect) {
    btn.classList.add('correct');
    correctCount++;
  } else {
    btn.classList.add('wrong');
    q.querySelectorAll('.quiz-option').forEach(function(o) {
      if (o.getAttribute('onclick').includes('true')) o.classList.add('correct');
    });
  }

  q.querySelectorAll('.quiz-option').forEach(function(o) { o.disabled = true; });
  document.getElementById(qId + '-exp').classList.add('show');

  var scoreEl = document.getElementById('quiz-score');
  scoreEl.innerHTML = answeredCount + '/' + totalQuestions + ' 완료 | 정답: ' + correctCount + '개';
  scoreEl.style.display = 'block';
}
</script>
```

### 필수 CSS (styles.css에 포함)

```css
.quiz-option {
  display: block; width: 100%; padding: 12px 16px; margin: 6px 0;
  border: 2px solid #e2e8f0; border-radius: 8px; background: #fff;
  cursor: pointer; text-align: left; font-size: 1rem; transition: all 0.2s;
}
.quiz-option:hover:not(:disabled) { border-color: #3b82f6; background: #eff6ff; }
.quiz-option.correct { border-color: #22c55e; background: #f0fdf4; color: #15803d; font-weight: 600; }
.quiz-option.wrong { border-color: #ef4444; background: #fef2f2; color: #dc2626; }
.quiz-option:disabled { cursor: not-allowed; opacity: 0.7; }
.quiz-explanation { display: none; margin-top: 12px; padding: 12px; background: #f0fdf4; border-left: 4px solid #22c55e; border-radius: 4px; }
.quiz-explanation.show { display: block; }
.quiz-score { margin-top: 24px; padding: 16px; background: #1e293b; color: #fff; border-radius: 8px; text-align: center; font-size: 1.1rem; font-weight: 600; display: none; }
.answered .quiz-option:not(.correct):not(.wrong) { opacity: 0.5; }
```

## 코드 블록 복사 버튼 구현 가이드

모든 `<pre>` 코드 블록에 클립보드 복사 버튼을 추가한다.

### 필수 동작
1. 각 `<pre>` 블록 우측 상단에 복사 버튼 표시
2. 클릭 시 코드 내용이 클립보드에 복사됨
3. 복사 완료 후 버튼 텍스트가 "복사됨!"으로 잠시 변경 (2초 후 원복)

### 참고 JS (각 HTML 하단 또는 공통 스크립트에 포함)

```javascript
document.querySelectorAll('pre').forEach(function(pre) {
  var btn = document.createElement('button');
  btn.className = 'copy-btn';
  btn.textContent = '복사';
  btn.addEventListener('click', function() {
    var code = pre.querySelector('code') ? pre.querySelector('code').textContent : pre.textContent;
    navigator.clipboard.writeText(code).then(function() {
      btn.textContent = '복사됨!';
      setTimeout(function() { btn.textContent = '복사'; }, 2000);
    });
  });
  pre.style.position = 'relative';
  pre.appendChild(btn);
});
```

### 필수 CSS (styles.css에 포함)

```css
.copy-btn {
  position: absolute; top: 8px; right: 8px;
  padding: 4px 12px; border: 1px solid #475569; border-radius: 4px;
  background: #334155; color: #e2e8f0; font-size: 0.75rem;
  cursor: pointer; opacity: 0.7; transition: opacity 0.2s;
}
.copy-btn:hover { opacity: 1; }
```
