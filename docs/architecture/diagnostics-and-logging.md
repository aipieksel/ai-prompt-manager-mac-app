# Diagnostics

Updated: 2026-09-13.

`AIRequestLogService` captures configurable local AI request diagnostics. `AppViewModel` reports user-visible operation failures, and `PromptStore` throws file/decoding errors. Treat logs, prompts and exports as private user data; use synthetic fixtures for bug reports.

Source: [AIRequestLogService.swift](../../Sources/PromptManagerCore/Services/AIRequestLogService.swift).
