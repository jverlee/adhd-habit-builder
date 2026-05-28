import Foundation
import SwiftUI
import UIKit

enum CompletionMethod: String, Codable, Hashable, CaseIterable, Identifiable {
    case photo
    case tap

    var id: String { rawValue }

    var label: String {
        switch self {
        case .photo: "Photo"
        case .tap: "Tap"
        }
    }
}

struct HabitTask: Identifiable, Codable, Hashable {
    var id: UUID
    var childID: UUID
    var title: String
    var icon: String                       // SF Symbol name
    var colorHex: String                   // "#RRGGBB"
    var completionMethod: CompletionMethod
    var points: Int
    var schedule: TaskSchedule
    /// When set, this task is a frozen past version that was replaced by a newer
    /// task (with the given UUID) after a scoring-affecting edit. Frozen versions
    /// remain visible on past days so history stays immutable, but are hidden from
    /// the active and archived admin lists.
    var supersededBy: UUID?

    var color: Color { Color(hex: colorHex) }

    var isSuperseded: Bool { supersededBy != nil }
}

struct TaskSchedule: Codable, Hashable {
    /// Calendar.weekday values (1=Sunday … 7=Saturday). Empty = every day.
    var weekdays: [Int]
    var startTime: String?                  // "HH:mm", optional
    var deadline: String                    // "HH:mm"
    /// First day the task is active. Defaults to the day it was created.
    var activeFrom: Date
    /// Last day the task is active (inclusive). `nil` means ongoing.
    /// Set to yesterday on "delete" so today+future drop it but past days keep history.
    var activeUntil: Date?
}

extension HabitTask {
    func appliesTo(date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        let from = calendar.startOfDay(for: schedule.activeFrom)
        guard day >= from else { return false }
        if let until = schedule.activeUntil,
           day > calendar.startOfDay(for: until) {
            return false
        }
        if !schedule.weekdays.isEmpty,
           !schedule.weekdays.contains(calendar.component(.weekday, from: date)) {
            return false
        }
        return true
    }

    var isArchived: Bool {
        guard let until = schedule.activeUntil else { return false }
        return Calendar.current.startOfDay(for: until) < Calendar.current.startOfDay(for: Date())
    }

    func deadlineDate(on day: Date, calendar: Calendar = .current) -> Date? {
        Self.time(schedule.deadline, on: day, calendar: calendar)
    }

    func startDate(on day: Date, calendar: Calendar = .current) -> Date? {
        guard let raw = schedule.startTime else { return nil }
        return Self.time(raw, on: day, calendar: calendar)
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

struct TaskCompletion: Identifiable, Codable, Hashable {
    var id: UUID
    var childID: UUID
    var taskID: UUID
    var day: Date
    var completedAt: Date
    var imageFilename: String?
}

struct Child: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
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

/// Curated palette + icon set used by the admin editor.
enum TaskPalette {
    static let colors: [String] = [
        "#7C5CFF", "#FF8A3D", "#00C2D1", "#FF5C8A",
        "#FFB627", "#22C55E", "#14B8A6", "#5B5BD6",
        "#EF4444", "#F59E0B", "#3B82F6", "#A855F7",
    ]

    static let icons: [String] = [
        "bed.double.fill", "fork.knife", "mouth.fill", "backpack.fill",
        "pencil.and.list.clipboard", "sparkles", "tray.fill", "moon.stars.fill",
        "book.fill", "shower.fill", "drop.fill", "leaf.fill",
        "figure.run", "music.note", "gamecontroller.fill", "heart.fill",
        "star.fill", "sun.max.fill", "cloud.fill", "trash.fill",
    ]
}

