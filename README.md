# InkArc

macOS용 단일 캔버스 Markdown 에디터입니다.  
Typora처럼 본문 자체가 렌더링되고, Notion처럼 블록 입력 UX(`-`, `>`, `[]`, `"` + Enter 흐름)를 지원합니다.

## Location
- `/Users/developseop/Desktop/InkArc`
- 정책 문서: `/Users/developseop/Desktop/InkArc/EDITOR_POLICY.md`
- TC 매트릭스: `/Users/developseop/Desktop/InkArc/QA/POLICY_TC.md`

## Run
```bash
cd /Users/developseop/Desktop/InkArc
swift run
```

## UX Highlights
- Single-canvas 편집: Preview 분리 없이 작성/읽기 동시 처리
- Notion형 자동 개행/종료:
  - `-`, `>`, `"` 블록에서 Enter 시 다음 블록 자동 생성
  - 빈 마커 라인에서 Enter 한 번 더 누르면 블록 종료
  - `[] ` / `[x] ` 입력 시 `- [ ] ` / `- [x] `로 자동 변환
- 클릭 가능한 토글/체크:
  - `>` 토글 아이콘으로 접기/펼치기
  - 체크박스 클릭으로 `[ ]` ↔ `[x]` 전환

## Typography Presets (Research / Compact)
- Research: 55-75 CPL, line-height 1.58-1.70
- Compact: 70-90 CPL, line-height 1.45-1.58
- 폰트 크기 변경 시 목표 CPL을 유지하도록 본문 폭 자동 재계산

## QA
현재 환경에서 `swift test`는 로컬 Command Line Tools 이슈로 XCTest를 찾지 못해, 실행형 QA 러너를 같이 제공합니다.

```bash
# Editor QA
swiftc -parse-as-library \
  /Users/developseop/Desktop/InkArc/Sources/PlainMarkdownEditor.swift \
  /Users/developseop/Desktop/InkArc/QA/InkArcQARunner.swift \
  -o /tmp/inkarc-qa

/tmp/inkarc-qa

# Core QA (ReaderModel / ReaderSettings)
swiftc -parse-as-library \
  /Users/developseop/Desktop/InkArc/Sources/ReaderSettings.swift \
  /Users/developseop/Desktop/InkArc/Sources/ReaderModel.swift \
  /Users/developseop/Desktop/InkArc/QA/InkArcCoreQARunner.swift \
  -o /tmp/inkarc-core-qa

/tmp/inkarc-core-qa
```

정상 결과:
```text
QA RESULT: PASS
CORE QA RESULT: PASS
```
