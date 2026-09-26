# AI Prompt Manager Mac App

Maintained by [aipieksel](https://github.com/aipieksel).

Prompt Manager is a native SwiftUI macOS application for organizing reusable prompts, phrases and prompt chains. It includes nested folders, tags, search/filtering, variable expansion, Markdown/folder import, exports, backups, provider settings, and chain execution.

## Build and check

Requires macOS 15+, Swift 6, and a compatible Xcode toolchain. From this folder:

```sh
swift build
swift run PromptManagerChecks
```

The checks are a custom executable target, not an XCTest suite. They exercise model, import/export, library, settings, and chain behavior with temporary fixtures. Optionally set `PROMPT_LIBRARY_FIXTURE=/path/to/prompt-library` to additionally test a full library containing design/coding/content/business categories, cheat-sheet phrases, and at least 50 importable rows. An explicitly configured missing fixture fails; an unset fixture is reported as skipped.

To launch a development process, use `swift run PromptManager`. It uses the app's normal local storage and settings. The packaging script `scripts/build-app.sh` changes version metadata and can quit/open an installed copy, so inspect it before using it; building the Swift package does not install an app.

## Source and data

- `Sources/PromptManager/`: application entry point and bundle resources.
- `Sources/PromptManagerCore/`: models, SwiftUI views, storage, imports, AI providers, settings and chains.
- `Tests/PromptManagerTests/main.swift`: executable checks.
- `docs/0-index.md`: current source-backed documentation.
- `project/`: product and design reference material, not proof that every planned feature exists.

`PromptStore` persists a JSON library, normally under Application Support, with optional Documents/custom locations. It returns bundled synthetic sample prompts on first load. This implementation does not use SwiftData. Provider keys use macOS Keychain; selected AI requests are sent to the configured provider. Core library editing works locally without provider credentials. App data, backups, request logs, and actual credentials are not shared starter files.

This is an application under development. The local check executable is not proof of installed-app signing, live-provider behavior, or every rendered UI state. The owner-original source is licensed under [MIT](LICENSE). Changing the bundle identifier orphans previously installed copies that used the old identifier.

A matching full import fixture can be generated in a new temporary folder:

```sh
python3 scripts/create-test-library.py /tmp/prompt-import-example
PROMPT_LIBRARY_FIXTURE=/tmp/prompt-import-example swift run PromptManagerChecks
```

The generator refuses an existing output. It uses the importer's legacy `type: cheat-sheet` format; the separate current prompt-library package uses different reference metadata.
