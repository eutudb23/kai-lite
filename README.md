# kai-ylte — tweaked IPA builder

A from-scratch, fully open-source alternative. Builds an unsigned tweaked IPA entirely in GitHub Actions.
Sign + sideload the resulting IPA yourself with Feather, AltStore, Sideloadly, ESign, or install via TrollStore.

## Included tweaks

Configured in [`tweaks.json`](./tweaks.json). Each one is a workflow toggle.

| Tweak | Source | What it does |
|---|---|---|
| YouTube-X | [`PoomSmart/YouTube-X`](https://github.com/PoomSmart/YouTube-X) | Adblock, background play, premium dialog block, telemetry kill |
| YouPiP | [`PoomSmart/YouPiP`](https://github.com/PoomSmart/YouPiP) | Picture-in-Picture |
| YTUHD | [`Tonwalter888/YTUHD`](https://github.com/Tonwalter888/YTUHD) | 4K / UHD quality unlock (maintained fork of PoomSmart's) |
| YouQuality | [`PoomSmart/YouQuality`](https://github.com/PoomSmart/YouQuality) | Remember video quality |
| Return YouTube Dislikes | [`PoomSmart/Return-YouTube-Dislikes`](https://github.com/PoomSmart/Return-YouTube-Dislikes) | Restore dislike counts |
| YTABConfig | [`PoomSmart/YTABConfig`](https://github.com/PoomSmart/YTABConfig) | Settings UI for the above (auto-pulls [`PoomSmart/YouGroupSettings`](https://github.com/PoomSmart/YouGroupSettings) as a runtime dep) |
| YTVideoOverlay | [`PoomSmart/YTVideoOverlay`](https://github.com/PoomSmart/YTVideoOverlay) | Overlay framework dep |
| DontEatMyContent | [`therealFoxster/DontEatMyContent`](https://github.com/therealFoxster/DontEatMyContent) | Notch / Dynamic Island safe-area fix |
| YTSideload | [`Balackburn/YTSideload`](https://github.com/Balackburn/YTSideload) | **Fixes logout-on-relaunch under sideload** |

## How to use

1. **Get a decrypted IPA** for your own legally-owned device. (Out of scope here.)
2. **Upload it** to a direct-download host like [Catbox.moe](https://catbox.moe) or pixeldrain and copy the direct URL.
3. **Run the workflow:** GitHub → Actions tab → *Build tweaked IPA* → **Run workflow**:
   - Paste the URL into `decrypted_ipa_url` (it's masked from logs).
   - Toggle tweaks on/off — only the selected ones are compiled (faster builds, separate cache key).
   - Optionally provide `safari_extension_url` pointing at an `OpenYouTubeSafariExtension.appex` (raw `.appex` or a `.zip` containing one) to add the "Open in YouTube" Safari handler.
   - Keep `build_trollfools_companion` ticked to also produce a `.cyan` package + a zip of just the dylibs/bundles — useful for [TrollFools](https://github.com/Lessica/TrollFools) users or local re-injection without rebuilding.
   - Tick `publish_release` to bundle all artifacts into a **draft** GitHub Release (review then publish manually).
4. Wait ~6–10 minutes (first run; subsequent runs reuse the `built-debs` cache when the same tweak subset is selected). Download `Tweaked_<run>.ipa` from the run's artifacts. The run summary shows IPA size, source bundle id, and the exact tweak list injected.
5. **Sign + install** locally with your tool of choice:
   - Feather, AltStore, Sideloadly, ESign — sign with your Apple ID
   - TrollStore — install as-is (no signing)

## Workflow inputs (cheat sheet)

| Input | Purpose |
|---|---|
| `decrypted_ipa_url` | Direct download URL (masked in logs) |
| `bundle_id` | Override `CFBundleIdentifier` |
| `app_name` | Override display name |
| `safari_extension_url` | Optional `.appex` (or zip containing one) to inject |
| `build_trollfools_companion` | Also produce `.cyan` + dylib zip |
| `publish_release` | Assemble all artifacts into a draft release |
| `enable_*` | Per-tweak toggles |

## Architecture

```
.github/workflows/
  build-tweaks.yml    # Reusable: clones each tweak, builds rootless .deb via Theos
  build-ipa.yml       # User entry point: prep -> tweaks -> inject + trollfools -> release
scripts/
  build_all_tweaks.sh # Iterates tweaks.json (filtered by BUILD_FILTER), runs `make package`
  inject.sh           # Wraps `cyan -uwef ...` for IPA assembly; supports extra injects
tweaks.json           # Single source of truth for tweak repos + refs
```

- **`prep` job** computes the enabled-tweak list once and feeds it to both `build-tweaks` (so only selected tweaks are compiled) and `inject` (so only selected dylibs are linked in).
- **Shared headers** (`YouTubeHeader`, `PSHeader`) are cloned into `$THEOS/include/` so every tweak's Makefile finds them on the standard include path. `YouTubeHeader` is also aliased to `YTHeaders` for older tweaks that include via that name.
- **Silent deps**: enabling `YTABConfig` automatically builds + injects `YouGroupSettings` (its runtime dependency) — no user-facing toggle needed.
- **Cache key** includes the enabled list — different toggle combinations get different caches.
- **YTSideload** is pulled from its GitHub Release rather than built from source.
- **`concurrency: cancel-in-progress`** kills superseded runs to save macOS minutes.
- **`levibostian/action-hide-sensitive-inputs`** masks the IPA URL from logs.
- **Pinned Theos commit** for reproducibility. Bump in `build-tweaks.yml` when upstream tweaks need new headers.

## Outputs

| Artifact | Contents |
|---|---|
| `Tweaked-ipa-<run>` | `Tweaked_<run>.ipa` (sign + sideload) |
| `Tweaked-trollfools-<run>` | `Tweaked_<run>.cyan` + `Tweaked_<run>-dylibs.zip` (TrollFools / re-inject) |
| `built-debs` | Individual `.deb` packages (debug / reuse) |

## Adding a new tweak

1. Edit `tweaks.json`:
   ```json
   { "name": "MyNewTweak", "repo": "owner/MyNewTweak", "ref": "main", "deb_glob": "packages/*.deb" }
   ```
2. Add a matching `enable_mynewtweak` input + branch in `build-ipa.yml`'s `Compute enabled tweak list` step (map it to the `.deb` basename prefix).
3. Re-run the workflow.

## Maintenance / debugging

When a workflow run goes red (typically after a YouTube version bump breaks a PoomSmart tweak), open the failing run and invoke these skills together:

- **`superpowers:systematic-debugging`** — forces hypothesis → minimal repro → fix instead of guess-and-rerun (which costs macOS minutes).
- **`everything-claude-code:github-ops`** — for `gh run view --log`, re-running specific jobs, and opening/triaging issues.

Optional helpers when relevant:

- **`find-docs`** for current cyan flags, Theos make variables, or GHA syntax.
- **`everything-claude-code:loop`** to babysit a long `gh run watch` without burning context.

If the same tweak breaks a third time, that's the cue to capture the pattern as a project-local skill via `everything-claude-code:skill-create` — until then, ad-hoc debugging is fine.

## Credits

- [PoomSmart](https://github.com/PoomSmart) — the canonical YT tweak ecosystem (YouTube-X, YouPiP, YouQuality, RYD, YTABConfig, YouGroupSettings, YTVideoOverlay, YouTubeHeader, PSHeader)
- [Tonwalter888](https://github.com/Tonwalter888) — maintained YTUHD fork
- [therealFoxster](https://github.com/therealFoxster) — DontEatMyContent
- [Balackburn](https://github.com/Balackburn) — YTSideload, YTLitePlus
- [asdfzxcvbn/pyzule-rw](https://github.com/asdfzxcvbn/pyzule-rw) — `cyan`, the IPA-inject tool

## Legal

This repo contains no copyrighted Google code. Decrypted YouTube IPAs must be sourced and used in accordance with your local laws and Apple's terms.
