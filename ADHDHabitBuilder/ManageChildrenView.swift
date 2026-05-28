import SwiftUI

struct ManageChildrenView: View {
    @EnvironmentObject private var store: LocalStore
    @Environment(\.dismiss) private var dismiss
    @State private var addingChild = false
    @State private var renamingChild: Child?
    @State private var confirmingDelete: Child?

    var body: some View {
        List {
            Section {
                ForEach(store.children) { child in
                    HStack {
                        Text(child.name)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                        Spacer()
                        Button("Rename") { renamingChild = child }
                            .font(.system(size: 14, weight: .medium))
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            confirmingDelete = child
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Button {
                    addingChild = true
                } label: {
                    Label("Add child", systemImage: "person.crop.circle.badge.plus")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            } header: {
                Text("Children (\(store.children.count))")
            } footer: {
                Text("Deleting a child permanently removes their tasks, completions, and photos.")
            }
        }
        .navigationTitle("Children")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $addingChild) {
            ChildNameSheet(title: "Add child", initialName: "") { name in
                store.addChild(name: name)
            }
        }
        .sheet(item: $renamingChild) { child in
            ChildNameSheet(title: "Rename", initialName: child.name) { name in
                store.renameChild(child.id, to: name)
            }
        }
        .alert(item: $confirmingDelete) { child in
            Alert(
                title: Text("Delete \(child.name)?"),
                message: Text("This permanently removes all their tasks, completions, and photos. This cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    store.deleteChild(child.id)
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct ChildNameSheet: View {
    let title: String
    let initialName: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .focused($focused)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            name = initialName
            focused = true
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
        dismiss()
    }
}

#Preview {
    NavigationStack { ManageChildrenView() }
        .environmentObject(LocalStore())
}
