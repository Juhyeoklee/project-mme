#!/bin/bash
# 실기기 배포 — 기기 조회 → 빌드 → 설치 → 실행.
#
# 사용법:
#   scripts/deploy-device.sh                   연결된 기기가 하나면 그 기기로
#   scripts/deploy-device.sh <이름|UDID 일부>   여러 대 중 하나를 고를 때 (예: iPad)
#   scripts/deploy-device.sh --build-only      기기 없이 빌드까지만
#
# 전제 — 기기당 1회, 사람 손 (스크립트가 못 줄인다):
#   기기의 개발자 모드 켜짐 · 이 Mac과 페어링 · 개발자 앱 신뢰.
#   서명은 -allowProvisioningUpdates 가 처리한다 (인증서가 키체인에 있어야 한다).
#
# 검증 상태 (2026-08-04 셋업 세션): 빌드까지는 기기 없이 검증됐다.
# 설치·실행 단계는 다음 실기기 세션이 첫 사용에서 검증한다 — 어긋나면 이 주석을 고칠 것.
set -euo pipefail

APPLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$APPLE_DIR/DerivedData/device"
BUNDLE_ID="dev.placeholder.moanogi"
UUID_RE='[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'

FILTER="${1:-}"

# ── 1. 기기 결정 (빌드보다 먼저 — 기기가 없으면 빨리 실패한다)
UDID=""
if [ "$FILTER" != "--build-only" ]; then
  LIST="$(xcrun devicectl list devices)"
  if [ -n "$FILTER" ]; then
    MATCHES="$(printf '%s\n' "$LIST" | grep -iE "$UUID_RE" | grep -i -- "$FILTER" || true)"
  else
    # 상태 열 앞 공백으로 가른다 — 'available'만 쓰면 'unavailable'까지 문다. Watch는 iOS 앱이 못 간다
    MATCHES="$(printf '%s\n' "$LIST" | grep -vi 'watch' | grep -i ' connected' || true)"
    # USB 연결이 없으면 무선 페어링(available)까지 넓힌다
    [ -z "$MATCHES" ] && MATCHES="$(printf '%s\n' "$LIST" | grep -vi 'watch' | grep -i ' available' || true)"
  fi
  COUNT="$(printf '%s\n' "$MATCHES" | grep -cE "$UUID_RE" || true)"
  if [ "$COUNT" -ne 1 ]; then
    echo "기기를 하나로 정하지 못했다 (후보 ${COUNT}대). 이름이나 UDID 일부를 인자로 줘라:" >&2
    printf '%s\n' "$LIST" >&2
    exit 2
  fi
  UDID="$(printf '%s\n' "$MATCHES" | grep -oE "$UUID_RE" | head -1)"
  echo "▸ 기기: $(printf '%s\n' "$MATCHES" | head -1 | sed 's/  */ /g')"
fi

# ── 2. 빌드 (generic — 한 번 빌드한 산출물을 어느 기기에든 설치한다)
echo "▸ 빌드"
xcodebuild build \
  -project "$APPLE_DIR/Moanogi.xcodeproj" -scheme Moanogi \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  -derivedDataPath "$DERIVED" \
  -quiet

APP="$DERIVED/Build/Products/Debug-iphoneos/Moanogi.app"
[ -d "$APP" ] || { echo "빌드 산출물이 없다: $APP" >&2; exit 1; }
echo "▸ 산출물: $APP"

[ "$FILTER" = "--build-only" ] && exit 0

# ── 3. 설치 → 4. 실행
echo "▸ 설치"
xcrun devicectl device install app --device "$UDID" "$APP"
echo "▸ 실행"
xcrun devicectl device process launch --device "$UDID" --terminate-existing "$BUNDLE_ID"
