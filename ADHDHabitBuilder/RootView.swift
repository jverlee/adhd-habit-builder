import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: LocalStore

    var body: some View {
        if store.children.isEmpty {
            OnboardingChildView()
        } else if let child = store.selectedChild {
            DayHomeView()
                .id(child.id)
        } else {
            ChildPickerView()
        }
    }
}
