#!/usr/bin/env bash
# PreToolUse(Bash) 훅: 되돌리기 어려운 명령을 exit 2로 막는다. Claude Code와 Codex가 함께 쓴다.
# shortcut: `bash -c "..."`, `eval`처럼 문자열 안에 감춘 명령은 못 잡는다. 우회가 문제 되면 파서를 강화한다.
cmd=$(jq -r '.tool_input.command // empty')

block() {
  echo "차단됨: $1 — 사용자에게 직접 실행을 요청할 것" >&2
  exit 2
}

# 명령 구분자(; & | ( ) `)와 줄바꿈 기준으로 나눠 각 명령의 첫 단어를 본다.
while read -r -a w; do
  i=0
  while [[ ${w[i]} == sudo || ${w[i]} == *=* ]]; do ((i++)); done
  case ${w[i]##*/} in
    git | docker)
      j=$((i + 1))
      # git -C <경로>, docker --context <이름> 같은 전역 옵션을 건너뛴다.
      while [[ ${w[j]} == -* ]]; do
        case ${w[j]} in -C | -c | --context | --config | -H | --host) ((j += 2)) ;; *) ((j++)) ;; esac
      done
      if [[ ${w[j]} == push ]]; then
        [[ ${w[i]##*/} == docker ]] && block "docker push"
        ask=1
      fi
      ;;
    rm)
      r=0 f=0
      for a in "${w[@]:i+1}"; do
        case $a in
          --recursive) r=1 ;;
          --force) f=1 ;;
          --*) ;;
          -*) [[ $a == *[rR]* ]] && r=1; [[ $a == *f* ]] && f=1 ;;
        esac
      done
      ((r && f)) && block "rm -rf"
      ;;
  esac
done < <(printf '%s\n' "$cmd" | tr ';&|()`' '\n\n\n\n\n\n')

# git push는 막지 않고 실행 전에 사용자에게 한 번 묻는다. 같은 명령에 막을 명령이 섞이면 위에서 먼저 막힌다.
if [[ $ask ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"git push 실행 전 사용자 확인"}}'
fi
exit 0
