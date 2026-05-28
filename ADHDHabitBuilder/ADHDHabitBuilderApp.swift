import SwiftUI

@main
struct ADHDHabitBuilderApp: App {
    @StateObject private var store = LocalStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
