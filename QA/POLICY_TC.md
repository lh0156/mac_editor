# Policy Test Cases (TC)

기준 문서: `/Users/developseop/Desktop/InkArc/EDITOR_POLICY.md`

## 실행 명령
- Build: `cd /Users/developseop/Desktop/InkArc && swift build`
- Editor QA: `swiftc -parse-as-library /Users/developseop/Desktop/InkArc/Sources/PlainMarkdownEditor.swift /Users/developseop/Desktop/InkArc/QA/InkArcQARunner.swift -o /tmp/inkarc-qa && /tmp/inkarc-qa`
- Core QA: `swiftc -parse-as-library /Users/developseop/Desktop/InkArc/Sources/ReaderSettings.swift /Users/developseop/Desktop/InkArc/Sources/ReaderModel.swift /Users/developseop/Desktop/InkArc/QA/InkArcCoreQARunner.swift -o /tmp/inkarc-core-qa && /tmp/inkarc-core-qa`

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
| TC-CORE-001 | 3.1 | Research CPL 범위(55~75) | `InkArcCoreQARunner.swift` |
| TC-CORE-002 | 3.1 | Compact CPL 범위(70~90) | `InkArcCoreQARunner.swift` |
| TC-CORE-003 | 3.1 | content width bounds(560~920) | `InkArcCoreQARunner.swift` |
| TC-CORE-004 | 3.1 | font size 변경 시 width 재계산 | `InkArcCoreQARunner.swift` |
| TC-CORE-005 | 저장/불러오기 | UTF-8 read/write 일치 | `InkArcCoreQARunner.swift` |
| TC-CORE-006 | 저장/불러오기 | Latin-1 read 일치 | `InkArcCoreQARunner.swift` |
| TC-CORE-007 | 모델 상태 | update/save 시 unsaved flag 전이 | `InkArcCoreQARunner.swift` |
| TC-CORE-008 | 오류 처리 | missing file open 시 errorMessage 설정 | `InkArcCoreQARunner.swift` |
