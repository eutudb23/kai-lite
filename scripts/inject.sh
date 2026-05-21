#!/usr/bin/env bash
# Downloads the decrypted YouTube IPA, injects the selected .deb tweaks
# via cyan (pyzule-rw), and writes the unsigned tweaked IPA to $OUT_IPA.
#
# Required env:
#   IPA_URL            direct-download URL of decrypted YouTube IPA
#   BUNDLE_ID          bundle id override (e.g. com.google.ios.youtube.tweaked)
#   APP_NAME           display name (e.g. YouTube)
#   ENABLED_TWEAKS     newline-separated list of .deb basenames to inject
# Optional env:
#   DEB_DIR            defaults to ./built-debs
#   OUT_IPA            defaults to ./YouTube-Tweaked.ipa
#
# Facts (per repo policy):
#   Caller: .github/workflows/build-ipa.yml step "Inject + repack"
#   Schema: reads .deb files from DEB_DIR; writes one .ipa to OUT_IPA. No dates.
#   Duplicate check: scripts/ contains only build_all_tweaks.sh before this file.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEB_DIR="${DEB_DIR:-$ROOT/built-debs}"
OUT_IPA="${OUT_IPA:-$ROOT/YouTube-Tweaked.ipa}"
WORK="$ROOT/.inject"
mkdir -p "$WORK"

: "${IPA_URL:?IPA_URL required}"
: "${BUNDLE_ID:?BUNDLE_ID required}"
: "${APP_NAME:?APP_NAME required}"
: "${ENABLED_TWEAKS:?ENABLED_TWEAKS required (newline list)}"

# 1. Download IPA + sanity-check it's a real zip-ish blob, not an HTML error page.
SRC_IPA="$WORK/youtube.ipa"
echo "Downloading IPA from $IPA_URL"
curl -L --fail --silent --show-error -o "$SRC_IPA" "$IPA_URL"

size=$(stat -f%z "$SRC_IPA" 2>/dev/null || stat -c%s "$SRC_IPA")
if (( size < 50 * 1024 * 1024 )); then
  echo "::error::Downloaded IPA is only ${size} bytes — expected >50MB. URL probably returned an HTML error page."
  head -c 256 "$SRC_IPA"; echo
  exit 1
fi
file "$SRC_IPA" | grep -qiE 'zip archive|ios app' || {
  echo "::error::Downloaded file is not a zip/IPA"; file "$SRC_IPA"; exit 1
}

# 2. Resolve selected .deb paths.
declare -a DEB_ARGS=()
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  matches=( "$DEB_DIR"/${name}*.deb "$DEB_DIR"/${name}*.appex )
  # Filter out non-existent glob expansions.
  real=()
  for m in "${matches[@]}"; do [[ -e "$m" ]] && real+=( "$m" ); done
  if (( ${#real[@]} == 0 )); then
    echo "::error::Nothing in $DEB_DIR matching '${name}*' (.deb or .appex)"; ls "$DEB_DIR"; exit 1
  fi
  DEB_ARGS+=( "${real[0]}" )
done <<<"$ENABLED_TWEAKS"

if (( ${#DEB_ARGS[@]} == 0 )); then
  echo "::error::No tweaks selected — nothing to inject"; exit 1
fi

echo "Injecting ${#DEB_ARGS[@]} item(s):"
printf '  - %s\n' "${DEB_ARGS[@]}"

# 3. cyan flags: -u remove UISupportedDevices, -w overwrite, -e fakesign,
#    -f inject deb/dylib/bundle list, -b bundle id, -n display name.
cyan \
  -i "$SRC_IPA" \
  -o "$OUT_IPA" \
  -uwef "${DEB_ARGS[@]}" \
  -b "$BUNDLE_ID" \
  -n "$APP_NAME"

ls -lh "$OUT_IPA"
echo "OK: wrote $OUT_IPA"
