import SwiftUI

@main
struct AliviaApp: App {
    init() {
        CareModule.reminderScheduler.activate()
    }

    var body: some Scene {
        WindowGroup {
            AppNavigation()
        }
    }
}
