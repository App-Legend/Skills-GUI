# 사이드바 탭 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 왼쪽 사이드바 탭으로 Claude Code 목록과 "준비 중" 화면들을 오간다.

**Architecture:** `AppShell`이 배경·사이드바·내용 영역을 갖고 선택한 탭에 따라 내용을 바꾼다. `SkillListPage`는 사이드바를 빼고 내용(제목, 다시 스캔, 필터 버튼 줄, 카드)만 남긴다. `main.dart`는 `SkillListPage` 대신 `AppShell`을 띄운다.

**Tech Stack:** Flutter (패키지 추가 없음)

**Spec:** `docs/superpowers/specs/2026-11-04-sidebar-tabs-design.md`

## Global Constraints
- 패키지 추가 없음.
- 탭 문구: 그룹 `에이전트`(`Claude Code`, `Codex`), 그룹 `정리`(`업데이트 있음`, `미사용 후보`, `찾기·랭킹`).
- 준비 중 화면 문구: `아직 준비 중입니다`.
- Claude Code 탭에만 스킬 개수. 다른 탭은 개수 없음.
- 필터 버튼 줄: `전체` `전역` `플러그인` `꺼짐`, 제목 패널 아래.
- 탭·버튼은 누를 수 있는 높이 44 이상, 선택 상태를 `Semantics(selected:, button: true)`로 알린다(탭 동작 유지, `excludeSemantics` 금지).

## Review Focus
1. 탭을 옮겼다 돌아와도 앱이 죽지 않고 목록이 다시 보여야 한다 → Task 1 테스트 `탭 왕복`.
2. 좁은 창(900×600)에서 사이드바+목록이 넘치지 않아야 한다 → Task 1 테스트 `좁은 창`.
3. 스캔 실패·로딩 화면에서도 사이드바가 깨지지 않아야 한다 → 기존 `main` 흐름은 실패 화면에 사이드바 없이 둔다(범위 밖), 테스트 유지.

---

### Task 1: AppShell과 목록 화면 정리

**Files:**
- Create: `lib/ui/app_shell.dart`
- Modify: `lib/ui/skill_list_page.dart` (`_Sidebar` 삭제, 필터를 `_Main` 제목 아래 버튼 줄로, `Scaffold`·`GlassBackground`·바깥 Row 제거), `lib/main.dart` (`SkillListPage(...)` → `AppShell(...)`)
- Test: `test/ui/app_shell_test.dart`, `test/ui/skill_list_page_test.dart`(사이드바 개수 검사는 app_shell 테스트로 옮김)

**Interfaces:**
- Produces: `enum AppTab { claude, codex, updates, unused, discover }` (각 `label`), `class AppShell extends StatefulWidget { final ScanResult result; final Future<void> Function() onRescan; final void Function(Skill) onOpen; }`
- `SkillListPage` 생성자는 그대로(`result`, `onRescan`, `onOpen`). 이제 배경·Scaffold 없이 내용만 그린다.

- [ ] **Step 1: 실패하는 테스트** — `app_shell_test.dart` (1280×820)
  - `처음엔 Claude Code 목록`: 스킬 1개 → 카드 이름 보임, 사이드바 `Claude Code`와 `1` 보임, `에이전트`·`정리` 보임
  - `준비 중 탭`: `Codex`, `업데이트 있음`, `미사용 후보`, `찾기·랭킹` 각각 탭 → `아직 준비 중입니다` 보이고 카드 이름 안 보임
  - `탭 왕복`: `Codex` → `Claude Code` → 카드 이름 다시 보임, `takeException()` null
  - `선택 상태`: `Claude Code` 노드 `matchesSemantics(isButton: true, isSelected: true, hasTapAction: true, ...)`, `Codex`는 isSelected false
  - `좁은 창`: 900×600 → `takeException()` null
  - `skill_list_page_test.dart`: 필터 버튼 줄로 같은 필터 테스트 통과
- [ ] **Step 2: 실패 확인** — `flutter test test/ui/`
- [ ] **Step 3: 구현** — 사이드바 폭 240, `GlassPanel`, 그룹 제목은 작은 회색 글씨(시안). 내용 영역은 `AppTab.claude`면 `SkillListPage`, 아니면 가운데 `아직 준비 중입니다`.
- [ ] **Step 4: 통과 확인** — `flutter test`, `flutter analyze`
- [ ] **Step 5: 커밋** — `"사이드바 탭: Claude Code 목록과 준비 중 화면"`
