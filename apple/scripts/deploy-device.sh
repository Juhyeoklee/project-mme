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
# 전제 — **매번**: 실행 단계는 기기 잠금이 풀려 있어야 한다. 설치는 잠긴 채로도 된다.
#
# 검증 상태: 빌드는 기기 없이 (2026-08-04 셋업), **설치·실행은 실사용으로** (2026-08-07 세션 C2 —
# 무선 페어링 경로로 붙었다).
set -euo pipefail

APPLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$APPLE_DIR/DerivedData/device"
UUID_RE='[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'

FILTER="${1:-}"

# ── 1. 기기 결정 (빌드보다 먼저 — 기기가 없으면 빨리 실패한다)
UDID=""
if [ "$FILTER" != "--build-only" ]; then
  LIST="$(xcrun devicectl list devices)"
  # 이름 필터를 **먼저** 걸고 상태로 좁힌다. 순서가 뒤바뀌면 지목한 기기가 무선인데 다른 기기가
  # USB로 붙어 있을 때 후보가 0이 된다. 상태 필터를 공통으로 뽑은 것은 이름 필터 경로에만
  # 상태 검사가 없어서 꺼진 기기까지 물었기 때문이다 (2026-08-07 실물 목록).
  POOL="$(printf '%s\n' "$LIST" | grep -iE "$UUID_RE" | grep -vi 'watch' || true)"  # Watch는 iOS 앱이 못 간다
  [ -n "$FILTER" ] && POOL="$(printf '%s\n' "$POOL" | grep -i -- "$FILTER" || true)"
  # 상태 열 앞 공백으로 가른다 — 'available'만 쓰면 'unavailable'까지 문다(2026-08-04 실물 목록)
  MATCHES="$(printf '%s\n' "$POOL" | grep -i ' connected' || true)"
  # USB 연결이 없으면 무선 페어링(available)까지 넓힌다
  [ -z "$MATCHES" ] && MATCHES="$(printf '%s\n' "$POOL" | grep -i ' available' || true)"
  COUNT="$(printf '%s\n' "$MATCHES" | grep -cE "$UUID_RE" || true)"
  if [ "$COUNT" -ne 1 ]; then
    echo "기기를 하나로 정하지 못했다 (후보 ${COUNT}대). 이름이나 UDID 일부를 인자로 줘라:" >&2
    printf '%s\n' "$LIST" >&2
    exit 2
  fi
  UDID="$(printf '%s\n' "$MATCHES" | grep -oE "$UUID_RE" | head -1)"
  echo "▸ 기기: $(printf '%s\n' "$MATCHES" | head -1 | sed 's/  */ /g')"
fi

# ── 2. 빌드 (기기를 지목한다 — generic으로 빌드하면 그 기기가 프로파일에 안 들어가
#           새 기기에서 설치가 거부된다. 구현 5가 겪고 구현 7이 원인을 확인했다)
DEST="generic/platform=iOS"
if [ -n "$UDID" ]; then DEST="id=$UDID"; fi
echo "▸ 빌드"
xcodebuild build \
  -project "$APPLE_DIR/Moanogi.xcodeproj" -scheme Moanogi \
  -destination "$DEST" \
  -allowProvisioningUpdates \
  -derivedDataPath "$DERIVED" \
  -quiet

APP="$DERIVED/Build/Products/Debug-iphoneos/Moanogi.app"
[ -d "$APP" ] || { echo "빌드 산출물이 없다: $APP" >&2; exit 1; }
# 번들 ID는 **지어진 앱에서 읽는다** — 박아 두면 팀·번들을 바꿔 빌드했을 때 설치는 되고
# 실행만 조용히 엉뚱한 앱을 찾는다 (2026-08-19: 개인 팀 기기 상한에 걸려 계정을 바꿨다).
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
echo "▸ 산출물: $APP ($BUNDLE_ID)"

[ "$FILTER" = "--build-only" ] && exit 0

# ── 3. 설치 → 4. 실행
echo "▸ 설치"
xcrun devicectl device install app --device "$UDID" "$APP"
echo "▸ 실행"
# 여기서만 기기 잠금이 걸린다. 설치는 이미 끝났으므로 **앱은 기기에 들어가 있고**,
# 손으로 열어도 같은 결과다 — 실패를 통째로 실패로 읽지 않게 그 사실을 말해준다.
# 실패 원인이 둘인데 메시지가 하나였다 — 잠금과 **미신뢰 프로파일**은 손이 할 일이 다르다
# (2026-08-19: 계정을 바꾸자 새 팀에 대한 신뢰가 없어 막혔는데 「잠금을 풀어라」가 나갔다).
if ! LAUNCH="$(xcrun devicectl device process launch \
     --device "$UDID" --terminate-existing "$BUNDLE_ID" 2>&1)"; then
  printf '%s\n' "$LAUNCH" >&2
  echo "" >&2
  echo "실행만 실패했다 — 설치는 끝났으니 앱은 기기에 있다." >&2
  case "$LAUNCH" in
    *"not been explicitly trusted"*|*"invalid code signature"*)
      echo "기기가 이 개발자를 아직 안 믿는다 — 팀을 바꿨으면 다시 줘야 한다." >&2
      echo "  설정 → 일반 → VPN 및 기기 관리 → 개발자 앱 → 그 계정 → 신뢰" >&2 ;;
    *Locked*)
      echo "기기가 잠겨 있다. 잠금을 풀고 다시 돌리거나 앱을 직접 열어라." >&2 ;;
    *)
      echo "위 메시지를 읽어라. 앱을 직접 열어도 같은 결과다." >&2 ;;
  esac
  exit 3
fi
printf '%s\n' "$LAUNCH"
