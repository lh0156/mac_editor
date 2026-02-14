# InkArc Editor Policy (Notion + Typora + Research)

버전: v1.2 (2026-02-14)
적용 범위: `/Users/developseop/Desktop/mac_editor`

## 1) 제품 원칙
- 목표: "바로 쓰기 시작 가능한" 단일 캔버스 Markdown 에디터.
- 지향: Typora의 자연스러운 Markdown 편집 + Notion의 블록 UX.
- 우선순위: 입력 안정성 > 가독성 > 시각 미학 > 부가 기능.

## 2) 기준 레퍼런스 정책
### Notion에서 채택할 것
- 라인 시작 Markdown 단축:
  - `-`/`*`/`+` + space: bullet
  - `[]` + space: to-do
  - `1.` + space: ordered
  - `>` + space: toggle
  - `"` + space: quote
- 블록 조작:
  - `Cmd+Enter`: 현재 블록(토글/체크박스) 상태 전환

### Typora에서 채택할 것
- 분리된 Preview 없이 본문 자체가 렌더되는 single-canvas.
- Markdown 문법 자동 연속 입력(리스트/인용/코드블록 흐름).
- 작성 중 문법 노이즈 최소화(표식은 보조 시각화로 대체 가능).

### 충돌 시 우선 규칙
- 블록 입력/전환 UX는 Notion 우선.
- Markdown 문법 해석/연속 입력은 Typora 우선.
- 둘 다 불명확하면 CommonMark/GFM 호환을 우선.

## 3) 논문/표준 근거 기반 타이포 정책
### 3.1 Line Length (CPL)
- 기본 목표: 55~75 CPL.
- 허용 범위: 50~80 CPL.
- 근거:
  - 55 CPL가 주관적 읽기 용이성이 높다는 결과(스크린 읽기 연구).
  - 접근성 기준에서 80자 이내 권고.
  - 너무 짧은 줄은 속도 저하(최소 문자 수 임계 존재).

### 3.2 Line Height / Spacing
- 기본 line-height: 1.55~1.68.
- 최소: 1.45, 최대: 1.80.
- 정책:
  - 기본값은 일반 독자 기준.
  - 저시력/난독 사용자를 위해 spacing 확장 옵션 제공.
  - 단, 과도한 letter spacing을 기본으로 강제하지 않음.

### 3.3 Font Size / Contrast
- 기본 본문 글자 크기: 17~19pt.
- 최소 지원: 14pt, 확대 시 200%까지 레이아웃 파손 금지.
- 텍스트 대비: 본문 최소 4.5:1 (AA), 가능하면 7:1 근접.

## 4) 입력 UX 정책 (필수)
### 4.1 자동 변환
- `[] ` -> `- [ ] `
- `[x] ` -> `- [x] `
- 위 규칙은 "라인 시작부"에서만 작동(문장 중간 오탐 금지).

### 4.2 Enter 규칙
- `-`, `1.`, `- [ ]`, `"`, `>`(토글 헤더)에서 Enter:
  - 다음 항목 자동 생성.
- 빈 마커 라인에서 Enter:
  - 블록 종료(마커 제거).
- 토글(`>`)은 Enter 시 자식 들여쓰기 줄로 진입.
- 토글 자식 빈 줄에서 Enter:
  - 토글 자식 컨텍스트 종료.

### 4.3 토글 단축키
- `Cmd+Enter`, `Alt+Enter` 모두 토글 접기/펼치기 지원.
- 토글 헤더 줄 뿐 아니라 자식 줄에서도 부모 토글 전환 가능해야 함.

### 4.4 Slash Command 팔레트
- 빈 줄 시작에서 `/` 입력 시 블록 팔레트가 열려야 함.
- 팔레트에는 최소 아래 오브젝트가 항상 표시되어야 함:
  - 텍스트
  - 제목1 / 제목2 / 제목3
  - 글머리 기호 목록
  - 번호 매기기 목록
  - 할 일 목록
  - 토글 목록
  - 페이지
  - 콜아웃
  - 인용
  - 코드 블록
- 항목명이 일부 바뀌더라도 의미상 동등한 블록은 유지되어야 함.

### 4.5 코드 표시 정책
- 인라인 코드와 코드 블록을 모두 읽기 쉬운 형태로 표시해야 함.
- 코드 블록(펜스 ```/~~~):
  - 모노스페이스 폰트 사용
  - 본문과 구분되는 배경(카드/패널) 제공
  - 일반 본문 대비 충분한 명도 대비 유지
- 인라인 코드(`code`):
  - 모노스페이스 폰트 + 약한 배경 강조
  - 주변 텍스트 흐름을 깨지 않는 패딩/라운드 느낌 유지

## 5) 컴팩트/미학 정책
- 기본 캔버스는 라이트 테마(white paper) 우선.
- 툴바는 최소 아이콘 집합 유지(새 문서/열기/저장/보기 설정).
- 표식 아이콘(불릿/토글/체크)의 시각 크기와 클릭 영역 분리:
  - 시각 크기와 무관하게 히트 영역은 충분히 크게 유지.
- 불릿 리스트의 시각 시그니처는 "dot + short bar"를 유지:
  - 점만 보이거나 바만 보이는 형태로 임의 변경 금지.
  - 바 길이/두께/간격은 버전 관리 하에 변경.
- 불릿 중복 표식 금지:
  - 커스텀 불릿(`dot + short bar`)이 보이는 라인에서는 원문 마커 글리프(`-`, `*`, `+`)가 추가로 보이면 안 됨.
  - 활성 라인/빈 라인/입력 직후 상태에서도 `dot + short bar + '-'` 같은 중복 표시는 릴리즈 차단 사유.
- 텍스트 편집에 무관한 장식(강한 그라디언트/과한 유리효과)은 기본 비활성.

## 6) QA 운영 정책 (릴리즈 게이트)
### QA 엄격도
- QA 기준은 "보수적(conservative)"으로 유지한다.
- 시각 정렬(마커/텍스트 간격, baseline 유사 정렬)은 수치 임계값으로 검사한다.
- 임계값을 완화하는 변경은 정책/TC/근거를 함께 수정하지 않으면 금지한다.
- 현재 체크박스 정렬 임계값:
  - 아이콘-텍스트 gap: `8 ~ 26 px`
  - 아이콘 중심 y와 텍스트 라인 중심 y 오차: `<= 1.2 px`
  - 연속 행 gap 편차: `<= 1.2 px`

### 자동 QA (필수)
- Build:
  - `cd /Users/developseop/Desktop/mac_editor && swift build`
- Editor QA:
  - `swiftc -parse-as-library /Users/developseop/Desktop/mac_editor/Sources/PlainMarkdownEditor.swift /Users/developseop/Desktop/mac_editor/QA/InkArcQARunner.swift -o /tmp/inkarc-qa && /tmp/inkarc-qa`
  - 기대 결과: `QA RESULT: PASS`
- Core QA:
  - `swiftc -parse-as-library /Users/developseop/Desktop/mac_editor/Sources/ReaderSettings.swift /Users/developseop/Desktop/mac_editor/Sources/ReaderModel.swift /Users/developseop/Desktop/mac_editor/QA/InkArcCoreQARunner.swift -o /tmp/inkarc-core-qa && /tmp/inkarc-core-qa`
  - 기대 결과: `CORE QA RESULT: PASS`
- Live UI QA:
  - `swiftc -parse-as-library /Users/developseop/Desktop/mac_editor/QA/InkArcUILiveQARunner.swift /Users/developseop/Desktop/mac_editor/Sources/PlainMarkdownEditor.swift -o /tmp/inkarc-live-qa && /tmp/inkarc-live-qa`
  - 기대 결과: `LIVE UI QA RESULT: PASS`
- Live UI Stress QA (반복):
  - `INKARC_LIVE_STRESS_LOOPS=80 /tmp/inkarc-live-qa`
  - 기대 결과: `LIVE UI QA RESULT: PASS`
  - 1회라도 실패 시 릴리즈 차단.
- App UI QA (실제 ReaderRootView/Editor 스택):
  - `swiftc -module-name InkArcAppQATemp -o /tmp/inkarc-app-qa /Users/developseop/Desktop/mac_editor/QA/InkArcAppQARunner.swift /Users/developseop/Desktop/mac_editor/Sources/ReaderRootView.swift /Users/developseop/Desktop/mac_editor/Sources/ReaderModel.swift /Users/developseop/Desktop/mac_editor/Sources/ReaderSettings.swift /Users/developseop/Desktop/mac_editor/Sources/PlainMarkdownEditor.swift -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers`
  - `INKARC_APP_QA_LOOPS=3 /tmp/inkarc-app-qa`
  - 기대 결과: `APP UI QA RESULT: PASS`
- Continuous Live Soak QA (무한 반복):
  - `cd /Users/developseop/Desktop/mac_editor && ./QA/run_live_soak.sh`
  - 기본값은 무한 반복(`INKARC_LIVE_STRESS_MAX_BATCHES=0`)이며, 실패 시 즉시 종료.
  - 수동 종료 전까지 실패가 없을 것.
  - 필요 시 배치 제한:
    - `INKARC_LIVE_STRESS_LOOPS_PER_BATCH=120 INKARC_LIVE_STRESS_MAX_BATCHES=10 ./QA/run_live_soak.sh`

### 수동 스모크 (필수)
- `-` 입력 직후 글자 크기 붕괴 없음.
- `>` 토글에서 Enter -> 자식 줄 진입.
- 토글 자식 줄에서 Cmd+Enter/Alt+Enter -> 부모 토글 반응.
- 체크박스 클릭 2회 -> `[ ] -> [x] -> [ ]` 왕복.
- 확대/축소 후에도 가로 스크롤 없이 본문 읽기 가능.
- 불릿 마커 시그니처(`dot + short bar`) 유지 확인.
- 불릿 라인에서 중복 마커(`dot + short bar` + `-`)가 보이지 않는지 확인.
- `/` 팔레트에 필수 오브젝트(텍스트/제목/목록/토글/페이지/콜아웃/인용) 표시 확인.
- 코드 블록이 모노스페이스 + 별도 배경으로 렌더되는지 확인.
- 체크박스-텍스트 정렬:
  - 좌우 gap이 과도하게 벌어지지 않는지
  - 아이콘 중심이 텍스트 라인 중심과 크게 어긋나지 않는지

## 7) 변경 관리 정책
- UX 입력 규칙 변경 시:
  - Editor QA 케이스를 먼저 추가/수정하고 코드 반영.
- 타이포 기본값 변경 시:
  - CPL 계산 근거를 함께 기록.
- 접근성 관련 변경 시:
  - WCAG 관련 기준(대비/spacing/resize) 충돌 여부를 우선 점검.
- 사용자 명시 요청 시:
  - Live Soak QA를 무한 반복 모드로 실행하고, 실패 케이스가 0이 아닐 경우 수정 후 다시 반복한다.
  - QA가 100% 통과하지 않으면 릴리즈/완료 보고를 금지한다.
- 단기 수정 사이클 규칙:
  - 동일 테스트 루프는 회차당 최대 3회까지만 실행하고, 미통과 시 코드 수정으로 즉시 전환한다.

## References
- Notion Keyboard Shortcuts: https://www.notion.com/help/keyboard-shortcuts
- Typora Markdown Reference: https://support.typora.io/Markdown-Reference/
- Typora Shortcut Keys: https://support.typora.io/Shortcut-Keys/
- Dyson & Kipping (1998), line length on screen: https://journals.uc.edu/index.php/vl/article/view/5671
- Atilgan et al. (2020), print-size/display-size constraints: https://pmc.ncbi.nlm.nih.gov/articles/PMC7720185/
- Rubin et al. (2006), font/line width and reading speed: https://pubmed.ncbi.nlm.nih.gov/17040418/
- van den Boer & Hakvoort (2015), interletter spacing: https://pubmed.ncbi.nlm.nih.gov/25210997/
- Rayner (1998), eye movements in reading: https://pubmed.ncbi.nlm.nih.gov/9849112/
- WCAG 1.4.8 Visual Presentation: https://www.w3.org/WAI/WCAG21/Understanding/visual-presentation
- WCAG 1.4.12 Text Spacing: https://www.w3.org/WAI/WCAG21/Understanding/text-spacing.html
- WCAG 1.4.3 Contrast Minimum: https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum
