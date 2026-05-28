import SwiftUI

struct OnboardingChildView: View {
    @EnvironmentObject private var store: LocalStore
    @Environment(\.dismiss) private var dismiss
    let allowDismiss: Bool

    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    init(allowDismiss: Bool = false) {
        self.allowDismiss = allowDismiss
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "FAFBFF"), Color(hex: "EDF0FA")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                if allowDismiss {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary, .quaternary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }

                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(hex: "00C2D1"), Color(hex: "7C5CFF")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 92, height: 92)
                            .shadow(color: Color(hex: "7C5CFF").opacity(0.3), radius: 16, y: 8)
                        Image(systemName: "person.fill.badge.plus")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 8) {
                        Text(store.children.isEmpty ? "Add your first child" : "Add a child")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("We'll build their habit calendar from here.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    TextField("Child's name", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .padding(.vertical, 14)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(nameFocused ? Color(hex: "7C5CFF") : Color.clear, lineWidth: 2)
                        )
                        .frame(maxWidth: 360)
                        .onSubmit(submit)

                    Button(action: submit) {
                        Text("Create")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: 360)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "7C5CFF"), Color(hex: "5B5BD6")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                in: Capsule()
                            )
                            .opacity(canSubmit ? 1 : 0.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear { nameFocused = true }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canSubmit else { return }
        let child = store.addChild(name: name)
        if allowDismiss {
            dismiss()
        } else {
            store.selectChild(child.id)
        }
    }
}

#Preview {
    OnboardingChildView()
        .environmentObject(LocalStore())
}
