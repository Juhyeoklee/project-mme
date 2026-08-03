#!/bin/bash
# 경계 검증기의 에이전트 루프 진입점 (ADR 0003).
#
# Claude Code PostToolUse 훅이 부른다 — 에이전트가 apple/ 안의 Swift 파일을
# 수정한 직후. 검사 항목은 verify-boundaries.swift의 3항목 그대로다.
# 여기서 항목을 늘리지 않는다 (ADR 0001 결정 4) — 이 스크립트는 시점만 옮긴다.
#
# 동작 — 알림이지 차단이 아니다:
#   위반이면 exit 2. stderr가 에이전트에게 돌아가 그 자리에서 스스로 고친다.
#   수정 자체는 이미 일어난 뒤다. 최종 강제는 컴파일러와 CI가 맡는다.
#   우회 변수는 없다 — 오탐이면 검증기의 금지 명단을 고친다 (diff에 남는다).
#
# 배선은 저장소 밖에 있다 — 세션 루트의 .claude/settings.json. 내용은 ADR 0003에.

apple_root="$(cd "$(dirname "$0")/.." && pwd -P)"

# stdin JSON에서 수정된 파일 경로만 뽑는다. jq 의존을 들이지 않는다 —
# 경로 추출 하나에 도구를 더하는 것은 ADR 0001 근거 4의 잣대를 통과하지 못한다.
file_path="$(cat | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4)"

# 양쪽을 물리 경로로 맞춘 뒤 비교한다. 프리픽스 비교는 심볼릭 링크 등으로
# 표기가 갈리면 조용한 미탐이 된다 — 미탐은 조용히 도구를 죽인다 (검증기 헤더).
# 디렉터리가 없으면(파일 삭제 등) 원문 그대로 비교로 물러난다.
file_dir="$(cd "$(dirname "$file_path")" 2>/dev/null && pwd -P)"
[ -n "$file_dir" ] && file_path="$file_dir/$(basename "$file_path")"

# apple/ 안의 Swift 파일이 아니면 검사하지 않는다. 문서·워크스페이스 편집에 침묵.
case "$file_path" in
    "$apple_root"/*.swift) ;;
    *) exit 0 ;;
esac

output="$(cd "$apple_root" && swift scripts/verify-boundaries.swift 2>&1)"
if [ $? -ne 0 ]; then
    echo "$output" >&2
    exit 2
fi
exit 0
