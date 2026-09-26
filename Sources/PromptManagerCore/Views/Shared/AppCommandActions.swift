import SwiftUI

public struct AppCommandActions {
    public var newPrompt: () -> Void
    public var newFolder: () -> Void
    public var save: () -> Void
    public var duplicate: () -> Void
    public var delete: () -> Void
    public var copyPrompt: () -> Void
    public var hasSelectedPrompt: Bool
}

private struct AppCommandActionsKey: FocusedValueKey {
    typealias Value = AppCommandActions
}

public extension FocusedValues {
    var promptCommandActions: AppCommandActions? {
        get { self[AppCommandActionsKey.self] }
        set { self[AppCommandActionsKey.self] = newValue }
    }
}
