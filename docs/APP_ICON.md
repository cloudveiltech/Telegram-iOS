# App Icon

## Background

There are two independent icon mechanisms in this repo, and it's easy to fix one while leaving the other broken:

1. **Primary/home-screen icon** — `Telegram/Telegram-iOS/CloudVeil.icon/` (an Xcode "Icon Composer" bundle: `icon.json` + `Assets/1024.svg`, the CloudVeil cloud logo). Wired via `composer_icon_folders = ["CloudVeil"]` and `app_icons = [":CloudVeil_icon"]` in `Telegram/BUILD`. This is what installs on the home screen and is not affected by the scripts below.

2. **Selectable alternate icons** — Settings → Appearance → App Icon offers ~12 icon "skins" (`BlackIcon`, `BlueIcon`, `New1`, `New2`, classic/filled variants, `Premium`/`PremiumBlack`/`PremiumTurbo`, `WhiteFilledIcon`). Each one is a `Telegram/Telegram-iOS/<Name>.alticon/` folder of loose PNGs, listed in `alternate_icon_folders` in `Telegram/BUILD` and wired into `alternate_icons` on the `ios_application` rule. At build time, `alticonstool.py` (part of `rules_apple`) derives `CFBundleIconFiles` from each folder's filenames (stripping the `@Nx` suffix) and writes that list into **both** `CFBundleIcons` (iPhone) and `CFBundleIcons~ipad` (iPad) in Info.plist.

Two problems were found in these `.alticon` folders and fixed with the scripts below:

- **Missing iPad sizes → App Store Connect rejection (ITMS-90892).** Because the same file list is used for iPhone and iPad, a folder that only ships iPhone-sized PNGs (120×120 / 180×180) fails Apple's iPad validation. 4 of the 12 folders (`WhiteFilledIcon`, `Premium`, `PremiumBlack`, `PremiumTurbo`) never had 152×152/167×167 files — an upstream Telegram gap, not something introduced by this fork.
- **Wrong branding.** Every one of the 12 `.alticon` folders shipped unmodified stock Telegram artwork (the paper-plane logo), not CloudVeil's cloud logo. Since `UIImage(named: "BlueIcon", ...)` etc. resolve directly from these loose files (no asset catalog involved), this leaked into the in-app icon picker and the "Open in Telegram" thumbnail (`WebBrowserItem.swift`).

## The two scripts

Both live in `scripts/` and operate directly on the `.alticon` folders under `Telegram/Telegram-iOS/`. Neither touches `Telegram/BUILD` or any Swift code — every filename/size these scripts write to is already wired into the build, so no other changes are needed after running them.

### `scripts/apply-cloudveil-alticon-branding.sh`

Rewrites the pixel content of **every** PNG in **every** `.alticon` folder with the CloudVeil cloud logo, in place — same filename, same exact pixel dimensions, only the image content changes.

```sh
scripts/apply-cloudveil-alticon-branding.sh
```

- Master art is derived fresh on each run from `Telegram/Telegram-iOS/DefaultAppIcon.xcassets/AppIconLLC.appiconset/1024.png` (the CloudVeil logo, 1024×1024), flattened to remove its alpha channel via a `sips` JPEG round-trip (matches the no-alpha convention of the existing `.alticon` PNGs).
- For each existing PNG, the script measures its current width/height with `sips` and downsamples the master to that exact size before overwriting — so it naturally handles every size in play (120/180 iPhone, 76/152/167 iPad, 20/29/40/58/60/76/80/87 notification/spotlight/settings sizes) without needing a hardcoded size list.
- Idempotent — re-running it just re-derives the same master and re-writes the same pixels.
- **Run this after any upstream Telegram merge** that touches `Telegram/Telegram-iOS/*.alticon/` — merges can silently reintroduce stock Telegram artwork into these folders, and this script is the fix.
- All 12 icons currently render as the *same* cloud mark — there's only one master CloudVeil art asset in the repo (no black/blue/classic/filled/premium tinted variants). If per-style artwork is ever provided, this script would need to be extended to pick a different source image per folder name.

### `scripts/fix-alticon-ipad-sizes.sh`

Detects and backfills missing iPad-sized (152×152 / 167×167) icons in any `.alticon` folder — the fix for ITMS-90892.

```sh
scripts/fix-alticon-ipad-sizes.sh
```

- For each `.alticon` folder, checks (by actual pixel size, not filename — so it doesn't false-flag folders using different naming conventions like `New1`'s `-76@2x`/`-83.5@2x` vs `BlackIcon`'s `Ipad@2x`/`LargeIpad@2x`) whether a 152×152 and a 167×167 file already exist.
- If either is missing, downsamples the largest existing PNG in that folder (never upscales) to produce `<Name>Ipad@2x.png` (152×152) and `<Name>LargeIpad@2x.png` (167×167).
- Prints `OK` / `FIXED <files>` / `SKIPPED <reason>` per folder. `SKIPPED` means no source PNG in that folder is large enough to downsample from without upscaling — that folder needs a real ≥167px source image added manually.
- Idempotent — a second run reports `OK` everywhere once fixed.

## Recommended order

Run the branding script first, then the iPad-size script — that way any newly backfilled iPad icons are downsampled from the already-rebranded artwork instead of stale Telegram artwork:

```sh
scripts/apply-cloudveil-alticon-branding.sh
scripts/fix-alticon-ipad-sizes.sh
```

## Verifying

- `sips -g pixelWidth -g pixelHeight -g hasAlpha <file>` on a few files to confirm dimensions are unchanged and `hasAlpha: no`.
- Read/open a few PNGs directly (e.g. one small notification-size icon, one large @3x icon) to visually confirm they show the CloudVeil cloud logo cleanly, not a corrupted or black-matted image.
- Full app build (see root `CLAUDE.md` for the Bazel build command), then in Simulator: Settings → Appearance → App Icon should show the CloudVeil logo on every tile, and picking any of them should correctly update the home-screen icon.
