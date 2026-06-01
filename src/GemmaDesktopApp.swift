import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            Self.styleWindows()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Self.styleWindows()
    }

    private static func styleWindows() {
        for window in NSApplication.shared.windows {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unifiedCompact
            window.backgroundColor = NSColor(
                red: 0.055,
                green: 0.063,
                blue: 0.075,
                alpha: 1.0
            )
            window.isMovableByWindowBackground = true
            window.styleMask.insert(.fullSizeContentView)
        }
    }
}

@main
struct GemmaDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
    }
}

