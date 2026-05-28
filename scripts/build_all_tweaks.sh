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
  ref=$(jq  -r '.ref // empty' <<<"$entry")
  dst="$THEOS/include/$name"
  if [[ -d "$dst/.git" ]]; then
    git -C "$dst" pull --quiet --ff-only || true
  else
    # Clone default branch (handles repos that use master vs main).
    git clone --quiet --depth=1 "https://github.com/$repo.git" "$dst"
    if [[ -n "$ref" ]]; then
      git -C "$dst" fetch --quiet --depth=1 origin "$ref"
      git -C "$dst" checkout --quiet FETCH_HEAD
    fi
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
    tmp=$(mktemp -d)
    gh release download --repo "$release" --pattern "$pattern" --dir "$tmp" --clobber

    asset=$(find "$tmp" -type f | sort | head -1)
    [[ -z "$asset" ]] && { echo "::error::No asset matched '$pattern'"; exit 1; }
    ext="${asset##*.}"
    cp "$asset" "$OUT_DIR/${name}.${ext}"
    rm -rf "$tmp"
    echo "::endgroup::"
    continue
  fi

  url=$(jq -r '.url // empty' <<<"$entry")
  if [[ -n "$url" ]]; then
    sha=$(jq -r '.sha256 // empty' <<<"$entry")
    echo "::group::Download $name ($url)"
    tmp=$(mktemp -d)
    curl -L --fail --silent --show-error -o "$tmp/pkg.deb" "$url"
    if [[ -n "$sha" ]]; then
      actual=$(shasum -a 256 "$tmp/pkg.deb" | awk '{print $1}')
      if [[ "$actual" != "$sha" ]]; then
        echo "::error::SHA256 mismatch for $name: expected $sha, got $actual"; exit 1
      fi
    fi
    cp "$tmp/pkg.deb" "$OUT_DIR/${name}.deb"
    rm -rf "$tmp"
    echo "::endgroup::"
    continue
  fi

  sparse=$(jq -r '.sparse // empty' <<<"$entry")
  if [[ -n "$sparse" ]]; then
    repo=$(jq -r '.repo' <<<"$entry")
    echo "::group::Sparse-clone $name ($repo :: $sparse)"
    sparse_dir="$WORK/$name.sparse"
    rm -rf "$sparse_dir"
    git clone --quiet -n --depth=1 --filter=tree:0 "https://github.com/$repo.git" "$sparse_dir"
    git -C "$sparse_dir" sparse-checkout set --no-cone "$sparse"
    git -C "$sparse_dir" checkout --quiet
    found=$(find "$sparse_dir" -name "$(basename "$sparse")" -print -quit)
    if [[ -z "$found" ]]; then
      echo "::error::Sparse checkout of '$sparse' produced nothing in $sparse_dir"; exit 1
    fi
    ext="${found##*.}"
    rm -rf "$OUT_DIR/${name}.${ext}"
    cp -R "$found" "$OUT_DIR/${name}.${ext}"
    echo "::endgroup::"
    continue
  fi

  repo=$(jq -r '.repo' <<<"$entry")
  ref=$(jq  -r '.ref // empty' <<<"$entry")
  glob=$(jq -r '.deb_glob' <<<"$entry")
  src="$WORK/$name"

  echo "::group::Build $name ($repo@${ref:-default})"
  if [[ ! -d "$src" ]]; then
    git clone --depth=1 "https://github.com/$repo.git" "$src"
    if [[ -n "$ref" ]]; then
      git -C "$src" fetch --depth=1 origin "$ref"
      git -C "$src" checkout FETCH_HEAD
    fi
  fi

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
  cp "${found[0]}" "$OUT_DIR/${name}.deb"
  popd >/dev/null
  echo "::endgroup::"
done

echo "All packages in $OUT_DIR:"
ls -lh "$OUT_DIR"
