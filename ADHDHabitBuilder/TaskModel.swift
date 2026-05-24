import Foundation
import SwiftUI
import UIKit

enum CompletionMethod: String, Codable, Hashable {
    case photo   // tap → opens camera, image stored with completion
    case tap     // tap → instantly marks complete (no image)
}

struct HabitTask: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let icon: String                       // SF Symbol name
    let colorHex: String                   // "#RRGGBB"
    let completionMethod: CompletionMethod
    let points: Int                        // earned for on-time completion; half if late
    let schedule: TaskSchedule

    var color: Color { Color(hex: colorHex) }
}

enum ScoreBand {
    case red, yellow, green

    init(percent: Double) {
        switch percent {
        case ..<0.4: self = .red
        case ..<0.8: self = .yellow
        default: self = .green
        }
    }

    var color: Color {
        switch self {
        case .red: Color(hex: "EF4444")
        case .yellow: Color(hex: "F59E0B")
        case .green: Color(hex: "22C55E")
        }
    }

    var label: String {
        switch self {
        case .red: "Needs work"
        case .yellow: "On track"
        case .green: "Great day"
        }
    }
}

struct DayScore {
    let earned: Double
    let total: Double
    let percent: Double
    let band: ScoreBand

    var displayPercent: Int { Int((percent * 100).rounded()) }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var v: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xff) / 255
        let g = Double((v >> 8) & 0xff) / 255
        let b = Double(v & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}

struct TaskSchedule: Codable, Hashable {
    /// Weekdays the task applies to, using `Calendar.weekday` (1=Sunday … 7=Saturday).
    /// Empty array means every day.
    var weekdays: [Int]
    /// Earliest time the task may be completed, 24-hour "HH:mm" local time.
    /// If nil, defaults to 4 hours before `deadline`.
    var startTime: String?
    /// Deadline in 24-hour "HH:mm" local time. Completion after this is still allowed.
    var deadline: String
}

extension HabitTask {
    func appliesTo(date: Date, calendar: Calendar = .current) -> Bool {
        guard !schedule.weekdays.isEmpty else { return true }
        return schedule.weekdays.contains(calendar.component(.weekday, from: date))
    }

    func deadlineDate(on day: Date, calendar: Calendar = .current) -> Date? {
        Self.time(schedule.deadline, on: day, calendar: calendar)
    }

    /// The earliest time on `day` the user is allowed to complete this task.
    /// Falls back to deadline − 4h if `schedule.startTime` is unset.
    func startDate(on day: Date, calendar: Calendar = .current) -> Date? {
        if let raw = schedule.startTime,
           let parsed = Self.time(raw, on: day, calendar: calendar) {
            return parsed
        }
        guard let deadline = deadlineDate(on: day, calendar: calendar) else { return nil }
        return calendar.date(byAdding: .hour, value: -4, to: deadline)
    }

    private static func time(_ s: String, on day: Date, calendar: Calendar) -> Date? {
        let parts = s.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = h
        comps.minute = m
        return calendar.date(from: comps)
    }
}

struct TaskCompletion: Codable, Identifiable, Hashable {
    let id: UUID
    let taskID: UUID
    let day: Date
    let completedAt: Date
    let imageFilename: String?
}

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [HabitTask] = SampleTasks.all
    @Published private(set) var completions: [TaskCompletion] = []

    private let calendar = Calendar.current
    private let completionsURL: URL
    private let imagesDir: URL
    private let installDate: Date

    /// First day the user can navigate to (start of install day).
    var installDay: Date { calendar.startOfDay(for: installDate) }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        completionsURL = docs.appendingPathComponent("completions.json")
        imagesDir = docs.appendingPathComponent("completion-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        let defaults = UserDefaults.standard
        let key = "installDate"
        if let stored = defaults.object(forKey: key) as? Date {
            installDate = stored
        } else {
            let now = Date()
            defaults.set(now, forKey: key)
            installDate = now
        }

        loadCompletions()
    }

    func tasks(for date: Date) -> [HabitTask] {
        tasks
            .filter { $0.appliesTo(date: date, calendar: calendar) }
            .sorted { ($0.schedule.deadline, $0.title) < ($1.schedule.deadline, $1.title) }
    }

    func completion(for task: HabitTask, on date: Date) -> TaskCompletion? {
        let day = calendar.startOfDay(for: date)
        return completions.first { $0.taskID == task.id && $0.day == day }
    }

    func recordCompletion(task: HabitTask, on date: Date, image: UIImage?) {
        let day = calendar.startOfDay(for: date)
        var filename: String? = nil
        if let image, let data = image.jpegData(compressionQuality: 0.85) {
            let name = "\(UUID().uuidString).jpg"
            let url = imagesDir.appendingPathComponent(name)
            do {
                try data.write(to: url)
                filename = name
            } catch {
                print("Failed to save image: \(error)")
            }
        }
        let completion = TaskCompletion(
            id: UUID(),
            taskID: task.id,
            day: day,
            completedAt: Date(),
            imageFilename: filename
        )
        completions.removeAll { $0.taskID == task.id && $0.day == day }
        completions.append(completion)
        saveCompletions()
    }

    /// Score for a day. Returns nil for future days, pre-install days, or days with no scheduled tasks.
    func score(for date: Date) -> DayScore? {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        let installDay = calendar.startOfDay(for: installDate)
        guard day >= installDay else { return nil }
        guard day <= today else { return nil }

        let scheduled = tasks(for: date)
        guard !scheduled.isEmpty else { return nil }

        let total = scheduled.reduce(0.0) { $0 + Double($1.points) }
        var earned = 0.0
        for task in scheduled {
            guard let completion = completion(for: task, on: date) else { continue }
            let onTime: Bool = {
                guard let deadline = task.deadlineDate(on: date) else { return true }
                return completion.completedAt <= deadline
            }()
            earned += onTime ? Double(task.points) : Double(task.points) * 0.5
        }
        let percent = total > 0 ? earned / total : 0
        return DayScore(earned: earned, total: total, percent: percent, band: ScoreBand(percent: percent))
    }

    func image(for completion: TaskCompletion) -> UIImage? {
        guard let name = completion.imageFilename else { return nil }
        let url = imagesDir.appendingPathComponent(name)
        return UIImage(contentsOfFile: url.path)
    }

    private func saveCompletions() {
        do {
            let data = try JSONEncoder().encode(completions)
            try data.write(to: completionsURL)
        } catch {
            print("Failed to save completions: \(error)")
        }
    }

    private func loadCompletions() {
        guard let data = try? Data(contentsOf: completionsURL) else { return }
        if let decoded = try? JSONDecoder().decode([TaskCompletion].self, from: data) {
            completions = decoded
        }
    }
}

enum SampleTasks {
    private static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }

    static let all: [HabitTask] = [
        HabitTask(id: uuid(1), title: "Make bed",
                  icon: "bed.double.fill", colorHex: "#7C5CFF",
                  completionMethod: .photo, points: 10,
                  schedule: TaskSchedule(weekdays: [], startTime: "06:00", deadline: "08:00")),
        HabitTask(id: uuid(2), title: "Eat breakfast",
                  icon: "fork.knife", colorHex: "#FF8A3D",
                  completionMethod: .photo, points: 15,
                  schedule: TaskSchedule(weekdays: [], startTime: "07:00", deadline: "08:30")),
        HabitTask(id: uuid(3), title: "Brush teeth (morning)",
                  icon: "mouth.fill", colorHex: "#00C2D1",
                  completionMethod: .tap, points: 10,
                  schedule: TaskSchedule(weekdays: [], startTime: "07:00", deadline: "08:45")),
        HabitTask(id: uuid(4), title: "Pack school bag",
                  icon: "backpack.fill", colorHex: "#FF5C8A",
                  completionMethod: .photo, points: 15,
                  schedule: TaskSchedule(weekdays: [2, 3, 4, 5, 6], startTime: "07:00", deadline: "09:00")),
        HabitTask(id: uuid(5), title: "Homework",
                  icon: "pencil.and.list.clipboard", colorHex: "#FFB627",
                  completionMethod: .photo, points: 25,
                  schedule: TaskSchedule(weekdays: [2, 3, 4, 5, 6], startTime: "15:30", deadline: "18:00")),
        HabitTask(id: uuid(6), title: "Clean room",
                  icon: "sparkles", colorHex: "#22C55E",
                  completionMethod: .photo, points: 30,
                  schedule: TaskSchedule(weekdays: [7], startTime: "08:00", deadline: "10:00")),
        HabitTask(id: uuid(7), title: "Tidy desk",
                  icon: "tray.fill", colorHex: "#14B8A6",
                  completionMethod: .photo, points: 20,
                  schedule: TaskSchedule(weekdays: [1], startTime: nil, deadline: "17:00")),
        HabitTask(id: uuid(8), title: "Brush teeth (night)",
                  icon: "moon.stars.fill", colorHex: "#5B5BD6",
                  completionMethod: .tap, points: 10,
                  schedule: TaskSchedule(weekdays: [], startTime: "19:30", deadline: "20:30")),
    ]
}
