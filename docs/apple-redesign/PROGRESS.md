# Apple redesign — progress log

One line per converted screen or phase: what changed. Branch: `feature/apple-design`.

- **Phase 0** — Baseline commit of `mobile/` + `.claude/skills/`; audit written to `AUDIT.md` (baseline `flutter analyze`: 4 infos).
- **Phase 1** — `lib/core/design/` tokens: semantic `CupertinoDynamicColor`s (iOS system neutrals + teal accent), HIG type scale (Cairo titles, SF body on Apple platforms, Scheherazade Quran), 4-pt spacing, radii with continuous corners, 44-pt target. `AppTheme` = `CupertinoThemeData` + iOS-platform Material theme on the same tokens; `core/theme/*` re-export; `main.dart` gains `builder: AppTheme.builder`. New `test/design_theme_test.dart` (light / dark / system resolution). Analyze: 3 pre-existing infos.
