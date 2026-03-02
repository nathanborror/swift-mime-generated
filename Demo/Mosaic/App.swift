import SwiftUI

@main
struct MosaicApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            EditorView()
        }
    }
}
