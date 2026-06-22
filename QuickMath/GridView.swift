import SwiftUI

/// The primary entry/action screen: shows today's three priority slots.
struct GridView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @FocusState private var focusedSlot: Int?

    private var slots: [TaskSlot] {
        (appModel.today?.slots ?? []).sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Your three.")
                        .font(.title2.weight(.bold))
                }
                Spacer()
                // Day result badge
                if let today = appModel.today, today.hasAnyTitle {
                    dayBadge(today: today)
                }
            }

            Divider()

            // Three task slots
            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                SlotRow(
                    slot: slot,
                    number: index + 1,
                    isFocused: focusedSlot == index,
                    onTitleChange: { newTitle in
                        appModel.setTitle(newTitle, slot: slot)
                    },
                    onToggle: {
                        appModel.toggleDone(slot)
                    }
                )
                .focused($focusedSlot, equals: index)

                if index < 2 {
                    Divider().padding(.leading, 44)
                }
            }

            // Dismiss keyboard hint
            if focusedSlot != nil {
                HStack {
                    Spacer()
                    Button("Done") {
                        focusedSlot = nil
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.qmAccent)
                }
            }
        }
        .qmCard()
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var dateLabel: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        fmt.timeStyle = .none
        return fmt.string(from: Date())
    }

    @ViewBuilder
    private func dayBadge(today: DailyThree) -> some View {
        let wins = today.winCount
        Group {
            if today.isPerfect {
                Label("Won the day!", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.qmCorrect)
            } else if wins > 0 {
                Text("\(wins) of 3")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("Get started")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.qmCard2, in: Capsule())
    }
}

// MARK: - SlotRow

private struct SlotRow: View {
    let slot: TaskSlot
    let number: Int
    let isFocused: Bool
    let onTitleChange: (String) -> Void
    let onToggle: () -> Void

    @State private var localTitle: String = ""

    var body: some View {
        HStack(spacing: 12) {
            // Number + check button
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(slot.done ? Color.qmAccent : Color.qmHair, lineWidth: 2)
                        .frame(width: 32, height: 32)
                    if slot.done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.qmAccent)
                    } else {
                        Text("\(number)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(slot.title.isEmpty)

            // Title field
            TextField("Priority \(number)", text: $localTitle, axis: .vertical)
                .font(.body)
                .lineLimit(1...3)
                .strikethrough(slot.done, color: .secondary)
                .foregroundStyle(slot.done ? .secondary : .primary)
                .onAppear { localTitle = slot.title }
                .onChange(of: localTitle) { _, newVal in
                    onTitleChange(newVal)
                }
                .onChange(of: slot.title) { _, newVal in
                    if newVal != localTitle { localTitle = newVal }
                }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
