import SwiftUI
import SwiftData

// MARK: - SwiftData Models

@Model
final class DailyThree {
    @Attribute(.unique) var date: Date
    var slots: [TaskSlot]

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
        self.slots = [
            TaskSlot(order: 0),
            TaskSlot(order: 1),
            TaskSlot(order: 2)
        ]
    }

    var winCount: Int { slots.filter { $0.done }.count }
    var isPerfect: Bool { winCount == 3 }
    var hasAnyTitle: Bool { slots.contains { !$0.title.isEmpty } }
}

@Model
final class TaskSlot {
    var id: UUID
    var title: String
    var done: Bool
    var order: Int

    init(order: Int) {
        self.id = UUID()
        self.title = ""
        self.done = false
        self.order = order
    }
}

// MARK: - Streak (value type, computed on the fly)

struct StreakInfo {
    var current: Int
    var best: Int
    var lastPerfectDate: Date?
}

// MARK: - AppModel

@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published private(set) var today: DailyThree?
    @Published private(set) var history: [DailyThree] = []
    @Published private(set) var streak: StreakInfo = StreakInfo(current: 0, best: 0, lastPerfectDate: nil)

    init(container: ModelContainer) {
        self.container = container
        reload()
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([DailyThree.self, TaskSlot.self])
        do {
            let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [cfg])
        } catch {
            let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return (try? ModelContainer(for: schema, configurations: [cfg]))!
        }
    }

    func reload() {
        let ctx = container.mainContext
        let todayStart = Calendar.current.startOfDay(for: Date())

        // Fetch or create today's DailyThree
        let todayPred = #Predicate<DailyThree> { $0.date == todayStart }
        let todayFetch = FetchDescriptor<DailyThree>(predicate: todayPred)
        if let existing = try? ctx.fetch(todayFetch), let first = existing.first {
            today = first
        } else {
            let newDay = DailyThree(date: Date())
            ctx.insert(newDay)
            try? ctx.save()
            today = newDay
        }

        // Fetch full history sorted descending
        var descriptor = FetchDescriptor<DailyThree>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 365
        history = (try? ctx.fetch(descriptor)) ?? []

        streak = computeStreak()
    }

    func refresh() { reload() }

    // MARK: - Task operations

    func setTitle(_ title: String, slot: TaskSlot) {
        slot.title = title
        save()
    }

    func toggleDone(_ slot: TaskSlot) {
        guard !slot.title.isEmpty else { return }
        slot.done.toggle()
        if slot.done { Haptics.success() } else { Haptics.tap() }
        save()
        streak = computeStreak()
    }

    func clearToday() {
        guard let t = today else { return }
        for slot in t.slots {
            slot.title = ""
            slot.done = false
        }
        save()
    }

    // MARK: - History helpers

    func winRate(days: Int) -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recent = history.filter { $0.date >= cutoff && $0.hasAnyTitle }
        guard !recent.isEmpty else { return 0 }
        let perfectDays = recent.filter { $0.isPerfect }.count
        return Double(perfectDays) / Double(recent.count)
    }

    // MARK: - Delete all

    func deleteAllData() {
        let ctx = container.mainContext
        for day in history { ctx.delete(day) }
        try? ctx.save()
        today = nil
        history = []
        streak = StreakInfo(current: 0, best: 0, lastPerfectDate: nil)
        reload()
    }

    // MARK: - Private

    private func save() {
        try? container.mainContext.save()
    }

    private func computeStreak() -> StreakInfo {
        let cal = Calendar.current
        // Sort ascending for streak walk
        let sorted = history.filter { $0.hasAnyTitle }.sorted { $0.date < $1.date }
        var current = 0
        var best = 0
        var lastPerfect: Date?

        var streak = 0
        for (i, day) in sorted.enumerated() {
            if day.isPerfect {
                if i == 0 {
                    streak = 1
                } else {
                    let prev = sorted[i - 1]
                    let diff = cal.dateComponents([.day], from: prev.date, to: day.date).day ?? 99
                    streak = (prev.isPerfect && diff == 1) ? streak + 1 : 1
                }
                lastPerfect = day.date
                best = max(best, streak)
            } else {
                streak = 0
            }
        }

        // Current streak: count back from today
        let todayStart = cal.startOfDay(for: Date())
        var cur = 0
        var checkDate = todayStart
        for day in sorted.reversed() {
            let diff = cal.dateComponents([.day], from: day.date, to: checkDate).day ?? 99
            if diff > 1 { break }
            if day.isPerfect {
                cur += 1
                checkDate = day.date
            } else {
                break
            }
        }
        current = cur

        return StreakInfo(current: current, best: best, lastPerfectDate: lastPerfect)
    }
}
