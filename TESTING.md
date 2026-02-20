# TESTING.md

Universal development testing checklist (language-agnostic), with Stein-specific command examples.

## 1) Fast local correctness checks (every meaningful change)
Run the project's fastest deterministic checks before packaging/release.

Examples for this repo:
- `swift test`
- `swift build -c release --product Stein`

## 2) Packaging/integration verification (before push)
Verify distributable artifacts are created and non-empty.

Examples for this repo:
- `./scripts/verify-package-macos.sh`
- Confirm:
  - `dist/Stein.app/Contents/MacOS/Stein` exists and is non-empty
  - `dist/Stein-macos.zip` exists and is non-empty

## 3) Push policy
Only push code intended for distribution after local checks pass.

## 4) CI gate (required)
A build is releasable only if required CI workflows pass on target OS/platform.

For Stein: `macOS Build` must pass.

## 5) Install/run smoke test (release candidate)
Install the produced artifact in real target conditions and validate critical user flows.

For Stein:
- Install to `/Applications/Stein.app`
- Launch successfully
- Menu bar item visible
- Preferences opens
- Global shortcut works
- Start-at-login setting persists
- Menu bar indexing path works with Accessibility permission

## 6) Ship rule
Ship only artifacts that passed:
- local checks,
- CI checks,
- smoke test.

## 7) Failure rule
If any gate fails:
- stop release,
- fix root cause,
- rerun full checklist.
