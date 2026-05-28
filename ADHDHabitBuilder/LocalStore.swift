import Foundation
import SwiftUI
import UIKit

@MainActor
final class LocalStore: ObservableObject {
    @Published private(set) var children: [Child] = []
    @Published private(set) var tasks: [HabitTask] = []
    @Published private(set) var completions: [TaskCompletion] = []
    @Published var selectedChildId: UUID?

    let installDate: Date
    var installDay: Date { calendar.startOfDay(for: installDate) }

    private let calendar = Calendar.current
    private let storeURL: URL
    private let imagesDir: URL
    private let selectedKey = "habitBuilder.selectedChildId"

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storeURL = docs.appendingPathComponent("store.json")
        imagesDir = docs.appendingPathComponent("completion-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        let snapshot = Snapshot.load(from: storeURL) ?? Snapshot(
            children: [], tasks: [], completions: [], installDate: Date()
        )
        children = snapshot.children
        tasks = snapshot.tasks
        completions = snapshot.completions
        installDate = snapshot.installDate

        if let raw = UserDefaults.standard.string(forKey: selectedKey),
           let id = UUID(uuidString: raw),
           children.contains(where: { $0.id == id }) {
            selectedChildId = id
        }
    }

    // MARK: - Children

    @discardableResult
    func addChild(name: String) -> Child {
        let child = Child(id: UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        children.append(child)
        save()
        return child
    }

    func renameChild(_ id: UUID, to newName: String) {
        guard let idx = children.firstIndex(where: { $0.id == id }) else { return }
        children[idx].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    /// Permanently removes the child along with all their tasks, completions, and photos.
    func deleteChild(_ id: UUID) {
        let taskIDs = tasks.filter { $0.childID == id }.map(\.id)
        for tid in taskIDs { hardDeleteTask(tid) }
        children.removeAll { $0.id == id }
        completions.removeAll { $0.childID == id }
        if selectedChildId == id { clearSelection() }
        save()
    }

    func selectChild(_ id: UUID) {
        selectedChildId = id
        UserDefaults.standard.set(id.uuidString, forKey: selectedKey)
    }

    func clearSelection() {
        selectedChildId = nil
        UserDefaults.standard.removeObject(forKey: selectedKey)
    }

    var selectedChild: Child? {
        guard let id = selectedChildId else { return nil }
        return children.first { $0.id == id }
    }

    // MARK: - Tasks

    func addTask(_ task: HabitTask) {
        tasks.append(task)
        save()
    }

    func updateTask(_ task: HabitTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
        save()
    }

    /// Soft-delete: discontinue from today onward. Past days keep the task and its completions.
    func archiveTask(_ id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        tasks[idx].schedule.activeUntil = yesterday
        save()
    }

    func restoreTask(_ id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].schedule.activeUntil = nil
        save()
    }

    /// Hard-delete: removes the task and ALL its completion history (including photos).
    func hardDeleteTask(_ id: UUID) {
        let toRemove = completions.filter { $0.taskID == id }
        for c in toRemove {
            if let name = c.imageFilename {
                try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(name))
            }
        }
        completions.removeAll { $0.taskID == id }
        tasks.removeAll { $0.id == id }
        save()
    }

    /// Tasks currently active for a child (visible today + going forward).
    func activeTasks(for childID: UUID) -> [HabitTask] {
        tasks
            .filter { $0.childID == childID && !$0.isArchived }
            .sorted { ($0.schedule.deadline, $0.title) < ($1.schedule.deadline, $1.title) }
    }

    /// Tasks that have been archived (activeUntil in the past).
    func archivedTasks(for childID: UUID) -> [HabitTask] {
        tasks
            .filter { $0.childID == childID && $0.isArchived }
            .sorted { ($0.schedule.deadline, $0.title) < ($1.schedule.deadline, $1.title) }
    }

    /// Tasks scheduled on a specific date for a child — honors activeFrom/activeUntil
    /// so past days continue to show tasks that were active then.
    func tasksScheduled(child childID: UUID, on date: Date) -> [HabitTask] {
        tasks
            .filter { $0.childID == childID && $0.appliesTo(date: date, calendar: calendar) }
            .sorted { ($0.schedule.deadline, $0.title) < ($1.schedule.deadline, $1.title) }
    }

    // MARK: - Completions

    func completion(child childID: UUID, task: HabitTask, on date: Date) -> TaskCompletion? {
        let day = calendar.startOfDay(for: date)
        return completions.first { $0.childID == childID && $0.taskID == task.id && $0.day == day }
    }

    func recordCompletion(child childID: UUID, task: HabitTask, on date: Date, image: UIImage?) {
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
            childID: childID,
            taskID: task.id,
            day: day,
            completedAt: Date(),
            imageFilename: filename
        )
        removeCompletion(child: childID, task: task, on: day)
        completions.append(completion)
        save()
    }

    /// Admin override — set or clear a completion without going through the camera.
    func setCompletion(child childID: UUID, task: HabitTask, on date: Date, completed: Bool) {
        let day = calendar.startOfDay(for: date)
        if completed {
            if completion(child: childID, task: task, on: day) != nil { return }
            let c = TaskCompletion(
                id: UUID(), childID: childID, taskID: task.id,
                day: day, completedAt: Date(), imageFilename: nil
            )
            completions.append(c)
        } else {
            removeCompletion(child: childID, task: task, on: day)
        }
        save()
    }

    private func removeCompletion(child childID: UUID, task: HabitTask, on day: Date) {
        for c in completions where c.childID == childID && c.taskID == task.id && c.day == day {
            if let name = c.imageFilename {
                try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(name))
            }
        }
        completions.removeAll { $0.childID == childID && $0.taskID == task.id && $0.day == day }
    }

    func image(for completion: TaskCompletion) -> UIImage? {
        guard let name = completion.imageFilename else { return nil }
        let url = imagesDir.appendingPathComponent(name)
        return UIImage(contentsOfFile: url.path)
    }

    func score(child childID: UUID, on date: Date) -> DayScore? {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        guard day >= installDay else { return nil }
        guard day <= today else { return nil }

        let scheduled = tasksScheduled(child: childID, on: date)
        guard !scheduled.isEmpty else { return nil }

        let total = scheduled.reduce(0.0) { $0 + Double($1.points) }
        var earned = 0.0
        for task in scheduled {
            guard let c = completion(child: childID, task: task, on: date) else { continue }
            let onTime: Bool = {
                guard let deadline = task.deadlineDate(on: date) else { return true }
                return c.completedAt <= deadline
            }()
            earned += onTime ? Double(task.points) : Double(task.points) * 0.5
        }
        let percent = total > 0 ? earned / total : 0
        return DayScore(earned: earned, total: total, percent: percent, band: ScoreBand(percent: percent))
    }

    // MARK: - Persistence

    private func save() {
        let snapshot = Snapshot(
            children: children, tasks: tasks,
            completions: completions, installDate: installDate
        )
        snapshot.save(to: storeURL)
    }

    private struct Snapshot: Codable {
        var children: [Child]
        var tasks: [HabitTask]
        var completions: [TaskCompletion]
        var installDate: Date

        static func load(from url: URL) -> Snapshot? {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Snapshot.self, from: data)
        }

        func save(to url: URL) {
            do {
                let data = try JSONEncoder().encode(self)
                try data.write(to: url, options: .atomic)
            } catch {
                print("Failed to save store: \(error)")
            }
        }
    }
}
