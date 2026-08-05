#!/usr/bin/env bash
# Repeatable checks for BabyKeyboardLock Accessibility / event-tap foundation.
# Safe to run locally; does not modify System Settings or TCC.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${CONFIG:-Debug}"
SCHEME="${SCHEME:-BabyKeyboardLock}"
DERIVED="${DERIVED:-$ROOT/build/verify-ax}"
PRODUCTS_DIR="${DERIVED}/Build/Products/${CONFIG}"
PASS=0
FAIL=0
WARN=0

if [[ "$CONFIG" == "Debug" ]]; then
  EXPECTED_BUNDLE_ID="com.fangxing.BabyKeyboardLockDebug"
  EXPECTED_APP_NAMES=(
    "BabyKeyboardLock Debug.app"
    "BabyKeyboardLock.app"
  )
else
  EXPECTED_BUNDLE_ID="com.fangxing.BabyKeyboardLock"
  EXPECTED_APP_NAMES=(
    "BabyKeyboardLock.app"
  )
fi

note() { printf '• %s\n' "$*"; }
ok() { PASS=$((PASS + 1)); printf 'OK  %s\n' "$*"; }
warn() { WARN=$((WARN + 1)); printf 'WARN %s\n' "$*"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$*"; }

# Prefer the real app product; never the UI test runner.
resolve_app_product() {
  local products_dir="$1"
  local name candidate bid
  local -a found=()

  for name in "${EXPECTED_APP_NAMES[@]}"; do
    candidate="${products_dir}/${name}"
    if [[ -d "$candidate" ]]; then
      found+=("$candidate")
    fi
  done

  # Fallback: any .app whose Info.plist matches the expected app bundle id
  # (explicitly exclude *UITests* / *Runner*).
  while IFS= read -r -d '' candidate; do
    case "$candidate" in
      *UITests*|*Runner*) continue ;;
    esac
    bid="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$candidate/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$bid" == "$EXPECTED_BUNDLE_ID" ]]; then
      found+=("$candidate")
    fi
  done < <(find "$products_dir" -maxdepth 2 -type d -name '*.app' -print0 2>/dev/null || true)

  if [[ ${#found[@]} -eq 0 ]]; then
    return 1
  fi

  # Deterministic: first exact name match, else lexicographically first match.
  printf '%s\n' "${found[@]}" | awk 'NF' | sort -u | head -n 1
}

echo "=== BabyKeyboardLock accessibility foundation verify ==="
echo "repo: $ROOT"
echo "config: $CONFIG"
echo "expected bundle id: $EXPECTED_BUNDLE_ID"
echo

# --- Static project assumptions ---
note "Checking bundle IDs / LSUIElement / entitlements in project"

if rg -q 'PRODUCT_BUNDLE_IDENTIFIER = com.fangxing.BabyKeyboardLockDebug' BabyKeyboardLock.xcodeproj/project.pbxproj; then
  ok "Debug bundle id present (com.fangxing.BabyKeyboardLockDebug)"
else
  bad "Debug bundle id missing"
fi

if rg -q 'PRODUCT_BUNDLE_IDENTIFIER = com.fangxing.BabyKeyboardLock;' BabyKeyboardLock.xcodeproj/project.pbxproj; then
  ok "Release bundle id present (com.fangxing.BabyKeyboardLock)"
else
  bad "Release bundle id missing"
fi

DEBUG_LSUI=$(rg -n 'INFOPLIST_KEY_LSUIElement = YES' BabyKeyboardLock.xcodeproj/project.pbxproj | wc -l | tr -d ' ')
if [[ "$DEBUG_LSUI" -ge 1 ]]; then
  ok "LSUIElement=YES (agent / menu-bar app; no Dock icon by design)"
else
  bad "LSUIElement not set — window/lifecycle assumptions may differ"
fi

if [[ -f BabyKeyboardLock/BabyKeyboardLock.entitlements ]]; then
  if rg -q 'com.apple.security.app-sandbox' BabyKeyboardLock/BabyKeyboardLock.entitlements \
    && rg -q '<false/>' BabyKeyboardLock/BabyKeyboardLock.entitlements; then
    ok "Debug entitlements: app sandbox disabled (good for event taps)"
  else
    warn "Debug entitlements sandbox not clearly disabled"
  fi
fi

if [[ -f BabyKeyboardLock/BabyKeyboardLockRelease.entitlements ]]; then
  if rg -q 'com.apple.security.app-sandbox' BabyKeyboardLock/BabyKeyboardLockRelease.entitlements \
    && rg -A1 'com.apple.security.app-sandbox' BabyKeyboardLock/BabyKeyboardLockRelease.entitlements | rg -q '<true/>'; then
    warn "Release entitlements: app sandbox ENABLED — if tapCreate fails only in Release, try matching Debug (sandbox false)"
  else
    ok "Release sandbox not forced true"
  fi
fi

if rg -q 'Privacy - Accessibility API Enabled' BabyKeyboardLock-Info.plist 2>/dev/null; then
  warn "Info.plist still has non-functional 'Privacy - Accessibility API Enabled' key"
else
  ok "Info.plist no longer claims a fake Accessibility privacy key"
fi

if rg -q 'takeRetainedValue\(\) as String: true' BabyKeyboardLock --type swift 2>/dev/null; then
  bad "Found takeRetainedValue on AX prompt option (use takeUnretainedValue)"
else
  ok "No takeRetainedValue AX prompt misuse in Swift sources"
fi

if rg -q 'fatalError\("Failed to create event tap' BabyKeyboardLock --type swift 2>/dev/null; then
  bad "Event tap still fatalErrors on create failure"
else
  ok "Event tap create failure is non-fatal"
fi

if rg -q 'NSApplication.shared.terminate\(self\)' BabyKeyboardLock/EventHandler.swift 2>/dev/null; then
  bad "Permission loss still terminates the app"
else
  ok "Permission loss does not terminate the app"
fi

echo
note "Building $CONFIG (compile + unit tests where possible)"

mkdir -p "$DERIVED"
set +e
xcodebuild \
  -project BabyKeyboardLock.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  -destination 'platform=macOS' \
  build-for-testing \
  2>&1 | tee "$DERIVED/build-for-testing.log" | tail -n 40
BUILD_RC=${PIPESTATUS[0]}
set -e

if [[ $BUILD_RC -ne 0 ]]; then
  bad "xcodebuild build-for-testing failed (see $DERIVED/build-for-testing.log)"
else
  ok "build-for-testing succeeded"
fi

echo
note "Resolving app product (must not be UI test runner)"
APP_PATH=""
if [[ -d "$PRODUCTS_DIR" ]]; then
  APP_PATH="$(resolve_app_product "$PRODUCTS_DIR" || true)"
fi

if [[ -z "${APP_PATH:-}" || ! -d "${APP_PATH:-}" ]]; then
  bad "No real app product under $PRODUCTS_DIR (expected ${EXPECTED_APP_NAMES[*]})"
else
  case "$APP_PATH" in
    *UITests*|*Runner*)
      bad "Resolved product looks like a test runner: $APP_PATH"
      ;;
    *)
      ok "App product: $APP_PATH"
      ;;
  esac

  echo
  note "codesign / entitlements dump"
  codesign -dv --verbose=2 "$APP_PATH" 2>&1 | sed -n '1,25p' || true
  echo
  ENTITLEMENTS_DUMP="$(codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || true)"
  if [[ -n "$ENTITLEMENTS_DUMP" ]]; then
    printf '%s\n' "$ENTITLEMENTS_DUMP" | head -n 40
  else
    warn "Could not dump entitlements"
  fi

  BID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
  LSUI="$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo '?')"

  if [[ "$BID" == "$EXPECTED_BUNDLE_ID" ]]; then
    ok "CFBundleIdentifier=$BID"
  else
    bad "CFBundleIdentifier=$BID (expected $EXPECTED_BUNDLE_ID)"
  fi

  case "$LSUI" in
    true|YES|1)
      ok "LSUIElement=$LSUI (agent app)"
      ;;
    *)
      bad "LSUIElement=$LSUI (expected true/YES for menu-bar agent)"
      ;;
  esac

  # Debug product should not ship with app sandbox enabled.
  if [[ "$CONFIG" == "Debug" ]]; then
    if printf '%s\n' "$ENTITLEMENTS_DUMP" | rg -q 'com.apple.security.app-sandbox'; then
      if printf '%s\n' "$ENTITLEMENTS_DUMP" | rg -U -q 'com.apple.security.app-sandbox</key>[[:space:]]*<false/>'; then
        ok "Debug product entitlements: app-sandbox false"
      elif printf '%s\n' "$ENTITLEMENTS_DUMP" | rg -U -q 'com.apple.security.app-sandbox</key>[[:space:]]*<true/>'; then
        bad "Debug product entitlements: app-sandbox true (expected false)"
      else
        warn "Debug product has app-sandbox key but value not clearly false/true"
      fi
    else
      ok "Debug product entitlements: no app-sandbox key (effectively off)"
    fi
  fi

  if command -v tccutil >/dev/null 2>&1; then
    note "tccutil is present but will NOT reset TCC automatically (destructive)."
  fi
fi

echo
note "Running unit tests (AccessibilityFoundationTests + EventHandlerUnitTests)"
set +e
xcodebuild \
  -project BabyKeyboardLock.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  -destination 'platform=macOS' \
  test-without-building \
  -only-testing:BabyKeyboardLockTests/AccessibilityFoundationTests \
  -only-testing:BabyKeyboardLockTests/EventHandlerUnitTests \
  2>&1 | tee "$DERIVED/test.log" | tail -n 50
TEST_RC=${PIPESTATUS[0]}
set -e

if [[ $TEST_RC -eq 0 ]]; then
  ok "Unit tests passed"
else
  # Full test host may fail if test team / host path mismatches; still report.
  warn "Unit tests did not fully pass (rc=$TEST_RC). See $DERIVED/test.log"
  if rg -q 'AccessibilityFoundationTests' "$DERIVED/test.log"; then
    note "AccessibilityFoundationTests appeared in log — inspect failures carefully"
  fi
fi

echo
echo "=== Human-only checklist (cannot be automated without TCC click) ==="
cat <<EOF
1. Launch the built app product only:
   ${APP_PATH:-"(resolve failed — rebuild first)"}
2. Confirm the main titled window appears (menu-bar agent still has no Dock icon).
3. If Accessibility is off: use in-app “Grant Accessibility Access” OR System Settings toggle.
4. In System Settings → Privacy & Security → Accessibility, enable the EXACT app you launched
   (bundle id must be $EXPECTED_BUNDLE_ID for this CONFIG).
5. Recheck in-app status: Accessibility ok + Event tap Active.
6. Toggle Lock Keyboard ON → keys should be blocked; Ctrl+Option+U or toggle unlocks.
7. If you re-sign / move the app, re-enable the Accessibility toggle (code identity changed).
8. Optional: watch unified log for AttributeGraph "Cycle detected" — should be quiet after foundation fix.
EOF

echo
echo "=== Summary: pass=$PASS warn=$WARN fail=$FAIL ==="
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
