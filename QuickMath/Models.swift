import SwiftUI
import SwiftData

// MARK: - SwiftData Models

@Model
final class TrackedCategory {
    var id: UUID
    var name: String
    var colorTag: String   // hex string e.g. "#007AFF"
    var order: Int

    init(id: UUID = UUID(), name: String, colorTag: String, order: Int) {
        self.id = id
        self.name = name
        self.colorTag = colorTag
        self.order = order
    }

    var displayColor: Color {
        Color(hex: colorTag)
    }
}

@Model
final class TimeEntry {
    var id: UUID
    var categoryID: UUID
    var startedAt: Date
    var endedAt: Date?

    init(id: UUID = UUID(), categoryID: UUID, startedAt: Date, endedAt: Date? = nil) {
        self.id = id
        self.categoryID = categoryID
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }
}

@Model
final class DayRollup {
    var id: UUID
    var date: Date
    // JSON-encoded [categoryID: minutes]
    var perCategoryMinutesData: Data

    init(id: UUID = UUID(), date: Date, perCategoryMinutesData: Data = Data()) {
        self.id = id
        self.date = date
        self.perCategoryMinutesData = perCategoryMinutesData
    }

    var perCategoryMinutes: [String: Int] {
        get {
            (try? JSONDecoder().decode([String: Int].self, from: perCategoryMinutesData)) ?? [:]
        }
        set {
            perCategoryMinutesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
}

// MARK: - AppModel

@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published private(set) var categories: [TrackedCategory] = []
    @Published private(set) var todayEntries: [TimeEntry] = []
    @Published private(set) var activeEntry: TimeEntry?

    init(container: ModelContainer) {
        self.container = container
        reload()
        seedDefaultCategoriesIfNeeded()
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([TrackedCategory.self, TimeEntry.self, DayRollup.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }
        // fallback
        let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return (try? ModelContainer(for: schema, configurations: [fallback]))!
    }

    func reload() {
        let ctx = container.mainContext
        let allCats = (try? ctx.fetch(FetchDescriptor<TrackedCategory>(sortBy: [SortDescriptor(\.order)]))) ?? []
        categories = allCats

        let todayStart = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.startedAt >= todayStart },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        let entries = (try? ctx.fetch(descriptor)) ?? []
        todayEntries = entries
        activeEntry = entries.last(where: { $0.endedAt == nil })
    }

    func refresh() { reload() }

    // MARK: - Category management (free: up to 5; unlimited = Pro)

    var canAddCategory: Bool {
        (store?.isPro == true) || categories.count < 5
    }

    func addCategory(name: String, colorTag: String) {
        let ctx = container.mainContext
        let newOrder = (categories.map(\.order).max() ?? -1) + 1
        let cat = TrackedCategory(name: name, colorTag: colorTag, order: newOrder)
        ctx.insert(cat)
        try? ctx.save()
        reload()
    }

    func deleteCategory(_ cat: TrackedCategory) {
        let ctx = container.mainContext
        ctx.delete(cat)
        try? ctx.save()
        reload()
    }

    // MARK: - Tracking

    func startTracking(category: TrackedCategory) {
        let ctx = container.mainContext
        // Close the current active entry
        if let active = activeEntry {
            active.endedAt = Date()
        }
        let entry = TimeEntry(categoryID: category.id, startedAt: Date())
        ctx.insert(entry)
        try? ctx.save()
        reload()
    }

    func stopTracking() {
        let ctx = container.mainContext
        if let active = activeEntry {
            active.endedAt = Date()
            try? ctx.save()
        }
        reload()
    }

    // MARK: - Today's pie data

    struct CategoryMinutes: Identifiable {
        let id: UUID
        let name: String
        let colorTag: String
        let minutes: Int
        var color: Color { Color(hex: colorTag) }
        var fraction: Double = 0
    }

    func todayBreakdown() -> [CategoryMinutes] {
        var totals: [UUID: TimeInterval] = [:]
        for entry in todayEntries {
            let dur = entry.duration
            totals[entry.categoryID, default: 0] += dur
        }
        var result: [CategoryMinutes] = []
        for cat in categories {
            let secs = totals[cat.id] ?? 0
            let mins = max(0, Int(secs / 60))
            result.append(CategoryMinutes(id: cat.id, name: cat.name, colorTag: cat.colorTag, minutes: mins))
        }
        let total = result.map { Double($0.minutes) }.reduce(0, +)
        if total > 0 {
            result = result.map {
                var c = $0; c.fraction = Double($0.minutes) / total; return c
            }
        }
        return result.filter { $0.minutes > 0 }
    }

    // MARK: - Weekly & monthly data (Pro)

    func weeklyBreakdown() -> [(date: Date, items: [CategoryMinutes])] {
        let ctx = container.mainContext
        var results: [(Date, [CategoryMinutes])] = []
        for offset in (0..<7).reversed() {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let start = Calendar.current.startOfDay(for: day)
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
            let descriptor = FetchDescriptor<TimeEntry>(
                predicate: #Predicate { $0.startedAt >= start && $0.startedAt < end }
            )
            let entries = (try? ctx.fetch(descriptor)) ?? []
            var totals: [UUID: TimeInterval] = [:]
            for e in entries { totals[e.categoryID, default: 0] += e.duration }
            var items: [CategoryMinutes] = []
            for cat in categories {
                let mins = Int((totals[cat.id] ?? 0) / 60)
                if mins > 0 {
                    items.append(CategoryMinutes(id: cat.id, name: cat.name, colorTag: cat.colorTag, minutes: mins))
                }
            }
            results.append((start, items))
        }
        return results
    }

    func monthlyBreakdown() -> [CategoryMinutes] {
        let ctx = container.mainContext
        let now = Date()
        let comps = Calendar.current.dateComponents([.year, .month], from: now)
        guard let monthStart = Calendar.current.date(from: comps),
              let monthEnd = Calendar.current.date(byAdding: .month, value: 1, to: monthStart) else { return [] }
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.startedAt >= monthStart && $0.startedAt < monthEnd }
        )
        let entries = (try? ctx.fetch(descriptor)) ?? []
        var totals: [UUID: TimeInterval] = [:]
        for e in entries { totals[e.categoryID, default: 0] += e.duration }
        return categories.compactMap { cat in
            let mins = Int((totals[cat.id] ?? 0) / 60)
            return mins > 0 ? CategoryMinutes(id: cat.id, name: cat.name, colorTag: cat.colorTag, minutes: mins) : nil
        }
    }

    // MARK: - Goals (Pro)

    func totalTrackedMinutesToday() -> Int {
        todayBreakdown().map(\.minutes).reduce(0, +)
    }

    // MARK: - Helpers

    func category(for id: UUID) -> TrackedCategory? {
        categories.first { $0.id == id }
    }

    func deleteAllData() {
        let ctx = container.mainContext
        for cat in (try? ctx.fetch(FetchDescriptor<TrackedCategory>())) ?? [] { ctx.delete(cat) }
        for entry in (try? ctx.fetch(FetchDescriptor<TimeEntry>())) ?? [] { ctx.delete(entry) }
        for rollup in (try? ctx.fetch(FetchDescriptor<DayRollup>())) ?? [] { ctx.delete(rollup) }
        try? ctx.save()
        reload()
    }

    private func seedDefaultCategoriesIfNeeded() {
        guard categories.isEmpty else { return }
        let defaults: [(String, String)] = [
            ("Work", "#007AFF"),
            ("Personal", "#34C759"),
            ("Health", "#FF9500"),
            ("Sleep", "#5856D6")
        ]
        let ctx = container.mainContext
        for (i, (name, color)) in defaults.enumerated() {
            ctx.insert(TrackedCategory(name: name, colorTag: color, order: i))
        }
        try? ctx.save()
        reload()
    }
}

