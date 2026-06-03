# Sentry XCFramework

## Setup

The `Sentry.xcframework` is **not committed** to the repository — it's downloaded on demand.

After cloning the repo, run:

```sh
./scripts/download-sentry.sh
```

This downloads Sentry 8.41.0 and extracts it into this directory. The script checks if it's already present and skips download if so.

## Why gitignore?

- `Sentry.xcframework/` is large (~31 MB).
- It's a pre-built binary with no source changes needed.
- Downloading at setup is simpler and cleaner than committing binaries.

## Integration

- `BUILD` file defines the Bazel target `//third-party/Sentry:Sentry` using `apple_static_xcframework_import`.
- Consumers (CloudVeil/SecurityManager, TelegramUI) depend on `//third-party/Sentry:Sentry`.
- This approach works with `rules_xcodeproj` (local workspace paths are resolvable; external repos via `http_archive` are not).

## Updating Sentry

If upgrading to a newer version:

1. Update the URL and SHA256 in `scripts/download-sentry.sh`.
2. Delete the current `Sentry.xcframework/` directory.
3. Run the updated script.
