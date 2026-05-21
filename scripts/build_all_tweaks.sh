set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${MANIFEST:-$ROOT/tweaks.json}"
WORK="${WORK:-$ROOT/.build}"
OUT_DIR="${OUT_DIR:-$ROOT/built-debs}"
mkdir -p "$WORK" "$OUT_DIR"

: "${THEOS:?THEOS env var must point to a Theos checkout}"
export THEOS

# 1. Clone shared headers into Theos's standard include path so every tweak's
mkdir -p "$THEOS/include"
jq -c '.headers[]' "$MANIFEST" | while read -r entry; do
  name=$(jq -r '.name' <<<"$entry")
  repo=$(jq -r '.repo' <<<"$entry")
  ref=$(jq  -r '.ref'  <<<"$entry")
  dst="$THEOS/include/$name"
  if [[ -d "$dst/.git" ]]; then
    git -C "$dst" pull --quiet --ff-only || true
  else
    git clone --quiet --depth=1 --branch "$ref" "https://github.com/$repo.git" "$dst"
  fi
done

# Some older tweaks include <YTHeaders/...> — alias YouTubeHeader for them.
if [[ -d "$THEOS/include/YouTubeHeader" && ! -e "$THEOS/include/YTHeaders" ]]; then
  cp -R "$THEOS/include/YouTubeHeader" "$THEOS/include/YTHeaders"
fi

# 2. Iterate tweaks (filter by BUILD_FILTER JSON array if provided).
filter_expr='.tweaks[]'
if [[ -n "${BUILD_FILTER:-}" && "$BUILD_FILTER" != "[]" ]]; then
  if echo "$BUILD_FILTER" | jq -e 'type == "array"' >/dev/null 2>&1; then
    export BUILD_FILTER
    filter_expr='.tweaks[] | select(.name as $n | env.BUILD_FILTER | fromjson | index($n))'
    echo "Build filter active: $BUILD_FILTER"
  else
    echo "::warning::BUILD_FILTER is not a JSON array, building all"
  fi
fi

jq -c "$filter_expr" "$MANIFEST" | while read -r entry; do
  name=$(jq -r '.name' <<<"$entry")
  release=$(jq -r '.release // empty' <<<"$entry")

  if [[ -n "$release" ]]; then
    pattern=$(jq -r '.asset_pattern' <<<"$entry")
    echo "::group::Download release $name ($release :: $pattern)"
    gh release download --repo "$release" --pattern "$pattern" --dir "$OUT_DIR" --clobber
    echo "::endgroup::"
    continue
  fi

  repo=$(jq -r '.repo' <<<"$entry")
  ref=$(jq  -r '.ref'  <<<"$entry")
  glob=$(jq -r '.deb_glob' <<<"$entry")
  src="$WORK/$name"

  echo "::group::Build $name ($repo@$ref)"
  [[ -d "$src" ]] || git clone --depth=1 --branch "$ref" "https://github.com/$repo.git" "$src"

  pushd "$src" >/dev/null
  make clean >/dev/null 2>&1 || true
  make package \
    THEOS_PACKAGE_SCHEME=rootless \
    FINALPACKAGE=1 DEBUG=0 \
    -j"$(sysctl -n hw.ncpu)"

  # shellcheck disable=SC2086
  found=( $glob )
  if (( ${#found[@]} == 0 )); then
    echo "::error::No .deb produced for $name (glob=$glob)"; exit 1
  fi
  cp "${found[@]}" "$OUT_DIR/"
  popd >/dev/null
  echo "::endgroup::"
done

echo "All packages in $OUT_DIR:"
ls -lh "$OUT_DIR"
