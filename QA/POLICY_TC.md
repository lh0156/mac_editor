# Policy Test Cases (TC)

기준 문서: `/Users/developseop/Desktop/mac_editor/EDITOR_POLICY.md`

## 실행 명령
- Build: `cd /Users/developseop/Desktop/mac_editor && swift build`
- Editor QA: `swiftc -parse-as-library /Users/developseop/Desktop/mac_editor/Sources/PlainMarkdownEditor.swift /Users/developseop/Desktop/mac_editor/QA/InkArcQARunner.swift -o /tmp/inkarc-qa && /tmp/inkarc-qa`
- Core QA: `swiftc -parse-as-library /Users/developseop/Desktop/mac_editor/Sources/ReaderSettings.swift /Users/developseop/Desktop/mac_editor/Sources/ReaderModel.swift /Users/developseop/Desktop/mac_editor/QA/InkArcCoreQARunner.swift -o /tmp/inkarc-core-qa && /tmp/inkarc-core-qa`
- Live UI QA: `swiftc -parse-as-library /Users/developseop/Desktop/mac_editor/QA/InkArcUILiveQARunner.swift /Users/developseop/Desktop/mac_editor/Sources/PlainMarkdownEditor.swift -o /tmp/inkarc-live-qa && /tmp/inkarc-live-qa`
- Live UI Stress QA: `INKARC_LIVE_STRESS_LOOPS=80 /tmp/inkarc-live-qa`
- Continuous Live Soak QA: `cd /Users/developseop/Desktop/mac_editor && ./QA/run_live_soak.sh`
- App UI QA: `swiftc -module-name InkArcAppQATemp -o /tmp/inkarc-app-qa /Users/developseop/Desktop/mac_editor/QA/InkArcAppQARunner.swift /Users/developseop/Desktop/mac_editor/Sources/ReaderRootView.swift /Users/developseop/Desktop/mac_editor/Sources/ReaderModel.swift /Users/developseop/Desktop/mac_editor/Sources/ReaderSettings.swift /Users/developseop/Desktop/mac_editor/Sources/PlainMarkdownEditor.swift -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers && INKARC_APP_QA_LOOPS=3 /tmp/inkarc-app-qa`

## TC 목록

| TC ID | 정책 항목 | 검증 내용 | 자동화 위치 |
|---|---|---|---|
| TC-UX-001 | 4.1 | `[] ` -> `- [ ] ` 변환 | `InkArcQARunner.swift` |
| TC-UX-002 | 4.1 | `[x] ` -> `- [x] ` 변환 | `InkArcQARunner.swift` |
| TC-UX-003 | 4.1 | 문장 중간 `[] ` 오탐 금지 | `InkArcQARunner.swift` |
| TC-UX-004 | 4.2 | `-` Enter 연속/더블 Enter 탈출 | `InkArcQARunner.swift` |
| TC-UX-005 | 4.2 | `*`, `+` bullet Enter 연속 | `InkArcQARunner.swift` |
| TC-UX-006 | 4.2 | `1.` ordered Enter 연속 | `InkArcQARunner.swift` |
| TC-UX-007 | 4.2 | `- [ ]` task Enter 연속 | `InkArcQARunner.swift` |
| TC-UX-008 | 4.2 | `"` quote Enter 연속/탈출 | `InkArcQARunner.swift` |
| TC-UX-009 | 4.2 | `>` toggle Enter -> 자식 줄 | `InkArcQARunner.swift` |
| TC-UX-010 | 4.2 | 토글 자식 줄 Enter 연속/탈출 | `InkArcQARunner.swift` |
| TC-UX-011 | 4.3 | `Cmd+Enter` 토글 헤더 전환/왕복 | `InkArcQARunner.swift` |
| TC-UX-012 | 4.3 | `Alt+Enter` 토글 헤더 전환/왕복 | `InkArcQARunner.swift` |
| TC-UX-013 | 4.3 | 자식 줄에서 `Cmd+Enter` 부모 토글 전환 | `InkArcQARunner.swift` |
| TC-UX-014 | 4.3 | 자식 줄에서 `Alt+Enter` 부모 토글 전환 | `InkArcQARunner.swift` |
| TC-UX-015 | 4.3 | `Cmd+Enter` 체크박스 전환/왕복 | `InkArcQARunner.swift` |
| TC-UX-016 | 4.3 | `Alt+Enter` 체크박스 전환/왕복 | `InkArcQARunner.swift` |
| TC-UX-017A | 4.2 | `insertLineBreak`(no modifier) 는 일반 Enter와 동일 동작 | `InkArcQARunner.swift` |
| TC-UX-017B | 4.2 | `insertNewlineIgnoringFieldEditor`(no modifier) 는 일반 Enter와 동일 동작 | `InkArcQARunner.swift` |
| TC-UX-018 | 5, 6 | 토글 클릭 콜백 동작 | `InkArcQARunner.swift` |
| TC-UX-019 | 5, 6 | 체크박스 클릭 콜백 동작 | `InkArcQARunner.swift` |
| TC-UX-020 | 6(수동 스모크 자동화 대체) | `-` 입력 직후 typing font 붕괴 없음 | `InkArcQARunner.swift` |
| TC-UX-021 | 4.2, 6 | setext 오탐 방지(`Heading\\n-`) | `InkArcQARunner.swift` |
| TC-UX-022 | 4.2 | setext 정상(`Heading\\n--`) | `InkArcQARunner.swift` |
| TC-UX-023 | 안정성 | collapse 상태 marker 오프셋 이동 후 유지 | `InkArcQARunner.swift` |
| TC-UX-024 | 4.4 | `/` 팔레트 필수 오브젝트 존재(텍스트/제목/목록/토글/페이지/콜아웃/인용/코드 블록) | `InkArcQARunner.swift` |
| TC-UX-025 | 4.4 | `/` 팔레트 필수 오브젝트 템플릿 매핑 정확성 | `InkArcQARunner.swift` |
| TC-VIS-001 | 5 | 불릿 시각 시그니처 유지(`dot + short bar`) | `InkArcQARunner.swift` + 수동 스모크 |
| TC-VIS-002 | 4.5 | 코드 블록/인라인 코드가 모노스페이스 + 배경 강조로 렌더 | `InkArcQARunner.swift` |
| TC-VIS-003 | 6 | 체크박스 아이콘-텍스트 gap 범위(8~26px) | `InkArcQARunner.swift` |
| TC-VIS-004 | 6 | 체크박스 아이콘 중심 y와 텍스트 라인 중심 y 오차(`<=1.2px`) | `InkArcQARunner.swift` |
| TC-VIS-005 | 6 | 연속 행 체크박스 gap 편차(`<=1.2px`) | `InkArcQARunner.swift` |
| TC-VIS-006 | 5 | 불릿 라인에서 원문 `-` 글리프가 보이지 않아 중복 마커가 발생하지 않음 | `InkArcQARunner.swift` |
| TC-VIS-007 | 5 | 활성 빈 bullet 라인(`- `)은 guide bar를 숨겨 `dot`만 표시 | `InkArcQARunner.swift`, `InkArcUILiveQARunner.swift`, `InkArcAppQARunner.swift` |
| TC-LIVE-001 | 6 | 실제 윈도우/입력 이벤트로 토글 자식 입력 가시성 검증 | `InkArcUILiveQARunner.swift` |
| TC-LIVE-002 | 6 | 실제 윈도우에서 insertLineBreak/insertNewlineIgnoringFieldEditor 폴백 검증 | `InkArcUILiveQARunner.swift` |
| TC-LIVE-003 | 6 | 실제 토글 아이콘 클릭 접기/펼치기 왕복 검증 | `InkArcUILiveQARunner.swift` |
| TC-LIVE-004 | 6 | 실제 체크박스 클릭 `[ ]`↔`[x]` 왕복 검증 | `InkArcUILiveQARunner.swift` |
| TC-LIVE-005 | 6 | 실제 Cmd/Alt+Enter 토글 단축키 동작 검증 | `InkArcUILiveQARunner.swift` |
| TC-LIVE-006 | 6 | 실제 리스트 Enter 연속/더블 Enter 종료 검증 | `InkArcUILiveQARunner.swift` |
| TC-LIVE-007 | 5, 6 | 실제 `- ` 입력 시 불릿 중복 마커(`dot + short bar + '-'`) 비발생 검증 | `InkArcUILiveQARunner.swift` |
| TC-STRESS-001 | 6 | Live UI QA를 N회 반복 실행해 회귀/플레이키니스 검출 | `InkArcUILiveQARunner.swift` |
| TC-STRESS-002 | 6, 7 | Live QA 배치 무한 반복(또는 지정 배치 수) 실행 시 실패 즉시 중단 | `run_live_soak.sh` |
| TC-APP-001 | 6 | 실제 ReaderRootView 스택에서 불릿 중복 마커 비발생 검증 | `InkArcAppQARunner.swift` |
| TC-APP-002 | 6 | 실제 ReaderRootView 스택에서 토글 자식 입력 가시성 검증 | `InkArcAppQARunner.swift` |
| TC-APP-003 | 6 | 실제 ReaderRootView 스택에서 Cmd+Enter 토글 반응 검증 | `InkArcAppQARunner.swift` |
| TC-CORE-001 | 3.1 | Research CPL 범위(55~75) | `InkArcCoreQARunner.swift` |
| TC-CORE-002 | 3.1 | Compact CPL 범위(70~90) | `InkArcCoreQARunner.swift` |
| TC-CORE-003 | 3.1 | content width bounds(560~920) | `InkArcCoreQARunner.swift` |
| TC-CORE-004 | 3.1 | font size 변경 시 width 재계산 | `InkArcCoreQARunner.swift` |
| TC-CORE-005 | 저장/불러오기 | UTF-8 read/write 일치 | `InkArcCoreQARunner.swift` |
| TC-CORE-006 | 저장/불러오기 | Latin-1 read 일치 | `InkArcCoreQARunner.swift` |
| TC-CORE-007 | 모델 상태 | update/save 시 unsaved flag 전이 | `InkArcCoreQARunner.swift` |
| TC-CORE-008 | 오류 처리 | missing file open 시 errorMessage 설정 | `InkArcCoreQARunner.swift` |
