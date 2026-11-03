# 스킬 스캔 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Claude Code 전역·플러그인 스킬을 읽어 리퀴드 글래스 목록·상세 화면으로 보여준다 (macOS 샌드박스 유지, Windows 지원).

**Architecture:** 스캔은 순수 Dart(`dart:io`)로, `.claude` 폴더 `Directory`를 받아 `ScanResult`를 돌려준다. 폴더 권한은 `FolderAccess` 인터페이스 뒤에 숨긴다. macOS 구현은 `file_selector` + Swift 북마크 채널이고, Windows 구현은 홈 폴더를 바로 쓴다. UI는 기본 `StatefulWidget`과 `Navigator`만 쓴다 (상태 관리 패키지 없음).

**Tech Stack:** Flutter 3.47 / Dart, `yaml`, `file_selector`, Swift (macOS Runner)

**Spec:** `docs/superpowers/specs/2026-11-03-skill-scan-design.md`

## Global Constraints

- 추가 패키지는 `yaml`, `file_selector` 둘만. 그 외 추가 금지.
- 스캔은 읽기만 한다. 사용자 파일을 쓰거나 바꾸지 않는다.
- 읽지 못한 스킬도 목록에 남기고 이유를 보여준다.
- 플러그인: `installed_plugins.json`의 모든 항목(scope 무관), 각 항목의 `installPath` 기준. user 범위는 `settings.json`의 `enabledPlugins["<이름>@<마켓>"]`가 `true`면 켜짐, 아니면 꺼짐. 프로젝트 범위는 켜짐 여부 `null`(모름).
- 꺼진 플러그인 스킬도 목록에 넣고 "꺼짐" 표시. 사이드바에 "꺼짐" 필터.
- 프로젝트 범위 플러그인 스킬은 카드에 프로젝트 경로 표시.
- `settings.json`을 읽지 못하면 user 플러그인의 켜짐 여부도 `null`로 두고 notice를 남긴다.
- 캐시의 옛 버전 폴더는 목록에 넣지 않고 개수만 notice.
- `skills/synced/`는 펼치지 않는다. 출처 "동기화", 설명 "claude.ai에서 동기화된 스킬 폴더"인 항목 하나.
- macOS 샌드박스 유지. entitlements(DebugProfile·Release 모두)에 `com.apple.security.files.user-selected.read-only`, `com.apple.security.files.bookmarks.app-scope` 추가.
- macOS "투명도 줄이기"가 켜지면 블러 대신 불투명 배경 `#F4F6FA`.
- 화면 문구는 간결한 한국어. 시안: https://claude.ai/artifact/STvot9BocgrsUZXwDAWF9f ("스킬 목록", "스킬 상세").

## Review Focus

1. **깨진 링크 / 허락 범위 밖 링크** (`computer-use -> ../../.agents/skills/...`): 앱이 죽지 않고 카드에 "읽을 수 없음"과 실제 경로가 보여야 한다. → Task 2 테스트 `brokenLink`, Task 2 권한 오류 분류.
2. **머리말 없음·잘못된 YAML·`name` 누락**: 폴더 이름으로 대체하고 문제로 표시. → Task 1 테스트.
3. **여러 줄 `description`(`>`, `|`)**: 줄바꿈이 합쳐져 한 문단으로 읽혀야 한다. → Task 1 테스트 `foldedDescription`.
4. **`installed_plugins.json` 없음/깨짐, `installPath`가 사라진 폴더**: 전역 스킬은 그대로 나오고 notice로 알린다. → Task 3 테스트.
5. **사용자가 `.claude`가 아닌 폴더를 고름**: 다시 고르라는 안내. → Task 4 `isClaudeDir` 테스트.

권한 거부(EPERM)는 테스트 환경에서 재현이 어렵다. Task 2의 오류 분류 함수만 단위 테스트하고, 실제 동작은 Task 7 수동 확인에서 본다.

---

## 파일 구조

| 파일 | 역할 |
|---|---|
| `lib/scan/skill.dart` | `Skill`, `SkillSource`, `SkillProblem`, `ScanResult` 모델 |
| `lib/scan/frontmatter.dart` | `SKILL.md` 머리말 파싱 |
| `lib/scan/skill_scanner.dart` | 전역·synced·플러그인 스캔 |
| `lib/access/folder_access.dart` | `FolderAccess` 인터페이스, Windows 구현, `isClaudeDir` |
| `lib/access/macos_folder_access.dart` | macOS 구현 (MethodChannel + `file_selector`) |
| `macos/Runner/FolderAccessChannel.swift` | 북마크 저장·복원, 실제 홈 경로, 투명도 줄이기 값 |
| `lib/ui/glass.dart` | 배경 그라데이션, `GlassPanel` |
| `lib/ui/access_page.dart` | 폴더 허락 화면 |
| `lib/ui/skill_list_page.dart` | 목록 (사이드바 필터, 카드 그리드, 다시 스캔) |
| `lib/ui/skill_detail_page.dart` | 상세 |
| `lib/main.dart` | 앱 시작, 권한 → 스캔 → 목록 흐름 (카운터 앱 대체) |
| `test/scan/*_test.dart`, `test/access/*_test.dart`, `test/ui/*_test.dart` | 테스트 |

---

### Task 1: 모델과 머리말 파싱

**Files:**
- Create: `lib/scan/skill.dart`, `lib/scan/frontmatter.dart`
- Modify: `pubspec.yaml` (`flutter pub add yaml`)
- Test: `test/scan/frontmatter_test.dart`

**Interfaces:**
- Produces:
  - `enum SkillSource { global, synced, plugin }`
  - `enum ProblemKind { noSkillMd, badFrontmatter, noPermission, brokenLink, unreadable }`
  - `class SkillProblem { final ProblemKind kind; final String message; }` — `message`는 화면에 그대로 쓰는 한국어
  - `class Skill { final String name; final String? description; final SkillSource source; final String? plugin /* "<이름>@<마켓>" */; final String? pluginVersion; final bool? pluginEnabled /* 플러그인만: true 켜짐, false 꺼짐, null 모름 */; final String? projectPath /* 프로젝트 범위 플러그인만 */; final String path; final String? linkTarget; final String? skillMd; final List<String> files; final SkillProblem? problem; }`
  - `class ScanResult { final List<Skill> skills; final List<String> notices; }`
  - `({String? name, String? description}) parseFrontmatter(String skillMd)` — 머리말이 없거나 YAML 오류면 `FormatException`

- [ ] **Step 1: `flutter pub add yaml`** 실행, `pubspec.yaml`에 `yaml`이 들어갔는지 확인
- [ ] **Step 2: 실패하는 테스트 작성** — `test/scan/frontmatter_test.dart`
  - `plain`: `'---\nname: a\ndescription: b\n---\n# x'` → `name == 'a'`, `description == 'b'`
  - `foldedDescription`: `description: >\n  one\n  two` → `'one two'` (끝 줄바꿈은 trim)
  - `literalDescription`: `description: |\n  one\n  two` → `'one\ntwo'`
  - `quoted`: `description: "a: b"` → `'a: b'`
  - `missingName`: `name` 없으면 `name == null`
  - `noFrontmatter`: `'# x'` → `throwsFormatException`
  - `badYaml`: `'---\nname: [\n---'` → `throwsFormatException`
  - `crlf`: `'---\r\nname: a\r\n---\r\n'` → `name == 'a'`
- [ ] **Step 3: 실행해서 실패 확인** — `flutter test test/scan/frontmatter_test.dart` → 컴파일 실패
- [ ] **Step 4: 구현** — 첫 줄이 `---`인지 보고, 다음 `---` 줄까지를 `loadYaml`로 읽는다. 결과가 `YamlMap`이 아니면 `FormatException`. `name`·`description`은 `toString().trim()`.
- [ ] **Step 5: 통과 확인** — 같은 명령, 8개 PASS
- [ ] **Step 6: 커밋** — `git commit -m "스킬 모델과 SKILL.md 머리말 파싱"`

### Task 2: 전역·synced 스캔

**Files:**
- Create: `lib/scan/skill_scanner.dart`
- Test: `test/scan/skill_scanner_test.dart`

**Interfaces:**
- Consumes: Task 1 모델, `parseFrontmatter`
- Produces:
  - `Future<ScanResult> scanClaude(Directory claudeDir)` — 이 Task에서는 전역·synced만, Task 3에서 플러그인 추가
  - `Future<Skill> readSkillDir(String path, {required SkillSource source, String? plugin, String? pluginVersion})` — 폴더 하나를 `Skill`로. 예외를 밖으로 던지지 않는다.
  - `ProblemKind classifyFsError(FileSystemException e)` — `osError?.errorCode`가 1(EPERM)·13(EACCES)이면 `noPermission`, 그 외 `unreadable`

테스트는 `Directory.systemTemp.createTemp()`에 가짜 `.claude`를 만들고 `tearDown`에서 지운다.

- [ ] **Step 1: 실패하는 테스트 작성**
  - `globalSkill`: `skills/a/SKILL.md`(name a, description d) + `skills/a/scripts/run.sh` → `name=='a'`, `source==global`, `files`에 `'SKILL.md'`, `'scripts/run.sh'` (상대 경로, `/` 구분, 정렬), `problem==null`, `skillMd` 원문 그대로
  - `noSkillMd`: `skills/b/` 빈 폴더 → `name=='b'`, `problem.kind==noSkillMd`
  - `badFrontmatter`: 머리말 없는 `SKILL.md` → `name==폴더이름`, `problem.kind==badFrontmatter`, `skillMd`는 채워짐
  - `linkedSkill`: `skills/c` → 다른 임시 폴더로 `Link` → 정상 스킬, `linkTarget`이 실제 경로
  - `brokenLink`: 없는 경로를 가리키는 `Link` → `problem.kind==brokenLink`, `linkTarget` 채워짐
  - `synced`: `skills/synced/acc1/docx/SKILL.md` → 항목 하나, `name=='synced'`, `source==synced`, `description=='claude.ai에서 동기화된 스킬 폴더'`, `problem==null`, `files`에 `'acc1/docx/SKILL.md'`
  - `noSkillsDir`: `skills/` 없음 → `skills` 비어 있고 예외 없음
  - `classifyFsError`: `FileSystemException('x', 'p', OSError('', 1))` → `noPermission`, 코드 13 → `noPermission`, 코드 2 → `unreadable`
  - `fileSkippedAtTopLevel`: `skills/.DS_Store` 파일은 무시
- [ ] **Step 2: 실패 확인** — `flutter test test/scan/skill_scanner_test.dart`
- [ ] **Step 3: 구현** — `skills/`의 직속 항목 중 폴더나 폴더 링크만 본다. 링크는 `Link.target`을 상대 경로면 링크 위치 기준으로 풀어 `linkTarget`에 넣고, 대상이 없으면 `brokenLink`. 파일 목록은 `list(recursive: true, followLinks: false)`. `FileSystemException`은 `classifyFsError`로 문제를 만든다. 문제 메시지:
  - `noSkillMd`: `SKILL.md가 없습니다`
  - `badFrontmatter`: `SKILL.md 머리말을 읽을 수 없습니다`
  - `noPermission`: `읽을 수 없음, 폴더 권한 필요`
  - `brokenLink`: `링크가 가리키는 폴더가 없습니다`
  - `unreadable`: `읽을 수 없습니다: <OSError 메시지>`
- [ ] **Step 4: 통과 확인**
- [ ] **Step 5: 커밋** — `"전역·동기화 스킬 스캔"`

### Task 3: 플러그인 스캔

**Files:**
- Modify: `lib/scan/skill_scanner.dart`
- Test: `test/scan/skill_scanner_test.dart` (추가)

**Interfaces:**
- Consumes: `readSkillDir`
- Produces: `scanClaude`가 플러그인 스킬도 포함 (`source==plugin`, `plugin=="<이름>@<마켓>"`, `pluginVersion`, `pluginEnabled`, `projectPath`)

`installed_plugins.json` 형식: `{"version":2,"plugins":{"<이름>@<마켓>":[{"scope":"user","installPath":"...","version":"1.0.0"}]}}`. `settings.json`: `{"enabledPlugins":{"<이름>@<마켓>":true}}`.

프로젝트 범위 항목의 프로젝트 경로 필드는 실제 데이터로 확인하지 못했다(이 기기는 user 항목만 있음). `projectPath` 키를 읽고, 없으면 `projectPath == null`로 두되 스킬은 그대로 보여준다. 구현 전에 Claude Code 문서나 다른 기기 데이터로 키 이름을 확인할 수 있으면 확인한다.

- [ ] **Step 1: 실패하는 테스트 작성** (테스트에서 `installPath`는 임시 폴더 절대 경로)
  - `enabledPlugin`: 켜진 플러그인의 `skills/x/SKILL.md` → `source==plugin`, `plugin=='p@m'`, `pluginVersion=='1.0.0'`
  - `enabledPlugin`에 `pluginEnabled == true` 추가
  - `disabledPlugin`: `enabledPlugins` 값 `false` 또는 키 없음 → 스킬은 나오고 `pluginEnabled == false`
  - `projectScope`: `scope:"project"`, `projectPath:"/w/app"` 항목 → 스킬 나옴, `projectPath == '/w/app'`, `pluginEnabled == null`
  - `projectScopeNoPath`: `projectPath` 키 없음 → 스킬 나옴, `projectPath == null`
  - `noSettings`: `settings.json` 없음 → 플러그인 스킬 나오고 `pluginEnabled == null`, `notices`에 `'settings.json을 읽지 못해 플러그인 켜짐 여부를 알 수 없습니다'`
  - `oldVersions`: `cache/m/p/0.9.0/`, `cache/m/p/1.0.0/`(installPath) → `0.9.0` 스킬은 안 나오고 `notices`에 `'플러그인 옛 버전 폴더 1개가 남아 있습니다'`. 옛 버전이 0개면 notice 없음
  - `noInstalledJson`: 파일 없음 → 전역 스킬만, notice 없음 (플러그인 미설치는 정상)
  - `badInstalledJson`: 깨진 JSON → 전역 스킬은 나오고 `notices`에 `'installed_plugins.json을 읽지 못했습니다'`
  - `missingInstallPath`: `installPath` 폴더 없음 → `notices`에 `'p@m 플러그인 폴더가 없습니다'`
  - `pluginWithoutSkills`: `installPath`는 있지만 `skills/` 없음 → 스킬 0개, notice 없음
  - `sameNameGlobalAndPlugin`: 전역 `a`와 플러그인 `a` → 둘 다 나옴
- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현** — `dart:convert`의 `jsonDecode`. 형식이 예상과 다르면(타입 불일치) `badInstalledJson`과 같은 notice.
- [ ] **Step 4: 통과 확인** — `flutter test test/scan/`
- [ ] **Step 5: 커밋** — `"플러그인 스킬 스캔 (켜진 user 플러그인만)"`

### Task 4: 폴더 권한 (macOS 북마크, Windows)

**Files:**
- Create: `lib/access/folder_access.dart`, `lib/access/macos_folder_access.dart`, `macos/Runner/FolderAccessChannel.swift`
- Modify: `macos/Runner/MainFlutterWindow.swift`, `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements`, `pubspec.yaml` (`flutter pub add file_selector`)
- Test: `test/access/folder_access_test.dart`

**Interfaces:**
- Produces:
  - `abstract class FolderAccess { Future<Directory?> restore(); Future<Directory?> pickClaudeDir(); Future<bool> grantFolder(String suggestedPath); Future<bool> reduceTransparency(); }`
    - `restore`: 저장된 `.claude` 권한 복원 (추가 허락 폴더도 함께 복원), 없으면 `null`
    - `pickClaudeDir`: 폴더 선택 창. 고른 폴더가 `isClaudeDir`이 아니면 북마크를 저장하지 않고 `null`. 취소도 `null`
    - `grantFolder`: 링크 대상 폴더를 추가 허락
  - `FolderAccess createFolderAccess()` — `Platform.isMacOS`면 `MacosFolderAccess`, 아니면 `HomeFolderAccess`
  - `class HomeFolderAccess implements FolderAccess` — `restore`는 `%USERPROFILE%\.claude`(없으면 `HOME`) 반환, `grantFolder`는 `true`, `reduceTransparency`는 `false`
  - `Future<bool> isClaudeDir(Directory d)` — `skills/` 또는 `plugins/`가 있으면 `true`
  - MethodChannel 이름 `skill_gui/folder_access`, 메서드: `realHome() -> String`, `saveBookmark(path) -> bool`, `restoreBookmarks() -> List<String>` (복원·접근 시작에 성공한 경로들, 첫 번째가 `.claude`), `reduceTransparency() -> bool`

- [ ] **Step 1: `flutter pub add file_selector`** 실행
- [ ] **Step 2: 실패하는 테스트 작성** — `isClaudeDir`: `skills/`만 → true, `plugins/`만 → true, 둘 다 없음 → false. `HomeFolderAccess.grantFolder` → true
- [ ] **Step 3: 실패 확인 후 Dart 구현** — `MacosFolderAccess.pickClaudeDir`는 `getDirectoryPath(initialDirectory: '<realHome>/.claude', confirmButtonText: '허락')`
- [ ] **Step 4: Swift 구현** — `FolderAccessChannel.register(with: FlutterViewController)`을 `MainFlutterWindow.awakeFromNib`의 `RegisterGeneratedPlugins` 다음에 호출
  - `realHome`: `getpwuid(getuid()).pw_dir` (샌드박스에서 `NSHomeDirectory()`는 컨테이너 경로라서)
  - `saveBookmark`: `URL.bookmarkData(options: .withSecurityScope)`를 `UserDefaults` 키 `folderBookmarks`(`[String: Data]`, 경로가 키)에 저장. 저장 직후 `startAccessingSecurityScopedResource()`
  - `restoreBookmarks`: 저장된 순서대로 `URL(resolvingBookmarkData:options:.withSecurityScope, bookmarkDataIsStale:)` → `startAccessing…`. stale이면 새 북마크로 다시 저장. 실패한 항목은 지우고 결과에서 뺀다. `.claude` 북마크가 먼저 오도록 키 `claudeDir`를 따로 둔다
  - `reduceTransparency`: `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency`
- [ ] **Step 5: entitlements 두 파일에 두 키 추가** (`<true/>`)
- [ ] **Step 6: 통과 확인** — `flutter test test/access/`, 그리고 `flutter build macos --debug`가 성공
- [ ] **Step 7: 커밋** — `"폴더 권한: macOS 북마크 채널, Windows 홈 폴더"`

### Task 5: 리퀴드 글래스 공통 위젯과 목록 화면

**Files:**
- Create: `lib/ui/glass.dart`, `lib/ui/skill_list_page.dart`
- Test: `test/ui/skill_list_page_test.dart`

**Interfaces:**
- Consumes: `ScanResult`, `Skill`, `SkillSource`
- Produces:
  - `class GlassBackground extends StatelessWidget { final Widget child; }` — 시안 배경 `#DCE3EE` 위 흐린 원 3개(`#9DB8F2`, `#F3C6A8`, `#B9E3D3`)
  - `class GlassPanel extends StatelessWidget { final Widget child; final double radius; }` — `BackdropFilter(ImageFilter.blur(28, 28))` + `rgba(255,255,255,0.42)`. 조상의 `ReduceTransparency.of(context)`가 true면 블러 없이 `#F4F6FA`
  - `class ReduceTransparency extends InheritedWidget { final bool value; static bool of(BuildContext) }`
  - `class SkillListPage extends StatefulWidget { final ScanResult result; final Future<void> Function() onRescan; final void Function(Skill) onOpen; }`
  - `enum SourceFilter { all, global, plugin, disabled }` — `plugin`에는 `SkillSource.plugin` 전부(꺼짐 포함), `global`에는 `global`과 `synced`, `disabled`에는 `pluginEnabled == false`만

- [ ] **Step 1: 실패하는 위젯 테스트 작성** (스킬 4개: 전역 a, 플러그인 b(`p@m`), 문제 있는 c, 꺼진 플러그인 d(`q@m`), 프로젝트 범위 플러그인은 별도 케이스)
  - 카드 4개, 이름 `a`·`b`·`c`·`d`가 보임
  - 사이드바에 `Claude Code`와 개수 `4`
  - `플러그인` 필터 탭 → `b`·`d`
  - `꺼짐` 필터 탭 → `d`만, `d` 카드에 `꺼짐` 표시
  - `projectPath: '/w/app'`인 플러그인 스킬 카드에 `/w/app`이 보임
  - `c` 카드에 `읽을 수 없음, 폴더 권한 필요`가 보임
  - 출처 태그: 전역 `전역`, 플러그인 `p@m`, synced `동기화`
  - `다시 스캔` 탭 → `onRescan` 호출됨
  - `notices`가 있으면 목록 위에 문구가 보임
  - `ReduceTransparency(value: true)`로 감싸면 `BackdropFilter`가 없음
- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현** — 카드는 불투명 흰색(0.86), 반지름 22, 설명은 `maxLines: 3`. 그리드는 `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 320)`. 제목 `Claude Code 스킬`. 버튼·탭 영역 높이 44 이상
- [ ] **Step 4: 통과 확인**
- [ ] **Step 5: 커밋** — `"리퀴드 글래스 목록 화면"`

### Task 6: 상세 화면과 폴더 허락 화면

**Files:**
- Create: `lib/ui/skill_detail_page.dart`, `lib/ui/access_page.dart`
- Test: `test/ui/skill_detail_page_test.dart`, `test/ui/access_page_test.dart`

**Interfaces:**
- Consumes: `Skill`, `GlassBackground`, `GlassPanel`
- Produces:
  - `class SkillDetailPage extends StatelessWidget { final Skill skill; final Future<void> Function(String path)? onGrantFolder; }` — `onGrantFolder`가 null이면 허락 버튼을 숨긴다 (Windows)
  - `class AccessPage extends StatefulWidget { final Future<Directory?> Function() onPick; final void Function(Directory) onGranted; }`

- [ ] **Step 1: 실패하는 테스트 작성**
  - 상세: 이름, 출처 태그, `path`, 설명, `SKILL.md 원문` 제목과 원문, `포함된 파일` 목록이 보임
  - 상세: `noPermission` 스킬 + `onGrantFolder` 있음 → `폴더 추가 허락` 버튼, 탭하면 `linkTarget`의 상위 폴더 경로로 호출
  - 상세: `onGrantFolder == null` → 버튼 없음
  - 상세: `skillMd == null` → 원문 대신 문제 메시지
  - 상세: 꺼진 플러그인 스킬 → `꺼짐` 표시, 프로젝트 범위면 프로젝트 경로 표시
  - 허락: `onPick`이 `null` 반환 → `Claude Code 설정 폴더(.claude)를 골라 주세요` 안내가 보이고 `onGranted` 호출 안 됨
  - 허락: `onPick`이 폴더 반환 → `onGranted` 호출
- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현** — 허락 화면 문구: 제목 `Claude Code 스킬 폴더를 허락해 주세요`, 본문 `홈 폴더의 .claude 폴더를 고르면 스킬을 읽습니다. 숨김 폴더가 안 보이면 ⌘⇧. 을 누르세요. 파일은 읽기만 합니다.`, 버튼 `폴더 고르기`. 상세 원문은 고정폭 글꼴, 선택 가능(`SelectableText`)
- [ ] **Step 4: 통과 확인**
- [ ] **Step 5: 커밋** — `"스킬 상세와 폴더 허락 화면"`

### Task 7: 앱 연결과 실제 확인

**Files:**
- Modify: `lib/main.dart` (카운터 앱 전체 대체)
- Modify: `test/widget_test.dart` (카운터 테스트 → 앱 시작 스모크 테스트)

**Interfaces:**
- Consumes: `createFolderAccess`, `scanClaude`, `AccessPage`, `SkillListPage`, `SkillDetailPage`, `ReduceTransparency`
- Produces: `class SkillGuiApp extends StatefulWidget { final FolderAccess access; final Future<ScanResult> Function(Directory) scan; }` — 테스트에서 가짜를 넣을 수 있게 주입

흐름: `restore()` → `null`이면 `AccessPage` → 디렉터리 확보 → `scan` → `SkillListPage`. 카드 탭 → `Navigator.push(SkillDetailPage)`. 상세에서 폴더 허락 성공 시 다시 스캔. 스캔 중에는 로딩 표시. `reduceTransparency()` 값을 `ReduceTransparency`로 앱 전체에 내린다.

- [ ] **Step 1: 스모크 테스트 작성** — 가짜 `FolderAccess`(restore → 임시 폴더)와 가짜 `scan`(스킬 1개) → 카드 이름이 보임. restore → null → `폴더 고르기` 버튼이 보임
- [ ] **Step 2: 실패 확인 후 구현**
- [ ] **Step 3: 전체 테스트** — test-runner 에이전트로 `flutter test` → 전부 PASS
- [ ] **Step 4: 실제 실행 확인 (macOS)** — `flutter run -d macos`
  - 첫 실행: 허락 화면 → `~/.claude` 선택 → 목록에 전역 스킬, `synced` 항목 하나, 플러그인 스킬이 보임. 옛 버전 폴더 알림이 보임 (superpowers 등 캐시에 옛 버전이 있으면)
  - `/plugin`으로 플러그인 하나를 끄고 `다시 스캔` → 그 플러그인 스킬에 `꺼짐` 표시
  - `computer-use`·`orca-cli`·`orchestration`이 `읽을 수 없음, 폴더 권한 필요` → 상세에서 `폴더 추가 허락` → `~/.agents/skills` 선택 → 정상으로 바뀜
  - 앱 재시작: 허락 화면 없이 바로 목록 (북마크 복원)
  - 시스템 설정 > 손쉬운 사용 > 투명도 줄이기 켜고 재시작 → 사이드바가 불투명
- [ ] **Step 5: 커밋** — `"앱 시작 흐름 연결: 권한 → 스캔 → 목록·상세"`

Windows 실기 확인은 이 Mac에서 할 수 없다. 남은 확인 항목으로 타임라인에 적는다.
