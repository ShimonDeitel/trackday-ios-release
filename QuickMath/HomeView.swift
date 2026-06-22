import SwiftUI

struct HomeView: View {
    var forceScreen: String? = nil

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showSettings = false
    @State private var showPro = false

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        // Today's card
                        GridView()
                            .environmentObject(appModel)
                            .environmentObject(store)

                        // Stats row
                        HStack(spacing: 12) {
                            MetricTile(value: "\(appModel.streak.current)", label: "Streak")
                            MetricTile(value: "\(appModel.streak.best)", label: "Best")
                            MetricTile(
                                value: appModel.today.map { "\($0.winCount)/3" } ?? "–",
                                label: "Today"
                            )
                        }
                        .padding(.horizontal)

                        // Pro history tile
                        Button {
                            Haptics.tap()
                            showPro = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("History & Insights")
                                        .font(.headline)
                                    Text("See every past day's wins")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: store.isPro ? "chevron.right" : "lock.fill")
                                    .foregroundStyle(Color.qmAccent)
                            }
                            .qmCard()
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Threes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.qmAccent)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(store)
                    .environmentObject(appModel)
            }
            .sheet(isPresented: $showPro) {
                if store.isPro {
                    InsightsView()
                        .environmentObject(appModel)
                        .environmentObject(store)
                } else {
                    PaywallView()
                        .environmentObject(store)
                }
            }
        }
        .onAppear {
            if let screen = forceScreen {
                switch screen {
                case "pro": showPro = true
                case "settings": showSettings = true
                default: break
                }
            }
        }
    }
}
