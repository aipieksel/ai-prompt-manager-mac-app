# Data and library

Updated: 2026-09-13.

`PromptStore` encodes/decodes `PromptLibrary` as JSON with ISO-8601 dates and atomic writes. The default file is `PromptManager/library.json` beneath Application Support. Settings can select Documents or a custom location. A missing file returns the bundled sample library. Storage-location migration and backup/export are explicit user actions; do not operate on a real library during automated checks.

Source: [PromptStore.swift](../../Sources/PromptManagerCore/Services/PromptStore.swift).
