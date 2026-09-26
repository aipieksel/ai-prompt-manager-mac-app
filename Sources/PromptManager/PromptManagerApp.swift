import PromptManagerCore
import SwiftUI

@main
struct PromptManagerApp: App {
    var body: some Scene {
        WindowGroup("Prompt Manager") {
            ContentView()
                .frame(minWidth: 1200, minHeight: 760)
        }
        .defaultSize(width: 1440, height: 1024)
        .windowStyle(.hiddenTitleBar)
        .commands { PromptCommands() }
    }
}
