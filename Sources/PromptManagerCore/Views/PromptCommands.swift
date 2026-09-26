import SwiftUI

public struct PromptCommands: Commands {
    @FocusedValue(\.promptCommandActions) private var actions

    public init() {}

    public var body: some Commands {
        CommandMenu("Prompt") {
            Button("New Prompt") { actions?.newPrompt() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(actions == nil)
            Button("New Folder") { actions?.newFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(actions == nil)
            Divider()
            Button("Save") { actions?.save() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(actions == nil)
            Button("Duplicate Prompt") { actions?.duplicate() }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(actions?.hasSelectedPrompt != true)
            Button("Delete Prompt") { actions?.delete() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(actions?.hasSelectedPrompt != true)
            Button("Copy Full Prompt") { actions?.copyPrompt() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(actions?.hasSelectedPrompt != true)
        }
    }
}
