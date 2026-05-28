import SwiftUI

struct AdminView: View {
    let childID: UUID
    @EnvironmentObject private var store: LocalStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingTask: HabitTask?
    @State private var addingTask = false
    @State private var confirmingHardDelete: HabitTask?
    @State private var showingArchived = false

    private var child: Child? { store.children.first { $0.id == childID } }
    private var activeTasks: [HabitTask] { store.activeTasks(for: childID) }
    private var archivedTasks: [HabitTask] { store.archivedTasks(for: childID) }

    var body: some View {
        List {
            Section {
                ForEach(activeTasks) { task in
                    Button {
                        editingTask = task
                    } label: {
                        taskRow(task)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.archiveTask(task.id)
                        } label: {
                            Label("Discontinue", systemImage: "archivebox")
                        }
                    }
                }

                Button {
                    addingTask = true
                } label: {
                    Label("Add task", systemImage: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            } header: {
                Text("Active tasks (\(activeTasks.count))")
            } footer: {
                Text("Discontinuing a task stops it from today onward but keeps history for past days.")
            }

            Section {
                NavigationLink {
                    DayEditorView(childID: childID)
                } label: {
                    Label("Override completions", systemImage: "checkmark.circle.badge.questionmark")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            } header: {
                Text("History")
            } footer: {
                Text("Mark tasks complete or not complete for any day in the past or today.")
            }

            if !archivedTasks.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showingArchived) {
                        ForEach(archivedTasks) { task in
                            HStack {
                                taskRow(task)
                                    .opacity(0.6)
                                Spacer()
                                Menu {
                                    Button {
                                        store.restoreTask(task.id)
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    Button(role: .destructive) {
                                        confirmingHardDelete = task
                                    } label: {
                                        Label("Delete permanently", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } label: {
                        Text("Archived (\(archivedTasks.count))")
                    }
                }
            }
        }
        .navigationTitle(child?.name ?? "Admin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $editingTask) { task in
            NavigationStack {
                TaskEditorView(task: task) { updated in
                    store.updateTask(updated)
                    editingTask = nil
                }
            }
        }
        .sheet(isPresented: $addingTask) {
            NavigationStack {
                TaskEditorView(task: HabitTask.blank(childID: childID)) { newTask in
                    store.addTask(newTask)
                    addingTask = false
                }
            }
        }
        .alert(item: $confirmingHardDelete) { task in
            Alert(
                title: Text("Delete \"\(task.title)\"?"),
                message: Text("Deletes the task and ALL its completion history (including photos). This cannot be undone."),
                primaryButton: .destructive(Text("Delete forever")) {
                    store.hardDeleteTask(task.id)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func taskRow(_ task: HabitTask) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(task.color.gradient)
                    .frame(width: 38, height: 38)
                Image(systemName: task.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(detailLine(task))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func detailLine(_ task: HabitTask) -> String {
        var parts: [String] = []
        parts.append("\(task.points) pts")
        parts.append(task.completionMethod.label)
        parts.append("by \(task.schedule.deadline)")
        if task.schedule.weekdays.isEmpty {
            parts.append("every day")
        } else {
            let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            parts.append(task.schedule.weekdays.sorted().map { names[$0 - 1] }.joined(separator: " "))
        }
        return parts.joined(separator: " · ")
    }
}

extension HabitTask {
    static func blank(childID: UUID) -> HabitTask {
        HabitTask(
            id: UUID(),
            childID: childID,
            title: "",
            icon: TaskPalette.icons.first ?? "star.fill",
            colorHex: TaskPalette.colors.first ?? "#7C5CFF",
            completionMethod: .tap,
            points: 10,
            schedule: TaskSchedule(
                weekdays: [],
                startTime: nil,
                deadline: "20:00",
                activeFrom: Calendar.current.startOfDay(for: Date()),
                activeUntil: nil
            )
        )
    }
}

#Preview {
    let store = LocalStore()
    let child = store.addChild(name: "Demo")
    return NavigationStack {
        AdminView(childID: child.id)
    }
    .environmentObject(store)
}
