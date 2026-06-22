import SwiftUI
import Charts

// Pro-only Insights screen: weekly/monthly trends + category history.
struct InsightsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                VStack(spacing: 0) {
                    Picker("Period", selection: $selectedTab) {
                        Text("Week").tag(0)
                        Text("Month").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    ScrollView {
                        VStack(spacing: 16) {
                            if selectedTab == 0 {
                                WeeklySection()
                            } else {
                                MonthlySection()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Weekly Section

struct WeeklySection: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        let data = appModel.weeklyBreakdown()
        let allItems = data.flatMap(\.items)
        let catNames = Array(Set(allItems.map(\.name))).sorted()

        VStack(alignment: .leading, spacing: 16) {
            Text("Last 7 Days")
                .font(.headline)
                .foregroundStyle(.secondary)

            if allItems.isEmpty {
                Text("No data yet. Start tracking to see weekly trends.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                // Stacked bar chart by day
                Chart {
                    ForEach(data, id: \.date) { dayData in
                        ForEach(dayData.items) { item in
                            BarMark(
                                x: .value("Day", shortDayLabel(dayData.date)),
                                y: .value("Minutes", item.minutes)
                            )
                            .foregroundStyle(item.color)
                        }
                    }
                }
                .frame(height: 180)
                .chartLegend(.hidden)

                // Legend
                legendGrid(names: catNames, allItems: allItems)

                // Per-category totals
                VStack(spacing: 8) {
                    ForEach(catTotals(from: data)) { item in
                        HStack(spacing: 10) {
                            Circle().fill(item.color).frame(width: 10, height: 10)
                            Text(item.name).font(.subheadline)
                            Spacer()
                            Text(formatMins(item.minutes))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .qmCard()
            }
        }
    }

    private func shortDayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "E"; return f.string(from: date)
    }

    private func catTotals(from data: [(date: Date, items: [AppModel.CategoryMinutes])]) -> [AppModel.CategoryMinutes] {
        var map: [UUID: AppModel.CategoryMinutes] = [:]
        for day in data {
            for item in day.items {
                if var existing = map[item.id] {
                    existing = AppModel.CategoryMinutes(id: item.id, name: item.name, colorTag: item.colorTag, minutes: existing.minutes + item.minutes)
                    map[item.id] = existing
                } else {
                    map[item.id] = item
                }
            }
        }
        return Array(map.values).sorted { $0.minutes > $1.minutes }
    }

    private func legendGrid(names: [String], allItems: [AppModel.CategoryMinutes]) -> some View {
        let unique = Dictionary(allItems.map { ($0.name, $0.color) }, uniquingKeysWith: { f, _ in f })
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(names, id: \.self) { name in
                HStack(spacing: 6) {
                    Circle().fill(unique[name] ?? .gray).frame(width: 8, height: 8)
                    Text(name).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    private func formatMins(_ mins: Int) -> String {
        if mins >= 60 { let h = mins/60; let m = mins%60; return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(mins)m"
    }
}

// MARK: - Monthly Section

struct MonthlySection: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        let items = appModel.monthlyBreakdown()
        let monthLabel: String = {
            let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: Date())
        }()

        VStack(alignment: .leading, spacing: 16) {
            Text(monthLabel)
                .font(.headline)
                .foregroundStyle(.secondary)

            if items.isEmpty {
                Text("No data yet. Start tracking to see monthly totals.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                // Pie chart
                PieChartView(slices: items.map {
                    let total = Double(items.map(\.minutes).reduce(0, +))
                    return PieSlice(fraction: total > 0 ? Double($0.minutes) / total : 0, color: $0.color)
                })
                .frame(height: 160)

                // Bar chart
                Chart(items) { item in
                    BarMark(
                        x: .value("Minutes", item.minutes),
                        y: .value("Category", item.name)
                    )
                    .foregroundStyle(item.color)
                }
                .frame(height: max(80, CGFloat(items.count) * 40))
                .chartXAxisLabel("Minutes")

                // Summary list
                VStack(spacing: 8) {
                    ForEach(items.sorted { $0.minutes > $1.minutes }) { item in
                        HStack(spacing: 10) {
                            Circle().fill(item.color).frame(width: 10, height: 10)
                            Text(item.name).font(.subheadline)
                            Spacer()
                            Text(formatMins(item.minutes))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .qmCard()

                // Total
                let total = items.map(\.minutes).reduce(0, +)
                MetricTile(value: formatMins(total), label: "total this month")
            }
        }
    }

    private func formatMins(_ mins: Int) -> String {
        if mins >= 60 { let h = mins/60; let m = mins%60; return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(mins)m"
    }
}
