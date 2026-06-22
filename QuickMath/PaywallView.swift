import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private let benefits: [(icon: String, text: String)] = [
        ("calendar", "Browsable history of every past day's three and win-rate insights"),
        ("arrow.uturn.forward", "Carry-forward unfinished items and rollover suggestions"),
        ("bell.badge", "Morning prompt and evening review reminders")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 28) {

                        // Icon + title
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(Color.qmAccent)

                            Text("Threes Pro")
                                .font(.title.weight(.bold))

                            Text("\(store.displayPrice) / month. Auto-renews until you cancel.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top)

                        // Benefits
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(benefits, id: \.icon) { benefit in
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: benefit.icon)
                                        .foregroundStyle(Color.qmAccent)
                                        .font(.title3)
                                        .frame(width: 28)
                                    Text(benefit.text)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .qmCard()
                        .padding(.horizontal)

                        // CTA
                        VStack(spacing: 12) {
                            Button {
                                Task { await store.purchase() }
                            } label: {
                                if store.purchaseInFlight {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Unlock Threes Pro")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .prominentButton()
                            .padding(.horizontal)
                            .disabled(store.purchaseInFlight)

                            Button("Restore Purchase") {
                                Task { await store.restore() }
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.qmAccent)
                        }

                        // Legal disclosure
                        VStack(spacing: 8) {
                            Text("Threes Pro is \(store.displayPrice)/month. Subscription automatically renews each month unless cancelled at least 24 hours before the renewal date. You can manage or cancel your subscription at any time in your Apple ID settings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 16) {
                                Link("Terms of Use",
                                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                Link("Privacy Policy",
                                     destination: URL(string: "https://shimondeitel.github.io/threes-site/privacy.html")!)
                            }
                            .font(.caption)
                            .foregroundStyle(Color.qmAccent)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
            .navigationTitle("Threes Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.qmAccent)
                }
            }
            .onChange(of: store.isPro) { _, newVal in
                if newVal { dismiss() }
            }
        }
    }
}
