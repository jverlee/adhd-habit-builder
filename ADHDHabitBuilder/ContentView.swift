import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var store = TaskStore()
    @State private var dayOffset: Int = 0
    @State private var showingMonthView = false

    private var pageRange: ClosedRange<Int> {
        let today = Calendar.current.startOfDay(for: Date())
        let earliest = Calendar.current.dateComponents([.day], from: today, to: store.installDay).day ?? 0
        return min(earliest, 0)...3650
    }

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                TabView(selection: $dayOffset) {
                    ForEach(pageRange, id: \.self) { offset in
                        DayPage(date: Self.date(forOffset: offset))
                            .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .environmentObject(store)
        .sheet(isPresented: $showingMonthView) {
            MonthView(initialMonth: Self.date(forOffset: dayOffset)) { selectedDate in
                let today = Calendar.current.startOfDay(for: Date())
                let target = Calendar.current.startOfDay(for: selectedDate)
                let offset = Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    dayOffset = offset
                }
            }
            .environmentObject(store)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(hex: "FAFBFF"), Color(hex: "EDF0FA")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var header: some View {
        let date = Self.date(forOffset: dayOffset)
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayLabel(offset: dayOffset, date: date))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(Self.fullDateFormatter.string(from: date))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let score = store.score(for: date) {
                ScoreBadge(score: score)
            }
            if dayOffset != 0 {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        dayOffset = 0
                    }
                } label: {
                    Text("Today")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "7C5CFF"), Color(hex: "5B5BD6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                        .shadow(color: Color(hex: "7C5CFF").opacity(0.35), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
            Button {
                showingMonthView = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.06), lineWidth: 1))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func dayLabel(offset: Int, date: Date) -> String {
        switch offset {
        case 0: return "Today"
        case -1: return "Yesterday"
        case 1: return "Tomorrow"
        default: return Self.weekdayFormatter.string(from: date)
        }
    }

    private static func date(forOffset offset: Int) -> Date {
        let start = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: offset, to: start) ?? start
    }

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEMMMMdyyyy")
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()
}

private struct DayPage: View {
    let date: Date
    @EnvironmentObject private var store: TaskStore
    @State private var capturingTask: HabitTask?
    @State private var showingCameraUnavailable = false

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        let tasks = store.tasks(for: date)
        let completed = tasks.filter { store.completion(for: $0, on: date) != nil }.count

        let score = store.score(for: date)

        ScrollView {
            VStack(spacing: 18) {
                if !tasks.isEmpty {
                    ProgressHeader(completed: completed, total: tasks.count, score: score)
                }

                if tasks.isEmpty {
                    emptyState
                } else {
                    TimelineView(.periodic(from: Date(), by: 30)) { context in
                        VStack(spacing: 12) {
                            ForEach(tasks) { task in
                                let unlockTime = task.startDate(on: date)
                                let locked = isToday
                                    && unlockTime.map { context.date < $0 } ?? false
                                TaskCard(
                                    task: task,
                                    day: date,
                                    completion: store.completion(for: task, on: date),
                                    interactive: isToday && !locked,
                                    lockedUntil: locked ? unlockTime : nil
                                )
                                .onTapGesture {
                                    handleTap(task: task, now: context.date)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 48)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .opacity(isToday ? 1.0 : 0.55)
            .allowsHitTesting(isToday)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $capturingTask) { task in
            CameraPicker { image in
                if let image {
                    store.recordCompletion(task: task, on: date, image: image)
                }
            }
            .ignoresSafeArea()
        }
        .alert("Camera unavailable", isPresented: $showingCameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Run the app on a real iPad to take photos.")
        }
    }

    private func handleTap(task: HabitTask, now: Date) {
        guard isToday else { return }
        guard store.completion(for: task, on: date) == nil else { return }
        if let unlockTime = task.startDate(on: date), now < unlockTime { return }

        switch task.completionMethod {
        case .photo:
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                capturingTask = task
            } else {
                showingCameraUnavailable = true
            }
        case .tap:
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                store.recordCompletion(task: task, on: date, image: nil)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "7C5CFF").opacity(0.15), Color(hex: "00C2D1").opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 96, height: 96)
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color(hex: "7C5CFF"))
            }
            Text("Nothing scheduled")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text("Enjoy the day off.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 48)
    }
}

private struct ProgressHeader: View {
    let completed: Int
    let total: Int
    let score: DayScore?

    private var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(completed) / CGFloat(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(completed) of \(total) done")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                if let score {
                    Text(score.band.label)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(score.band.color)
                }
            }
            if let score {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(score.band.color.gradient)
                            .frame(width: geo.size.width * fraction)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: fraction)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}

private struct ScoreBadge: View {
    let score: DayScore

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(score.band.color)
                .frame(width: 9, height: 9)
            Text("\(score.displayPercent)%")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(score.band.color)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: score.displayPercent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(score.band.color.opacity(0.12), in: Capsule())
        .overlay(
            Capsule().stroke(score.band.color.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct TaskCard: View {
    let task: HabitTask
    let day: Date
    let completion: TaskCompletion?
    let interactive: Bool
    let lockedUntil: Date?
    @EnvironmentObject private var store: TaskStore

    private var isComplete: Bool { completion != nil }
    private var isLocked: Bool { lockedUntil != nil }

    var body: some View {
        HStack(spacing: 16) {
            iconBadge
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(isComplete || isLocked ? .secondary : .primary)
                    .strikethrough(isComplete, color: .secondary)
                HStack(spacing: 10) {
                    if let lockedUntil, completion == nil {
                        Label("unlocks at " + timeString(lockedUntil), systemImage: "lock.fill")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        Label(deadlineText, systemImage: "clock")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        if let completion {
                            Label(timeString(completion.completedAt), systemImage: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: "22C55E"))
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            trailingAffordance
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isComplete ? task.color.opacity(0.25) : .clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(task.color.gradient)
                .frame(width: 56, height: 56)
                .shadow(color: task.color.opacity(0.35), radius: 8, y: 4)
            Image(systemName: task.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
        }
        .opacity(isComplete || isLocked ? 0.6 : 1)
        .saturation(isLocked ? 0.4 : 1)
    }

    @ViewBuilder
    private var trailingAffordance: some View {
        if let completion, let image = store.image(for: completion) {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white, Color(hex: "22C55E"))
                    .background(Circle().fill(.white).padding(2))
                    .offset(x: 4, y: 4)
            }
        } else if isComplete {
            ZStack {
                Circle()
                    .fill(Color(hex: "22C55E"))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
        } else if isLocked {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "lock.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        } else if interactive {
            ZStack {
                Circle()
                    .fill(task.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: task.completionMethod == .photo ? "camera.fill" : "circle.dashed")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(task.color)
            }
        } else {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1.5)
                .frame(width: 44, height: 44)
        }
    }

    private var deadlineText: String {
        guard let date = task.deadlineDate(on: day) else { return task.schedule.deadline }
        return "by " + Self.timeFormatter.string(from: date)
    }

    private func timeString(_ d: Date) -> String {
        Self.timeFormatter.string(from: d)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}

private struct MonthView: View {
    @State private var visibleMonth: Date
    let onSelectDay: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TaskStore

    private let calendar: Calendar = .current

    init(initialMonth: Date, onSelectDay: @escaping (Date) -> Void) {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: initialMonth)) ?? initialMonth
        _visibleMonth = State(initialValue: start)
        self.onSelectDay = onSelectDay
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "FAFBFF"), Color(hex: "EDF0FA")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                topBar
                monthSwitcher
                weekdayHeader
                daysGrid
                legend
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private var topBar: some View {
        HStack {
            Text("Calendar")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary, .quaternary)
            }
            .buttonStyle(.plain)
        }
    }

    private var monthSwitcher: some View {
        HStack {
            navButton(systemImage: "chevron.left") { shiftMonth(-1) }
            Spacer()
            Text(monthTitle)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: visibleMonth)
            Spacer()
            navButton(systemImage: "chevron.right") { shiftMonth(1) }
        }
    }

    private func navButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 40, height: 40)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.06), lineWidth: 1))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstWeekday = calendar.firstWeekday
        let rotated = Array(symbols[(firstWeekday - 1)...] + symbols[..<(firstWeekday - 1)])
        return HStack(spacing: 8) {
            ForEach(rotated, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysGrid: some View {
        let days = daysForGrid()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(days, id: \.self) { day in
                let inMonth = calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month)
                let isToday = calendar.isDateInToday(day)
                let beforeInstall = day < store.installDay
                let score = inMonth ? store.score(for: day) : nil
                DayCell(
                    date: day,
                    inMonth: inMonth,
                    isToday: isToday,
                    score: score,
                    disabled: beforeInstall
                )
                .onTapGesture {
                    guard inMonth, !beforeInstall else { return }
                    onSelectDay(day)
                    dismiss()
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendDot(color: ScoreBand.green.color, label: "Great")
            legendDot(color: ScoreBand.yellow.color, label: "On track")
            legendDot(color: ScoreBand.red.color, label: "Needs work")
            Spacer()
        }
        .padding(.top, 4)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func shiftMonth(_ months: Int) {
        if let new = calendar.date(byAdding: .month, value: months, to: visibleMonth) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                visibleMonth = new
            }
        }
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: visibleMonth)
    }

    private func daysForGrid() -> [Date] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)),
              let monthRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date] = []
        for i in stride(from: leadingBlanks, to: 0, by: -1) {
            if let d = calendar.date(byAdding: .day, value: -i, to: monthStart) {
                days.append(d)
            }
        }
        for day in 1...monthRange.count {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(d)
            }
        }
        while days.count % 7 != 0, let last = days.last,
              let next = calendar.date(byAdding: .day, value: 1, to: last) {
            days.append(next)
        }
        return days
    }
}

private struct DayCell: View {
    let date: Date
    let inMonth: Bool
    let isToday: Bool
    let score: DayScore?
    let disabled: Bool

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundFill)
            if isToday {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(hex: "7C5CFF"), lineWidth: 2.5)
            }
            Text(dayNumber)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(inMonth ? (disabled ? 0.35 : 1) : 0.25)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var backgroundFill: Color {
        guard inMonth else { return Color.primary.opacity(0.02) }
        if let score { return score.band.color.opacity(0.22) }
        return Color.primary.opacity(0.04)
    }

    private var textColor: Color {
        guard inMonth else { return .secondary }
        if disabled { return .secondary }
        if let score { return score.band.color }
        return .primary
    }
}

#Preview {
    ContentView()
}
