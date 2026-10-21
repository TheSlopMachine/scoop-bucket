# TheSlopMachine's Scoop bucket

Automatically updated [Scoop](https://scoop.sh) bucket.

## Usage

```powershell
scoop bucket add slop https://github.com/TheSlopMachine/scoop-bucket
```

## Apps

| App | Description | Upstream |
|---|---|---|
| `imageviewer` | Simple, cross-platform Qt image viewer inspired by GPicView | [AlienCowEatCake/ImageViewer](https://github.com/AlienCowEatCake/ImageViewer) |
| `pineconemc` | Prism Launcher fork with Ely.by support | [ElyPrismLauncher/Launcher](https://github.com/ElyPrismLauncher/Launcher) |

## How updates work

`.github/workflows/excavator.yml` runs every 6 hours (and on demand via **Actions → Excavator → Run workflow**).
It runs Scoop's `checkver.ps1 -Update` over every manifest in `bucket/`. When upstream has a new release, the
manifest's `version`, `url` and `hash` are rewritten and committed automatically.

## Adding an app

1. Copy `templates/github-release.json` to `bucket/<app-name>.json` (lowercase, dashes).
2. Fill in the `__PLACEHOLDERS__`. Keep `version` at `0.0.0` and the hash as zeros.
3. Commit and push, then run the **Excavator** workflow once. It fills in the real version, URL and hash.

Notes:

- Apps with 32/64-bit/arm64 builds use an `architecture` block, like `bucket/pineconemc.json`.
- If the project is not on GitHub Releases, use `checkver` with a `url` + `regex` or `jsonpath`.
  See the [Scoop wiki](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifest-Autoupdate).
- `validate.yml` lints manifests on every push/PR.

## Testing locally

```powershell
# From a clone of this repo, with Scoop installed
scoop install .\bucket\pineconemc.json
& "$(scoop prefix scoop)\bin\checkver.ps1" -Dir .\bucket -App pineconemc -Update
```
