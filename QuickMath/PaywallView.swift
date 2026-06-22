import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private let benefits: [String] = [
        "Weekly and monthly time-allocation trends and category history",
        "Unlimited categories with goals and per-category targets",
        "Idle-and-switch reminders and a daily wrap-up nudge"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 28) {
                        // Icon + title
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.qmAccent.opacity(0.12))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "clock.badge.checkmark")
                                    .font(.system(size: 38))
                                    .foregroundStyle(Color.qmAccent)
                            }
                            Text("Trackday Pro")
                                .font(.title2.bold())
                            Text("\(store.displayPrice) / month. Auto-renews until you cancel.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Benefits
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(benefits, id: \.self) { benefit in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.qmCorrect)
                                        .font(.headline)
                                    Text(benefit)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .qmCard()

                        // Purchase button
                        Button {
                            Haptics.tap()
                            Task { await store.purchase() }
                        } label: {
                            if store.purchaseInFlight {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Unlock for \(store.displayPrice)/mo")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .prominentButton()
                        .disabled(store.purchaseInFlight)

                        // Restore
                        Button {
                            Haptics.tap()
                            Task { await store.restore() }
                        } label: {
                            Text("Restore Purchase")
                        }
                        .softButton()

                        // Disclosure
                        VStack(spacing: 8) {
                            Text("Subscription automatically renews at \(store.displayPrice)/month unless cancelled at least 24 hours before the end of the current period. Cancel anytime in your Apple Account settings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 16) {
                                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/trackday-site/privacy.html")!)
                            }
                            .font(.caption)
                            .foregroundStyle(Color.qmAccent)
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: store.isPro) { _, newValue in
                if newValue { dismiss() }
            }
        }
    }
}
