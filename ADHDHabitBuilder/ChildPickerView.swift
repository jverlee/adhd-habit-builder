import SwiftUI

struct ChildPickerView: View {
    @EnvironmentObject private var store: LocalStore
    @State private var showingAdd = false
    @State private var showingAdminGate = false

    private let palette: [String] = [
        "#7C5CFF", "#FF8A3D", "#00C2D1", "#FF5C8A",
        "#FFB627", "#22C55E", "#14B8A6", "#5B5BD6",
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "FAFBFF"), Color(hex: "EDF0FA")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Who's using the iPad?")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Tap a child to see their habits.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showingAdminGate = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.06), lineWidth: 1))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)

                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3),
                        spacing: 18
                    ) {
                        ForEach(Array(store.children.enumerated()), id: \.element.id) { idx, child in
                            childCard(child, color: Color(hex: palette[idx % palette.count]))
                                .onTapGesture { store.selectChild(child.id) }
                        }
                        addCard
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showingAdd) {
            OnboardingChildView(allowDismiss: true)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingAdminGate) {
            AdminPasswordView(title: "Manage children") {
                ManageChildrenView()
            }
            .environmentObject(store)
        }
    }

    private func childCard(_ child: Child, color: Color) -> some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(color.gradient)
                    .frame(width: 110, height: 110)
                    .shadow(color: color.opacity(0.3), radius: 12, y: 6)
                Text(initials(child.name))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(child.name)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var addCard: some View {
        Button {
            showingAdd = true
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            Color.secondary.opacity(0.35),
                            style: StrokeStyle(lineWidth: 2, dash: [6, 6])
                        )
                        .frame(width: 110, height: 110)
                    Image(systemName: "plus")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text("Add child")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground).opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

#Preview {
    ChildPickerView()
        .environmentObject(LocalStore())
}
