import SwiftUI

// Primary tracking action screen — tap a category to switch to it.
struct GridView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showAddSheet = false
    @State private var showProLimit = false
    @State private var newCatName = ""
    @State private var selectedColor = "#007AFF"
    @State private var activeID: UUID? = nil

    private let colorOptions = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30",
        "#5856D6", "#FF2D55", "#AC8E68", "#636366"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Categories")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Haptics.tap()
                    if appModel.canAddCategory {
                        showAddSheet = true
                    } else {
                        showProLimit = true
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.qmAccent)
                        .font(.title3)
                }
            }

            if appModel.categories.isEmpty {
                Text("Add a category to start tracking.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(appModel.categories) { cat in
                        CategoryTile(
                            category: cat,
                            isActive: appModel.activeEntry?.categoryID == cat.id
                        )
                        .onTapGesture {
                            Haptics.tap()
                            appModel.startTracking(category: cat)
                            withAnimation(.spring(duration: 0.3)) {
                                activeID = cat.id
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                appModel.deleteCategory(cat)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            // Stop tracking button
            if appModel.activeEntry != nil {
                Button {
                    Haptics.warning()
                    appModel.stopTracking()
                } label: {
                    Text("Stop Tracking")
                        .frame(maxWidth: .infinity)
                }
                .softButton()
                .padding(.top, 4)
            }
        }
        .qmCard()
        .sheet(isPresented: $showAddSheet) {
            AddCategorySheet(isPresented: $showAddSheet)
                .environmentObject(appModel)
        }
        .alert("Upgrade to Pro", isPresented: $showProLimit) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Free tier supports up to 5 categories. Upgrade to Pro for unlimited.")
        }
    }
}

// MARK: - Category Tile

struct CategoryTile: View {
    let category: TrackedCategory
    let isActive: Bool

    @State private var elapsed: TimeInterval = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(category.displayColor)
                    .frame(width: 12, height: 12)
                Spacer()
                if isActive {
                    Image(systemName: "record.circle")
                        .foregroundStyle(Color.qmWrong)
                        .font(.caption)
                }
            }
            Text(category.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            if isActive {
                Text(elapsedString())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.qmAccent)
            } else {
                Text("Tap to track")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isActive ? category.displayColor.opacity(0.12) : Color.qmCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isActive ? category.displayColor : Color.clear, lineWidth: 2)
                )
        )
        .onReceive(ticker) { _ in
            if isActive {
                elapsed += 1
            }
        }
        .onAppear {
            elapsed = 0
        }
    }

    private func elapsedString() -> String {
        let e = Int(elapsed)
        let h = e / 3600, m = (e % 3600) / 60, s = e % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var appModel: AppModel

    @State private var name = ""
    @State private var selectedColor = "#007AFF"

    private let colorOptions = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30",
        "#5856D6", "#FF2D55", "#AC8E68", "#636366"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Deep Work", text: $name)
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            ZStack {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                if selectedColor == hex {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.white)
                                        .font(.caption.bold())
                                }
                            }
                            .onTapGesture {
                                Haptics.tap()
                                selectedColor = hex
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        appModel.addCategory(name: trimmed, colorTag: selectedColor)
                        Haptics.success()
                        isPresented = false
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
