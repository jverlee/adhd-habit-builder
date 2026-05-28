import SwiftUI

struct AdminPasswordView<Destination: View>: View {
    let title: String
    @ViewBuilder let destination: () -> Destination

    @Environment(\.dismiss) private var dismiss
    @State private var entered = ""
    @State private var error: String?
    @State private var showingDestination = false
    @FocusState private var focused: Bool

    private let correctPassword = "5555"

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "5B5BD6").opacity(0.15))
                            .frame(width: 96, height: 96)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(Color(hex: "5B5BD6"))
                    }
                    .padding(.top, 32)

                    VStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("Enter the 4-digit code.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    SecureField("Code", text: $entered)
                        .focused($focused)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .frame(maxWidth: 220)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .onSubmit(submit)

                    if let error {
                        Text(error)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: "EF4444"))
                    }

                    Button(action: submit) {
                        Text("Unlock")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: 220)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "7C5CFF"), Color(hex: "5B5BD6")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(entered.isEmpty)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showingDestination) {
                destination()
            }
        }
        .onAppear { focused = true }
    }

    private func submit() {
        if entered == correctPassword {
            error = nil
            showingDestination = true
        } else {
            error = "Incorrect code."
            entered = ""
        }
    }
}
