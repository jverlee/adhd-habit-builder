import SwiftUI

struct DayEditorView: View {
    let childID: UUID
    @EnvironmentObject private var store: LocalStore
    @State private var date: Date = Calendar.current.startOfDay(for: Date())

    private var scheduled: [HabitTask] {
        store.tasksScheduled(child: childID, on: date)
    }

    var body: some View {
        Form {
            Section {
                DatePicker(
                    "Date",
                    selection: $date,
                    in: store.installDay...Calendar.current.startOfDay(for: Date()),
                    displayedComponents: .date
                )
            }

            Section {
                if scheduled.isEmpty {
                    Text("No tasks were scheduled on this day.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(scheduled) { task in
                        taskRow(task)
                    }
                }
            } header: {
                Text("Scheduled tasks")
            } footer: {
                Text("Toggle to mark complete or not complete. Admin overrides don't include photos.")
            }
        }
        .navigationTitle("Override completions")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func taskRow(_ task: HabitTask) -> some View {
        let completion = store.completion(child: childID, task: task, on: date)
        let isComplete = completion != nil
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(task.color.gradient)
                    .frame(width: 36, height: 36)
                Image(systemName: task.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(subtitle(task: task, completion: completion))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { isComplete },
                set: { newValue in
                    store.setCompletion(child: childID, task: task, on: date, completed: newValue)
                }
            ))
            .labelsHidden()
        }
    }

    private func subtitle(task: HabitTask, completion: TaskCompletion?) -> String {
        if let completion {
            let f = DateFormatter()
            f.timeStyle = .short
            let when = f.string(from: completion.completedAt)
            return completion.imageFilename != nil
                ? "Completed \(when) (photo)"
                : "Completed \(when)"
        }
        return "Not completed"
    }
}

#Preview {
    let store = LocalStore()
    let child = store.addChild(name: "Demo")
    return NavigationStack {
        DayEditorView(childID: child.id)
    }
    .environmentObject(store)
}
