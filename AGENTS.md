# Reel Log

Flutter 3.47 / Dart 3.13 single-screen app. All UI lives in `lib/main.dart`; tests in `test/widget_test.dart`.

## Commands (run from the project root)

- Analyze: `flutter analyze` — must be clean
- Test: `flutter test` — must pass
- Strict spec check: `openspec validate <change> --strict`

## Architecture

- `Film` model: `id` int (generated, `microsecondsSinceEpoch` bumped on collision), `title` String (stored trimmed), `year` int? (null = absent, key omitted from JSON), `watchedYear` int, `rating` int (0 = unrated, else 1–5), `notes` String? (null = absent, key omitted).
- Persistence: `SharedPreferences` key `reel_log_films`, one JSON string, full-list rewrite on save. `fromJson` stays backward compatible: missing year/notes → null, ISO watched string → its year, unknown keys (e.g. old `director`) ignored.
- Averages ignore unrated (`rating == 0`). List sorts by `watchedYear` desc (same-year order unspecified).
- Poster tile colors cycle by film id (`_tones[id % 5]`), never stored per film.

## Tests

- Seed prefs first: `SharedPreferences.setMockInitialValues({})`; phone surface `Size(390, 1400)` with teardown reset.
- After the last `enterText` before a tap, always `await t.pump()` — entered text needs a frame before state (e.g. Save enablement) settles.
- Sheet fields carry keys: `logTitle`, `logReleaseYear`, `logWatchedYear`, `logNotes`, `logClose`. Detail controls carry keys: `detailBack`, `detailTitle`, `detailReleaseYear`, `detailWatchedYear`, `detailNotes`. Stars use tooltips `'1 of 5'`…`'5 of 5'`.
- Write-failure path: swap in a throwing `InMemorySharedPreferencesStore` subclass (see existing `_ThrowingStore`) after resetting the instance cache with `setMockInitialValues`, restore in teardown.
- Save flow in app code resolves prefs via fresh `SharedPreferences.getInstance()` per save — never cache the store, or injected failures won't land.

## Design tokens (AW Design System, Figma-synced — match these, don't eyeball)

- Primary deep green `0xFF006B59` — FAB, filled stars, Save button, focused field borders
- Primary container mint `0xFF5CFBD8` / on-container `0xFF002019` — selected chip
- Page `0xFFFCFCFF`, search fill `0xFFEDEEF1`, card surface `0xFFF3F3F6`, sheet `0xFFFFFFFF`
- Ink `0xFF151C23`, subtle grey `0xFF76777A`, star-outline `0xFF6F7975`
- Chip border `0xFFBFC9C4`, field/card border `0xFFDBE5E0`, sheet handle `0xFFC6C6C9`
- Poster tones (cycle by `id % 5`, bg/fg): `5CFBD8/002019`, `99F0FF/001F24`, `D3E4FF/001C38`, `006B59/FFFFFF`, `2E3134/F0F0F4`
- Type: prototype uses Inter / Montserrat / JetBrains Mono as local woff2 — Flutter cannot bundle woff2, so use system defaults at the prototype's sizes/weights (eyebrow 12 w500 ls 0.5, `Watched` 28 w700, stats 18 w600 / 12 subtle, sheet heading 20 w700, field labels 500 13px ink).
- List row: 56×84 tile, 4px radius, initials 13 w700 bottom-left; title 16 w600 ellipsis; meta 13 subtle; 14px stars (filled primary / `star_border` outline) + 12 subtle date; chevron; no dividers.
- Log sheet: white, 28px top radius, 300ms ease-out (`sheetAnimationStyle`), 40% scrim; drag handle 36×4; caption labels *above* h44 radius-8 bordered fields with placeholders (`e.g. Aftersun`, `2022`, `What stayed with you?`); 28px stars in 44px targets; h48 buttons — ghost Cancel + primary Save (disabled: primary at 38% alpha).
- Detail screen: h52 top bar with `< Watched` back button (h44, 20px `chevron_left` + 15 w500 primary); 112×168 poster tile (8px radius, 10px pad, 22 w700 initials bottom-left) beside inline title (24 w700) and release-year fields; `Your rating` card (`0xFFF3F3F6` fill, `0xFFDBE5E0` 1px border, 12px radius, 16px pad) with 14 w600 heading + 12 w500 subtle label (`Not rated` when 0, `<rating> of 5` when 1–5), 32px stars in 44px targets (sticky on tap), and watched-year field; `Notes` (14 w600 heading, 5-line field with `What stayed with you?` placeholder, 12 subtle `Saved automatically` / `Saving...` caption).

## Design matching (learned the hard way — follow every time)

When given a design (PDF, HTML prototype, Figma export), never build from text extraction alone:

1. Render it and look at it: rasterize every PDF page; for bundled/self-unpacking HTML, screenshot it headless (inject a delayed click to capture sheets, dialogs, and other states).
2. Extract exact values from markup, not memory: seed data, copy, colors (resolve design-system tokens to hex; sample pixels only when tokens are absent), type sizes/weights, spacing, radii, component structure.
3. Behavior conflict between design and spec → surface it and wait for a call; never silently pick. Style-only gaps → match the design, keep spec copy/behavior.
4. Verify visually before declaring done: capture the app via a temporary golden test, view the PNG side-by-side with the design render, iterate, then delete the scaffolding (`shot_test.dart`, `test/goldens/`).
5. Check asset usability up front (e.g. prototype woff2 fonts cannot ship in Flutter) and record the fallback.

## Boundaries

- No new packages without asking (dev-only pins of already-transitive packages are OK).
- Exact user-facing copy lives in the OpenSpec spec — never paraphrase confirmation/error/validation strings.
- The HTML prototype is the visual source of truth; the spec wins on any behavior conflict — surface the conflict, don't silently pick.
- OpenSpec changes live in `openspec/changes/<name>/`; archive after review.
