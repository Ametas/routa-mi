# Mihomo patches

All changes to mihomo (`core/Clash.Meta`, an official MetaCubeX release tag)
live here as patch files. Never commit inside the submodule.

The build tool (`plugins/setup/buildkit/build_tool/lib/src/mihomo_patcher.dart`)
applies every `*.patch` in this directory in lexical file-name order, both in
the Android core build and in `run_build_tool.sh patch-mihomo`. Each patch is
idempotent: if its reverse applies cleanly it is treated as already applied.
A patch that neither applies nor reverse-applies fails the build.

Keep patches independent (do not touch the same hunks from two files); if
two changes overlap, merge them into one patch. Use a numeric prefix when
order matters (`10-foo.patch`, `20-bar.patch`).

| Patch | Purpose | Required |
|---|---|---|
| `proxy-only-traffic.patch` | SlClash's proxy-only upload/download counters (`statistic.DefaultManager.ProxyNow/ProxyTotal`, used by `core/hub.go`) | yes |

## Workflow

```bash
cd core/Clash.Meta
git checkout -q <tag>            # clean official release
git apply --check -v ../patches/mihomo/<name>.patch
# edit files, then regenerate against the clean tag:
git diff > ../patches/mihomo/<name>.patch
git checkout -q . && git clean -fdq   # new files: add with `git add -N` before diffing
```

`.github/workflows/mihomo-core-update.yml` applies all patches to each new
MetaCubeX release and runs the core tests before opening a PR. If a release
changes the touched code, update the patch on that PR's branch and rerun the
tests (`go test ./tunnel/statistic` in `core/Clash.Meta`, plus the suite in
`CLAUDE.md`).
