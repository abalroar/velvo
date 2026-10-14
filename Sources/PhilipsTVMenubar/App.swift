import SwiftUI
import AppKit

@main
enum Entry {
    static func main() {
        let arguments = CommandLine.arguments
        if arguments.contains("--self-check") { exit(SelfCheck.run()) }
        if CLI.handles(arguments) { CLI.run(arguments) }
        PhilipsTVApp.main()
    }
}

struct PhilipsTVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            RemoteView(store: delegate.store)
        } label: {
            MenuBarIcon(store: delegate.store)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarIcon: View {
    @ObservedObject var store: RemoteStore
    var body: some View {
        Image(systemName: store.isConnected ? "tv.fill" : "tv")
            .accessibilityLabel("PhilipsTV Menubar")
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = RemoteStore()
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Leave keys alone while a text field is being edited.
            if event.window?.firstResponder is NSText { return event }
            guard let self else { return event }
            return MainActor.assumeIsolated { self.store.handleKeyDown(event) } ? nil : event
        }
        if store.isPaired { store.connect() }
    }
}
