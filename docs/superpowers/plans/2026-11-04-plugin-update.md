# 플러그인 업데이트 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** "업데이트 필요" 탭에서 새 버전이 있는 플러그인을 보여주고 Claude Code 명령으로 업데이트한다.

**Architecture:** 비교는 순수 Dart(`checkUpdates`)로 마켓 복사본과 설치 기록을 읽는다. 명령 실행은 `ClaudeCli` 뒤에 두고 테스트에서 가짜로 바꾼다. 화면은 `UpdatePage`, `AppShell`은 탭 내용을 `IndexedStack`으로 유지한다.

**Tech Stack:** Flutter, `dart:io` `Process` (패키지 추가 없음)

**Spec:** `docs/superpowers/specs/2026-11-04-plugin-update-design.md`

## Global Constraints
- 패키지 추가 없음. 파일을 직접 받거나 복사하지 않는다. 업데이트는 확인 창 뒤에만.
- 문구: 버튼 `업데이트 확인`, `업데이트`, 확인 창 본문 `<id>을(를) <현재> → <최신>(으)로 업데이트합니다. Claude Code를 다시 시작해야 적용됩니다.`, 버튼 `취소`/`업데이트`, 명령 없음 `Claude Code 명령(claude)을 찾지 못했습니다`, 모두 최신 `모든 플러그인이 최신입니다`, 확인 불가 묶음 제목 `확인할 수 없음`, 명령형 안내 `Claude Code에서 직접 업데이트해 주세요`.

## Review Focus
1. 마켓 폴더·JSON이 없거나 깨짐 → 그 플러그인만 `확인할 수 없음`, 나머지는 정상 → Task 1 테스트.
2. `claude` 명령이 실패(종료 코드 ≠ 0) → 항목 아래 출력 표시, 앱은 계속 → Task 2 테스트.
3. 확인 중에 버튼을 다시 눌러도 명령이 한 번만 → Task 2 테스트.
4. 탭을 옮겼다 와도 확인 결과·필터가 남아 있다 → Task 2 `IndexedStack` 테스트.

---

### Task 1: 업데이트 비교와 명령 실행기

**Files:** Create `lib/update/update_check.dart`, `lib/update/claude_cli.dart`; Test `test/update/update_check_test.dart`

**Interfaces (Produces):**
- `enum UpdateState { needed, unknown }`
- `class PluginUpdate { final String id; final String scope; final String current; final String? latest; final int skillCount; final UpdateState state; }`
- `Future<List<PluginUpdate>> checkUpdates(Directory claudeDir)` — 최신과 같은 플러그인은 빼고, 업데이트 필요·확인 불가만 id 순으로. 예외를 던지지 않는다.
- `class CmdResult { final int exitCode; final String stdout; final String stderr; }`
- `abstract class ClaudeCli { Future<CmdResult?> run(List<String> args); }` — `claude`를 못 찾으면 null. `class ProcessClaudeCli implements ClaudeCli`.

- [ ] 테스트(임시 `.claude`): `versionFromMarketJson`(마켓 항목 version 1.1 vs 설치 1.0 → needed, latest 1.1), `versionFromPluginJson`(항목 version 없고 source `./p` → plugin.json 2.0), `sameVersionHidden`, `shaCompare`(source `{sha: 'abcdef1234'}` vs gitCommitSha 다름 → latest `abcdef1`, current 설치 sha 앞 7자), `noMarket`(마켓 폴더 없음 → unknown), `badJson`, `skillCount`(installPath/skills 아래 폴더 2개 → 2), `noInstalledJson` → 빈 목록
- [ ] 실패 확인 → 구현 → `flutter test test/update/` 통과 → 커밋 `"플러그인 업데이트 비교와 claude 명령 실행기"`

### Task 2: 업데이트 화면과 연결

**Files:** Create `lib/ui/update_page.dart`; Modify `lib/ui/app_shell.dart`(`Widget? updates` 매개변수, `IndexedStack`), `lib/main.dart`(`UpdatePage` 생성, `ProcessClaudeCli`); Test `test/ui/update_page_test.dart`, `test/ui/app_shell_test.dart`

**Interfaces:** `UpdatePage({required Directory? claudeDir, required ClaudeCli cli, required Future<List<PluginUpdate>> Function(Directory) check, required Future<void> Function() onUpdated})`

- [ ] 테스트(가짜 cli·check): 확인 누르면 `['plugin','marketplace','update']` 실행 후 목록에 `p@m`, `1.0 → 1.1`; 확인 중 재클릭 무시(실행 1회); 빈 목록 → `모든 플러그인이 최신입니다`; unknown 항목은 `확인할 수 없음` 아래; `업데이트` → 확인 창 → `취소`면 실행 안 함, `업데이트`면 `['plugin','update','p@m','--scope','user','--json']` 실행 + `onUpdated` 호출; 실패(exit 1, stderr `boom`) → `boom` 표시; cli가 null → `Claude Code 명령(claude)을 찾지 못했습니다`; AppShell: 업데이트 탭 갔다 오면 목록 필터 유지(IndexedStack)
- [ ] 실패 확인 → 구현 → `flutter test`, `flutter analyze`, `flutter build macos --debug` → 커밋 `"업데이트 필요 탭: 확인과 업데이트"`
