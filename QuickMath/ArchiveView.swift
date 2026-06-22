import SwiftUI

/// Pro feature: browsable history and win-rate insights.
struct InsightsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private var pastDays: [DailyThree] {
        appModel.history.filter { Calendar.current.isDateInToday($0.date) == false }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        // Summary tiles
                        HStack(spacing: 12) {
                            MetricTile(value: "\(appModel.streak.current)", label: "Streak")
                            MetricTile(value: "\(appModel.streak.best)", label: "Best")
                            MetricTile(
                                value: pct(appModel.winRate(days: 7)),
                                label: "7-day rate"
                            )
                        }
                        .padding(.horizontal)

                        // Win rate bar
                        WinRateBar(
                            sevenDay: appModel.winRate(days: 7),
                            thirtyDay: appModel.winRate(days: 30),
                            allTime: appModel.winRate(days: 365)
                        )
                        .padding(.horizontal)

                        // Past days list
                        if pastDays.isEmpty {
                            Text("No history yet — come back tomorrow!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding()
                        } else {
                            VStack(spacing: 10) {
                                ForEach(pastDays, id: \.date) { day in
                                    HistoryCard(day: day)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("History & Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.qmAccent)
                }
            }
        }
    }

    private func pct(_ rate: Double) -> String {
        "\(Int(rate * 100))%"
    }
}

// MARK: - Win Rate Bar

private struct WinRateBar: View {
    let sevenDay: Double
    let thirtyDay: Double
    let allTime: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Win Rate")
                .font(.headline)

            ForEach([("7 days", sevenDay), ("30 days", thirtyDay), ("All time", allTime)],
                    id: \.0) { label, rate in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(rate * 100))%")
                            .font(.caption.weight(.semibold))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.qmCard2)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.qmAccent)
                                .frame(width: geo.size.width * rate, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .qmCard()
    }
}

// MARK: - History Card

private struct HistoryCard: View {
    let day: DailyThree

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dateString)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if day.isPerfect {
                    Label("Won", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.qmCorrect)
                } else {
                    Text("\(day.winCount)/3")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            let sorted = day.slots.sorted { $0.order < $1.order }
            ForEach(sorted, id: \.id) { slot in
                if !slot.title.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: slot.done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(slot.done ? Color.qmAccent : Color.qmHair)
                            .font(.subheadline)
                        Text(slot.title)
                            .font(.subheadline)
                            .foregroundStyle(slot.done ? .secondary : .primary)
                            .strikethrough(slot.done, color: .secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .qmCard()
    }

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: day.date)
    }
}
