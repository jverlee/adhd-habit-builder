import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: HabitTask
    @State private var hasStartTime: Bool
    @State private var startTime: Date
    @State private var deadline: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    let onSave: (HabitTask) -> Void

    private let earliestActiveFrom: Date

    private static let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    init(task: HabitTask, onSave: @escaping (HabitTask) -> Void) {
        _draft = State(initialValue: task)
        _hasStartTime = State(initialValue: task.schedule.startTime != nil)
        _startTime = State(initialValue: Self.parseTime(task.schedule.startTime ?? "07:00"))
        _deadline = State(initialValue: Self.parseTime(task.schedule.deadline))
        _hasEndDate = State(initialValue: task.schedule.activeUntil != nil)
        _endDate = State(initialValue: task.schedule.activeUntil ?? Date())
        self.earliestActiveFrom = Calendar.current.startOfDay(for: task.schedule.activeFrom)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("e.g. Brush teeth", text: $draft.title)
                    .textInputAutocapitalization(.sentences)
            }

            Section("Icon") {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6),
                    spacing: 12
                ) {
                    ForEach(TaskPalette.icons, id: \.self) { icon in
                        iconCell(icon)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Color") {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6),
                    spacing: 12
                ) {
                    ForEach(TaskPalette.colors, id: \.self) { hex in
                        colorCell(hex)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Completion") {
                Picker("Method", selection: $draft.completionMethod) {
                    ForEach(CompletionMethod.allCases) { method in
                        Text(method.label).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(value: $draft.points, in: 1...100, step: 5) {
                    HStack {
                        Text("Points")
                        Spacer()
                        Text("\(draft.points)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Days of week") {
                ForEach(1...7, id: \.self) { weekday in
                    Toggle(Self.weekdayLabels[weekday - 1],
                           isOn: weekdayBinding(weekday))
                }
                Text(draft.schedule.weekdays.isEmpty
                     ? "If no days are selected, the task runs every day."
                     : "Selected \(draft.schedule.weekdays.count) day(s).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Times") {
                Toggle("Lock until start time", isOn: $hasStartTime)
                if hasStartTime {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                }
                DatePicker("Deadline", selection: $deadline, displayedComponents: .hourAndMinute)
                Text("Completed after the deadline earns half points.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Active dates") {
                DatePicker("Start date",
                           selection: $draft.schedule.activeFrom,
                           in: earliestActiveFrom...,
                           displayedComponents: .date)
                Toggle("Has end date", isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker("End date",
                               selection: $endDate,
                               in: draft.schedule.activeFrom...,
                               displayedComponents: .date)
                }
                Text("The task appears on days within this range only. It can't be moved earlier than \(Self.dateFormatter.string(from: earliestActiveFrom)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(draft.title.isEmpty ? "New task" : draft.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save", action: save)
                    .disabled(!canSave)
            }
        }
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        var t = draft
        t.title = t.title.trimmingCharacters(in: .whitespacesAndNewlines)
        t.schedule.weekdays.sort()
        t.schedule.deadline = Self.formatTime(deadline)
        t.schedule.startTime = hasStartTime ? Self.formatTime(startTime) : nil
        let clampedFrom = max(
            Calendar.current.startOfDay(for: t.schedule.activeFrom),
            earliestActiveFrom
        )
        t.schedule.activeFrom = clampedFrom
        t.schedule.activeUntil = hasEndDate
            ? Calendar.current.startOfDay(for: endDate)
            : nil
        onSave(t)
        dismiss()
    }

    private func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { draft.schedule.weekdays.contains(weekday) },
            set: { isOn in
                if isOn, !draft.schedule.weekdays.contains(weekday) {
                    draft.schedule.weekdays.append(weekday)
                } else if !isOn {
                    draft.schedule.weekdays.removeAll { $0 == weekday }
                }
            }
        )
    }

    private func iconCell(_ icon: String) -> some View {
        let selected = draft.icon == icon
        return Button {
            draft.icon = icon
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? AnyShapeStyle(draft.color.gradient) : AnyShapeStyle(Color.secondary.opacity(0.12)))
                    .frame(height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? .white : .primary)
            }
        }
        .buttonStyle(.plain)
    }

    private func colorCell(_ hex: String) -> some View {
        let selected = draft.colorHex == hex
        return Button {
            draft.colorHex = hex
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: hex).gradient)
                    .frame(width: 36, height: 36)
                    .shadow(color: Color(hex: hex).opacity(0.35), radius: 4, y: 2)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private static func parseTime(_ s: String) -> Date {
        let parts = s.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else {
            return Date()
        }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = h
        comps.minute = m
        return Calendar.current.date(from: comps) ?? Date()
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private static func formatTime(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }
}
