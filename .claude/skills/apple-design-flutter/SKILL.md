---
name: apple-design-flutter
description: Use when redesigning or building Flutter mobile screens in Apple / iOS style (Cupertino, Human Interface Guidelines, iOS 26 Liquid Glass), including Arabic RTL and dark mode.
---

# Apple design for Flutter apps

Goal: make Flutter screens look and feel like a native iOS app, following Apple's Human Interface Guidelines (HIG), without breaking Arabic RTL, dark mode, or Android.

## 0. Before changing anything

1. Read `pubspec.yaml`: note the Flutter version and whether `cupertino_native`, `liquid_glass_native`, `native_adaptive_ui` or `cupertino_ui` are already used. Never add a package without telling the user.
2. Ask (once) which target the user wants if it isn't clear:
   - **iOS-only look everywhere** → Cupertino widgets on all platforms.
   - **Adaptive** (iOS style on iPhone, Material on Android) → `.adaptive` constructors or `native_adaptive_ui`.
   - **Liquid Glass (iOS 26)** → native glass package for bars/tabs only (see section 6).
3. Convert one screen at a time. Keep business logic, state management and API calls untouched; change only the presentation layer.

## 1. Widget mapping (Material → Cupertino)

| Material | Cupertino / iOS equivalent |
|---|---|
| `MaterialApp` | `CupertinoApp` (or keep `MaterialApp` + `CupertinoThemeData` if Material widgets remain) |
| `Scaffold` + `AppBar` | `CupertinoPageScaffold` + `CupertinoNavigationBar` |
| Scrollable page with title | `CustomScrollView` + `CupertinoSliverNavigationBar` (large title) |
| `BottomNavigationBar` | `CupertinoTabScaffold` + `CupertinoTabBar` |
| `ElevatedButton` | `CupertinoButton.filled` |
| `TextButton` | `CupertinoButton` |
| `TextField` | `CupertinoTextField` / `CupertinoSearchTextField` |
| `Switch`, `Slider`, `Checkbox` | `CupertinoSwitch`, `CupertinoSlider`, `CupertinoCheckbox` |
| `ListTile` in a `Card` | `CupertinoListSection.insetGrouped` + `CupertinoListTile` |
| `AlertDialog` | `CupertinoAlertDialog` via `showCupertinoDialog` |
| `BottomSheet` with options | `CupertinoActionSheet` via `showCupertinoModalPopup` |
| `showDatePicker` | `CupertinoDatePicker` inside a modal popup |
| `DropdownButton` | `CupertinoPicker` or a pull-down/action sheet |
| `TabBar` (segments) | `CupertinoSlidingSegmentedControl` |
| `CircularProgressIndicator` | `CupertinoActivityIndicator` |
| `RefreshIndicator` | `CupertinoSliverRefreshControl` |
| `MaterialPageRoute` | `CupertinoPageRoute` (gives the swipe-back gesture) |
| `Icons.*` | `CupertinoIcons.*` |

If the project still mixes Material widgets, wrap in `Theme` with `platform: TargetPlatform.iOS` and prefer `.adaptive` constructors (`Switch.adaptive`, `CircularProgressIndicator.adaptive`, `AlertDialog.adaptive`).

## 2. Layout and spacing (HIG)

- Minimum touch target: 44 × 44 pt.
- Screen side margins: 16 pt (20 pt on larger phones is fine). Use a spacing scale of 4/8/12/16/20/24/32.
- Grouped content: inset-grouped lists on `systemGroupedBackground`, corner radius ~10–12, no drop shadows.
- iOS uses almost no elevation. Remove Material shadows; separate content with background contrast and hairline separators (`CupertinoColors.separator`, 0.5 px).
- Respect safe areas (notch, home indicator); `CupertinoPageScaffold` handles most of it — don't double-pad.
- Primary action at top-right of the nav bar (top-left in RTL) or a full-width filled button at the bottom, not a floating action button.

## 3. Typography

- Use the system font: don't set a custom `fontFamily` on iOS; Flutter uses SF Pro (and SF Arabic for Arabic text). If the app has a brand Arabic font, keep it only for headlines and ask the user.
- Use `CupertinoTheme.of(context).textTheme` styles: `navLargeTitleTextStyle` (34), `navTitleTextStyle` (17 semibold), `textStyle` (17 body), `tabLabelTextStyle`.
- HIG sizes to follow: Large Title 34, Title 1 28, Title 2 22, Title 3 20, Headline 17 semibold, Body 17, Callout 16, Subheadline 15, Footnote 13, Caption 12.
- Support Dynamic Type: never hard-code heights that clip text; test with large text scale.

## 4. Color and dark mode

- Use semantic dynamic colors, never hard-coded hex for surfaces/text:
  `CupertinoColors.systemBackground`, `secondarySystemBackground`, `systemGroupedBackground`, `secondarySystemGroupedBackground`, `label`, `secondaryLabel`, `tertiaryLabel`, `separator`, `systemFill`.
- Brand colors become `CupertinoDynamicColor.withBrightness(color: ..., darkColor: ...)` and are set as `primaryColor` in `CupertinoThemeData`.
- Resolve dynamic colors with `CupertinoDynamicColor.resolve(color, context)` when passing them to non-Cupertino widgets.
- Dark mode is true black/near-black (`systemBackground` dark = #000000, elevated = #1C1C1E). Keep the app's existing dark theme intent but map it onto these tokens.
- Use one accent color for interactive elements; destructive actions in `CupertinoColors.destructiveRed`.

## 5. Navigation and motion

- Hierarchical navigation with `CupertinoPageRoute` (slide + edge swipe back). Modal tasks with `CupertinoSheetRoute` / `showCupertinoModalPopup`.
- Tabs: 3–5 items, icon + short label, each tab keeps its own navigation stack (`CupertinoTabView`).
- Back button shows the previous screen's title or a chevron only — never a custom arrow icon.
- Add light haptics on meaningful actions: `HapticFeedback.selectionClick()` for pickers/segments, `lightImpact()` for confirmations.
- Avoid Material ripple/ink effects; Cupertino buttons use opacity on press.

## 6. iOS 26 Liquid Glass

- Flutter's built-in Cupertino widgets render the pre-iOS-26 look. Real Liquid Glass needs a package that embeds native UIKit/SwiftUI controls (`cupertino_native`, `liquid_glass_native`, or `native_adaptive_ui`). Check which is in `pubspec.yaml`; if none, propose one and wait for approval.
- Apply glass only to the functional layer: tab bar, navigation bar, toolbars, floating buttons, sheets. Never to content (cards, list rows, images, text blocks).
- Never stack more than two glass layers.
- Always provide a fallback: below iOS 26, on Android, and when the user enables Reduce Transparency, the control must render as a solid surface.
- These packages use platform views: avoid putting them inside long scrolling lists; test performance on a real device.

## 7. Arabic RTL rules

- Keep `Directionality` / `locale` driving layout; use `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional` and `start`/`end`, never `left`/`right`.
- In RTL the nav-bar back chevron points right and sits on the right; the trailing action sits on the left. `CupertinoNavigationBar` does this automatically — don't hard-code chevron icons.
- Swipe-back gesture comes from the right edge in RTL; verify it works on every pushed route.
- Directional icons (arrows, chevrons, "forward") must mirror; non-directional ones (clock, search, checkmark) must not. Use `Transform.flip` / `matchTextDirection: true` where needed.
- Numbers, phone numbers and Latin brand names stay LTR inside Arabic text; wrap with `Directionality(textDirection: TextDirection.ltr)` or Unicode marks when they render out of order.
- Check that `CupertinoLocalizations` delegates are included (`GlobalCupertinoLocalizations.delegate`) so pickers and dialogs show Arabic.

## 8. Android policy

Ask the user. Default: adaptive — iOS styling on iOS, Material 3 on Android, using one shared widget layer (small wrapper widgets like `AppButton`, `AppSwitch` that switch on `Theme.of(context).platform`). Don't force iOS chrome on Android unless the user explicitly wants the same look everywhere.

## 9. Output and review checklist

For every converted screen, deliver the full Dart file(s) and a short list of what changed. Before calling it done, check:

- [ ] No Material shadows, ripples or FABs left on iOS
- [ ] All surfaces/text use semantic dynamic colors; looks right in light and dark
- [ ] Touch targets ≥ 44 pt; 16 pt side margins; safe areas respected
- [ ] Large title on top-level scroll screens; standard title on pushed screens
- [ ] Swipe-back works (LTR and RTL)
- [ ] RTL: directional insets/alignment, mirrored chevrons, Arabic in pickers/dialogs
- [ ] Liquid Glass only on bars/tabs/floating controls, with fallback
- [ ] Text scales with Dynamic Type without clipping
- [ ] Business logic and state management unchanged
- [ ] `flutter analyze` passes
