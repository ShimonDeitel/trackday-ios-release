import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("quickmath.theme") private var themeRaw = AppTheme.system.rawValue

    @State private var showPaywall = false
    @State private var showDeleteConfirm = false

    private var theme: AppTheme {
        get { AppTheme(rawValue: themeRaw) ?? .system }
        nonmutating set { themeRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                List {
                    // Pro section
                    Section("Threes Pro") {
                        if store.isPro {
                            Label("Pro Active", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(Color.qmAccent)
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                Link(destination: url) {
                                    Label("Manage Subscription", systemImage: "arrow.up.right")
                                }
                                .foregroundStyle(Color.qmAccent)
                            }
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                Label("Unlock Threes Pro", systemImage: "lock.open.fill")
                                    .foregroundStyle(Color.qmAccent)
                            }
                            Button {
                                Task { await store.restore() }
                            } label: {
                                Label("Restore Purchase", systemImage: "arrow.clockwise")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Appearance
                    Section("Appearance") {
                        Picker("Theme", selection: $themeRaw) {
                            ForEach(AppTheme.allCases) { t in
                                Text(t.label).tag(t.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    }

                    // Legal
                    Section("About") {
                        if let url = URL(string: "https://shimondeitel.github.io/threes-site/privacy.html") {
                            Link(destination: url) {
                                Label("Privacy Policy", systemImage: "hand.raised")
                            }
                            .foregroundStyle(Color.qmAccent)
                        }
                        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                            Link(destination: url) {
                                Label("Terms of Use", systemImage: "doc.text")
                            }
                            .foregroundStyle(Color.qmAccent)
                        }
                    }

                    // Danger zone
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete All Data", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.qmAccent)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(store)
            }
            .confirmationDialog(
                "Delete all data?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    appModel.deleteAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently erase your task history and streaks.")
            }
        }
    }
}
