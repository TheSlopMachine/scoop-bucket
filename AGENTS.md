# AGENTS.md

Scoop bucket, not an application repo: the work is authoring/validating manifests in `bucket/*.json` — there is nothing to build or test beyond manifest checks.

## How updates work

- `templates/github-release.json` is the starting point for a new manifest.
- `README.md` is end-user documentation only (install instructions + the apps table). All development knowledge lives here.
- `.github/workflows/validate.yml` lints every `bucket/*.json` on push/PR (requires `version`, `description`, `homepage`, `license`, `url` or `architecture`, `checkver` + `autoupdate`).
- `.github/workflows/excavator.yml` runs every 6h and on demand (Actions → Excavator → Run workflow): `checkver.ps1 -Dir bucket -Update -SkipUpdated` rewrites `version`/`url`/`hash` and commits `chore: update <app>` as `github-actions[bot]` — expect bot commits in `git log` and don't touch manifests while it runs a push.
- `README.md` has a manual apps table; nothing validates it, so update it in the same commit as the manifest, alphabetically.
- Line endings: `.gitattributes` forces LF. JSON files use 4-space indent.

## Adding a new app

Work through upstream first, then write the manifest — in this order:

1. `GET https://api.github.com/repos/<owner>/<repo>/releases` and confirm: assets present in every release, asset naming stable, tag prefix consistent. `checkver: "github"` reads the latest release; a `v`-prefixed tag like `v0.6` simply becomes version `0.6` (no-patch versions are fine). If the project does not publish GitHub Releases, use `checkver` with a `url` + `regex` or `jsonpath` instead — see the [Scoop wiki](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifest-Autoupdate).
2. Map arches explicitly — Scoop names never match Go/GoReleaser names: `64bit` → `amd64`, `32bit` → `386`, `arm64` → `arm64`. So multi-arch apps need the `architecture` block, like `pineconemc.json`.
3. Download the `amd64` asset; list the zip contents to learn the exe name and whether an `extract_dir` is needed; verify its SHA256 against upstream `checksums.txt`. GoReleaser checksum lines are `<os>_<arch>/<asset>` but download URLs use the bare asset name.
4. Add `persist` only on evidence: it is needed when the app writes data next to the exe. Grep the upstream source for storage paths (Go repos often use XDG dirs under `~` → no `persist`, e.g. `llm-router`), or test-run it.
5. Write `bucket/<app>.json`, then smoke-test the `autoupdate` URL pattern against a real released version using a literal URL: `Invoke-WebRequest https://github.com/<owner>/<repo>/releases/download/v0.6/<asset> -Method Head`. Gotcha: building the URL as `"...v$version/..."` inside PowerShell double quotes expands `$version` to empty and yields fake 404s — always write the literal tag or `[char]36 + 'version'` when checking.
6. Use the placeholder flow by default (`version: "0.0.0"`, 64-zero hashes): the current-release `url` will 404 by design until after push; then trigger Excavator once to fill real values; `scoop install` only works after that. Prefilling the verified version + hashes from `checksums.txt` is also correct and makes the app installable immediately.
7. Run the lint (below), then commit `feat: add <app> <version> from <owner>/<repo>` (style from history).

## Maintaining a broken app

- Diagnose from the same release API listing: the usual breakage is renamed/restructured assets. A rename requires updating all three in one edit: current release `url`s, the `autoupdate` URL templates, and fresh hashes.
- Manual dry-run with real Scoop:
  `& "$(scoop prefix scoop)\bin\checkver.ps1" -Dir .\bucket -App <app> -Update`
  Quick end-to-end test: `scoop install .\bucket\<app>.json` (placeholder manifests only install after Excavator filled real values).
- Same without Scoop installed: plain PowerShell + the GitHub API — fetch the release JSON, compare asset names/sizes/tags, download and hash the challenged asset against its `checksums.txt`. Hashes legitimately come from upstream `checksums.txt`, not third parties.

## Local lint (same logic as validate.yml)

```powershell
$failed = $false
foreach ($f in Get-ChildItem bucket -Filter *.json) {
    try { $m = Get-Content $f.FullName -Raw | ConvertFrom-Json }
    catch { Write-Host "FAIL $($f.Name): invalid JSON"; $failed = $true; continue }
    foreach ($k in 'version','description','homepage','license') {
        if (-not $m.$k) { Write-Host "FAIL $($f.Name): missing $k"; $failed = $true }
    }
    if (-not ($m.url -or $m.architecture)) { Write-Host "FAIL $($f.Name): needs url or architecture"; $failed = $true }
}
if ($failed) { exit 1 } else { Write-Host 'All manifests valid.' }
```
