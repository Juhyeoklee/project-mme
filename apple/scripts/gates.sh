#!/bin/bash
# 게이트 전량. CI와 에이전트가 **같은 파일**을 부른다.
#
# 사본을 만들지 않으려고 스크립트로 뺐다 — 명령이 ci.yml과 CLAUDE.md에
# 두 벌로 살면 한쪽이 낡고, 낡은 쪽으로 돈 세션은 초록을 잘못 믿는다.
#
# 층을 안 섞는다: 게이트 여섯은 CI가 막는 것이고, 대조 넷은 grep 한 줄짜리
# 사실 확인이다. 출력이 갈려 있는 것이 요점이다.

set -uo pipefail

apple_root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$apple_root" || exit 1

failed=()

# 한 게이트를 돌리고 결과만 남긴다. 실패했을 때만 출력을 편다.
gate() {
    local name="$1"; shift
    local out
    if out="$("$@" 2>&1)"; then
        printf '  ✅ %s\n' "$name"
    else
        printf '  ❌ %s\n' "$name"
        printf '%s\n' "$out" | tail -40 | sed 's/^/     /'
        failed+=("$name")
    fi
}

echo "── 게이트 여섯 ──"

gate "경계 검증기" swift scripts/verify-boundaries.swift
gate "커널 테스트" swift test --package-path Packages/MomentKernel
gate "PhotoSource 테스트" swift test --package-path Packages/PhotoSource
gate "iOS 빌드" xcodebuild build -project Moanogi.xcodeproj -scheme Moanogi \
    -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO

# macOS는 시뮬레이터가 없어 빌드만 돈다.
gate "macOS 빌드" xcodebuild build -project Moanogi.xcodeproj -scheme Moanogi \
    -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO

# 앱 테스트는 시뮬레이터를 실제로 띄운다 — generic 목적지로는 안 돈다.
# 기기 이름은 러너 이미지마다 다르므로 iOS 26+ 중 마지막 iPhone을 골라 쓴다.
sim="$(xcrun simctl list devices available |
    awk '/^-- iOS 2[6-9]/{ok=1;next} /^--/{ok=0} ok && /iPhone/{gsub(/ \(.*/,"");gsub(/^ +/,"");n=$0} END{print n}')"
if [ -z "$sim" ]; then
    echo "  ❌ 앱 테스트 — iOS 26+ 시뮬레이터가 없다"
    failed+=("앱 테스트")
else
    gate "앱 테스트 ($sim)" xcodebuild test -project Moanogi.xcodeproj -scheme Moanogi \
        -destination "platform=iOS Simulator,name=$sim" CODE_SIGNING_ALLOWED=NO
fi

echo
echo "── 기계 대조 넷 (docs/rules.md · 전부 0) ──"

# 넷 다 grep 한 줄이고 자가 틀릴 여지가 없다 — 그게 선정 기준이다.
# 여기서 항목을 늘리지 않는다. 길이를 세는 자는 네 번 틀렸다(rules.md).
check() {
    local name="$1" out
    out="$(eval "$2")"
    if [ -z "$out" ]; then
        printf '  ✅ %s\n' "$name"
    else
        printf '  ❌ %s — %s건\n' "$name" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
        printf '%s\n' "$out" | sed 's/^/     /'
        failed+=("$name")
    fi
}

check "산출물 문서 절 참조" \
    "grep -rn '§' --include='*.swift' . | grep -v '/.build/' | grep -vE '(\`[a-z0-9-]+\`|실험) §'"
check "프로토콜·actor" \
    "grep -rnE '^ *(public )?(protocol|actor) ' --include='*.swift' --exclude-dir=.build ."
check "커널 throws" \
    "grep -rn 'throws' Packages/MomentKernel/Sources"
check "이름 없는 유틸 파일" \
    "find . -name 'Utils.swift' -o -name 'Helpers.swift' -o -name 'Common.swift' -o -name 'Extensions.swift'"

echo
if [ ${#failed[@]} -eq 0 ]; then
    echo "✅ 전부 통과"
    exit 0
fi
printf '❌ 실패 %d — %s\n' "${#failed[@]}" "$(IFS='·'; echo "${failed[*]}")"
exit 1
