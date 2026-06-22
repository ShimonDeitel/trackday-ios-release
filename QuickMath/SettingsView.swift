import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("quickmath.theme") private var themeRaw = AppTheme.system.rawValue
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false

    private var theme: Binding<String> {
        Binding(
            get: { themeRaw },
            set: { themeRaw = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Pro status
                Section("Subscription") {
                    if store.isPro {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.qmCorrect)
                            Text("Trackday Pro Active")
                                .font(.headline)
                        }
                        Link("Manage Subscription",
                             destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                            .foregroundStyle(Color.qmAccent)
                    } else {
                        Button {
                            Haptics.tap()
                            showPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "lock.open.fill")
                                    .foregroundStyle(Color.qmAccent)
                                Text("Upgrade to Pro")
                            }
                        }
                        Button {
                            Haptics.tap()
                            Task { await store.restore() }
                        } label: {
                            Text("Restore Purchase")
                                .foregroundStyle(Color.qmAccent)
                        }
                    }
                }

                // MARK: - Appearance
                Section("Appearance") {
                    Picker("Theme", selection: theme) {
                        ForEach(AppTheme.allCases) { t in
                            Text(t.label).tag(t.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // MARK: - Legal
                Section("Legal") {
                    Link("Privacy Policy",
                         destination: URL(string: "https://shimondeitel.github.io/trackday-site/privacy.html")!)
                        .foregroundStyle(Color.qmAccent)
                    Link("Terms of Use",
                         destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        .foregroundStyle(Color.qmAccent)
                }

                // MARK: - Danger zone
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(store)
            }
            .confirmationDialog("Delete all tracking data?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    appModel.deleteAllData()
                    Haptics.warning()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all entries and categories.")
            }
        }
    }
}
