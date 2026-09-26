# Integrations

Updated: 2026-09-13.

`PromptFolderImportService` scans folder-based Markdown collections; `PromptMarkdownParser`, `ImportExportService` and `PromptExportService` implement parsing and export. Clipboard integration uses macOS APIs. `LiveAIProviderClient` builds provider requests and `AIKeychainService` stores provider credentials; AI operations require the configured network service.

Source: [PromptFolderImportService.swift](../../Sources/PromptManagerCore/Services/PromptFolderImportService.swift).
