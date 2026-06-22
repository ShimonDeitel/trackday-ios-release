import SwiftUI

struct HomeView: View {
    var forceScreen: String? = nil

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showSettings = false
    @State private var showInsights = false
    @State private var showPaywall = false
    @State private var showAddCategory = false
    @State private var now = Date()

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        // Live clock header
                        todayHeader

                        // Today's pie / breakdown
                        if !appModel.todayBreakdown().isEmpty {
                            TodayPieSection()
                        }

                        // Category tap grid
                        GridView()

                        // Pro insights tile
                        proTile

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Trackday")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptics.tap()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.qmAccent)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if store.isPro {
                        Button {
                            Haptics.tap()
                            showInsights = true
                        } label: {
                            Image(systemName: "chart.bar.xaxis")
                                .foregroundStyle(Color.qmAccent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(appModel)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showInsights) {
                InsightsView()
                    .environmentObject(appModel)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(store)
            }
            .onReceive(timer) { _ in
                now = Date()
                appModel.refresh()
            }
            .onAppear {
                handleForceScreen()
            }
        }
    }

    // MARK: - Sub-views

    private var todayHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayString())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(timeString())
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Spacer()
            MetricTile(value: "\(appModel.totalTrackedMinutesToday())m", label: "tracked today")
                .frame(width: 110)
        }
        .padding(.top, 4)
    }

    private var proTile: some View {
        Button {
            Haptics.tap()
            if store.isPro { showInsights = true } else { showPaywall = true }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(Color.qmAccent)
                        Text(store.isPro ? "Insights" : "Trackday Pro")
                            .font(.headline)
                    }
                    Text(store.isPro ? "Weekly & monthly trends" : "Unlock trends, goals & reminders")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.subheadline)
            }
            .qmCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func dayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: now)
    }

    private func timeString() -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: now)
    }

    private func handleForceScreen() {
        guard let screen = forceScreen else { return }
        switch screen {
        case "insights": showInsights = true
        case "paywall": showPaywall = true
        case "settings": showSettings = true
        default: break
        }
    }
}

// MARK: - TodayPieSection

struct TodayPieSection: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        let breakdown = appModel.todayBreakdown()
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(.secondary)
            PieChartView(slices: breakdown.map { PieSlice(fraction: $0.fraction, color: $0.color) })
                .frame(height: 140)
            VStack(spacing: 6) {
                ForEach(breakdown) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 10, height: 10)
                        Text(item.name)
                            .font(.subheadline)
                        Spacer()
                        Text(formatMins(item.minutes))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .qmCard()
    }

    private func formatMins(_ mins: Int) -> String {
        if mins >= 60 {
            let h = mins / 60; let m = mins % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(mins)m"
    }
}

// MARK: - Simple Pie Chart

struct PieSlice {
    let fraction: Double
    let color: Color
}

struct PieChartView: View {
    let slices: [PieSlice]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(Array(slices.enumerated()), id: \.offset) { idx, slice in
                    PieWedge(startAngle: startAngle(for: idx), endAngle: endAngle(for: idx))
                        .fill(slice.color)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity)
        }
    }

    private func cumulative(upTo index: Int) -> Double {
        slices.prefix(index).map(\.fraction).reduce(0, +)
    }

    private func startAngle(for index: Int) -> Angle {
        .degrees(cumulative(upTo: index) * 360 - 90)
    }

    private func endAngle(for index: Int) -> Angle {
        .degrees(cumulative(upTo: index + 1) * 360 - 90)
    }
}

struct PieWedge: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var p = Path()
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.closeSubpath()
        return p
    }
}
