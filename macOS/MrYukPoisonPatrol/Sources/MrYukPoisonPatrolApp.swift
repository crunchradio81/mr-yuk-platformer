import SwiftUI

@main
struct MrYukPoisonPatrolApp: App {
    var body: some Scene {
        WindowGroup("Mr. Yuk's Poison Patrol") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
