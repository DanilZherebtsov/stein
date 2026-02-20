# Stein

Stein is a native macOS menu bar utility inspired by Bartender-style workflows.

## V1 (current)

- Menu bar app (`NSStatusItem`) with configurable Stein icon.
- Show/hide state management for managed items.
- Group model (many items -> one logical parent group in Stein menu).
- Quick toggle for all managed items.
- Configurable global hotkey (preset options, default `⌥⌘B`).
- New-item policy (`hide by default` on/off).
- Start at login toggle (macOS login items integration).
- Import real running apps into managed list.
- Basic preferences UI for item visibility, grouping, and icon selection.
- Persistence in `~/Library/Application Support/Stein/state.json`.

## Current scope note

This repo ships a **clean V1 foundation** and UI/state layer.
Deep manipulation of third-party menu bar extras on macOS often relies on private/fragile system behavior and extra permissions; that integration is intentionally isolated for later hardening.

## OS support target

- macOS 13+ (Ventura and newer), including current releases.
- CPU: Apple Silicon and Intel.

## Build (on macOS)

```bash
swift build -c release
```

## Run (on macOS)

```bash
swift run Stein
```

## Package a simple installer ZIP (on macOS)

```bash
./scripts/package-macos.sh
```

This generates:

- `dist/Stein.app` (app bundle)
- `dist/Stein-macos.zip` (drag-and-drop installer archive)

## Install

1. Unzip `Stein-macos.zip`
2. Drag `Stein.app` into `/Applications`
3. Launch Stein

## Next planned work

1. Global hotkey registration (real handler)
2. Layout editor with group assignment UI
3. Integration layer for controlled visibility of external menu extras
4. Notch-aware overflow behavior
