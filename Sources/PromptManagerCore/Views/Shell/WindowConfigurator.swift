import SwiftUI
#if os(macOS)
import AppKit
#endif

struct WindowConfigurator: NSViewRepresentable {
    var rememberSize: Bool = true
    var shouldClose: () -> Bool = { true }
    var onCloseBlocked: () -> Void = {}

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(window: view.window, context: context) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(window: nsView.window, context: context) }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func configure(window: NSWindow?, context: Context) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: DT.Size.minWindowWidth, height: DT.Size.minWindowHeight)
        let defaults = UserDefaults.standard
        let savedWidth = defaults.double(forKey: AppSettingsKeys.sessionWindowWidth)
        let savedHeight = defaults.double(forKey: AppSettingsKeys.sessionWindowHeight)
        let targetWidth = rememberSize && savedWidth >= DT.Size.minWindowWidth ? savedWidth : DT.Size.defaultWindowWidth
        let targetHeight = rememberSize && savedHeight >= DT.Size.minWindowHeight ? savedHeight : DT.Size.defaultWindowHeight
        context.coordinator.configureInitialSizeIfNeeded(window: window, size: NSSize(width: targetWidth, height: targetHeight))
        context.coordinator.shouldClose = shouldClose
        context.coordinator.onCloseBlocked = onCloseBlocked
        window.delegate = context.coordinator
        context.coordinator.observe(window: window, rememberSize: rememberSize)
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        private weak var observedWindow: NSWindow?
        private var resizeObserver: NSObjectProtocol?
        private var configuredWindowIDs = Set<ObjectIdentifier>()
        var shouldClose: () -> Bool = { true }
        var onCloseBlocked: () -> Void = {}

        func configureInitialSizeIfNeeded(window: NSWindow, size: NSSize) {
            let id = ObjectIdentifier(window)
            guard !configuredWindowIDs.contains(id) else { return }
            configuredWindowIDs.insert(id)
            window.setContentSize(NSSize(width: max(size.width, DT.Size.minWindowWidth), height: max(size.height, DT.Size.minWindowHeight)))
        }

        func observe(window: NSWindow, rememberSize: Bool) {
            if !rememberSize {
                removeObserver()
                return
            }
            if observedWindow === window { return }
            removeObserver()
            observedWindow = window
            resizeObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak window] _ in
                Task { @MainActor in
                    guard let window else { return }
                    UserDefaults.standard.set(window.frame.width, forKey: AppSettingsKeys.sessionWindowWidth)
                    UserDefaults.standard.set(window.frame.height, forKey: AppSettingsKeys.sessionWindowHeight)
                }
            }
        }

        private func removeObserver() {
            if let resizeObserver {
                NotificationCenter.default.removeObserver(resizeObserver)
            }
            resizeObserver = nil
            observedWindow = nil
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if shouldClose() { return true }
            onCloseBlocked()
            return false
        }
    }
}
