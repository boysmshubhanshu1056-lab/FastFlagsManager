
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Preset Model

struct FlagPreset: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var json: String
    var date: Date = Date()
}

// MARK: - Main App View

struct ContentView: View {

    enum Page: String, CaseIterable, Identifiable {
        case engine = "Engine"
        case flags = "Fast Flags"
        case presets = "Presets"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .engine: return "cpu"
            case .flags: return "slider.horizontal.3"
            case .presets: return "bookmark"
            case .settings: return "gearshape"
            }
        }
    }

    @State private var selection: Page? = .engine
    @State private var flagJSON = "{}"
    @State private var presets: [FlagPreset] = []

    @State private var showingImporter = false
    @State private var showingSaveSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var presetToDelete: FlagPreset?
    @State private var presetName = ""

    @State private var statusMessage = ""
    @State private var showingStatus = false

    private let storageKey = "FastFlagsManager.presets.v1"

    private var isValidJSON: Bool {
        guard let data = flagJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
              ) else {
            return false
        }

        return object is [String: Any]
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("WORKSPACE") {
                    ForEach(Page.allCases) { page in
                        Label(page.rawValue, systemImage: page.icon)
                            .tag(Optional(page))
                    }
                }
            }
            .navigationTitle("FastFlags")
            .navigationSplitViewColumnWidth(
                min: 190,
                ideal: 225,
                max: 290
            )
        } detail: {
            Group {
                switch selection ?? .engine {
                case .engine:
                    enginePage
                case .flags:
                    flagsPage
                case .presets:
                    presetsPage
                case .settings:
                    settingsPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .onAppear {
            loadPresetsFromDisk()
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importJSON(result)
        }
        .sheet(isPresented: $showingSaveSheet) {
            savePresetSheet
        }
        .confirmationDialog(
            "Delete this preset?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Preset", role: .destructive) {
                if let preset = presetToDelete {
                    deletePreset(preset)
                }
            }

            Button("Cancel", role: .cancel) {
                presetToDelete = nil
            }
        } message: {
            Text("This removes the saved preset from this device.")
        }
        .alert("FastFlagsManager", isPresented: $showingStatus) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(statusMessage)
        }
    }

    // MARK: - Engine

    private var enginePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                pageHeader(
                    "Engine",
                    subtitle: "Your FastFlags workspace at a glance."
                )

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 14
                ) {
                    statCard(
                        title: "JSON Status",
                        value: isValidJSON ? "Valid" : "Invalid",
                        icon: isValidJSON ? "checkmark.circle" : "exclamationmark.circle"
                    )

                    statCard(
                        title: "Saved Presets",
                        value: "\(presets.count) / 10",
                        icon: "bookmark"
                    )
                }

                GroupBox("Current Configuration") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your editor contains the current JSON configuration.")
                            .foregroundStyle(.secondary)

                        HStack {
                            Label(
                                isValidJSON ? "JSON is valid" : "Check your JSON",
                                systemImage: isValidJSON
                                    ? "checkmark.circle.fill"
                                    : "exclamationmark.circle.fill"
                            )

                            Spacer()

                            Button("Open Editor") {
                                selection = .flags
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Quick Actions") {
                    VStack(spacing: 12) {
                        actionRow(
                            "Import JSON",
                            description: "Open a .json file",
                            icon: "doc.badge.plus"
                        ) {
                            showingImporter = true
                        }

                        Divider()

                        actionRow(
                            "Save Preset",
                            description: "Store this configuration",
                            icon: "bookmark"
                        ) {
                            beginSavingPreset()
                        }

                        Divider()

                        actionRow(
                            "View Presets",
                            description: "Load or delete saved configurations",
                            icon: "square.stack"
                        ) {
                            selection = .presets
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 850, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Engine")
    }

    // MARK: - Fast Flags Editor

    private var flagsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            pageHeader(
                "Fast Flags",
                subtitle: "Import, paste, or edit your JSON configuration."
            )

            HStack(spacing: 10) {
                Button {
                    showingImporter = true
                } label: {
                    Label("Import JSON", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.bordered)

                Button {
                    beginSavingPreset()
                } label: {
                    Label("Save Preset", systemImage: "bookmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidJSON || presets.count >= 10)

                Spacer()

                Text(isValidJSON ? "Valid JSON" : "Invalid JSON")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isValidJSON ? .green : .red)
            }

            TextEditor(text: $flagJSON)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.secondary.opacity(0.2))
                }

            HStack {
                Text("JSON object required")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear Editor", role: .destructive) {
                    flagJSON = "{}"
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .navigationTitle("Fast Flags")
    }

    // MARK: - Presets

    private var presetsPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageHeader(
                "Presets",
                subtitle: "Save up to 10 complete JSON configurations."
            )

            HStack {
                Text("\(presets.count) of 10 slots used")
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    beginSavingPreset()
                } label: {
                    Label("Save Current", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidJSON || presets.count >= 10)
            }

            if presets.isEmpty {
                ContentUnavailableView {
                    Label("No Presets Yet", systemImage: "bookmark")
                } description: {
                    Text("Import or paste your FastFlags JSON, then save it here.")
                } actions: {
                    Button("Open Fast Flags Editor") {
                        selection = .flags
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            } else {
                List {
                    ForEach(presets) { preset in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                Image(systemName: "doc.text")
                                    .font(.title2)
                                    .foregroundStyle(.tint)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.name)
                                        .font(.headline)

                                    Text("\(flagCount(in: preset.json)) top-level flags")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(preset.date, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Menu {
                                    Button {
                                        loadPreset(preset)
                                    } label: {
                                        Label("Load", systemImage: "arrow.down.doc")
                                    }

                                    Button(role: .destructive) {
                                        presetToDelete = preset
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title2)
                                }
                            }

                            HStack {
                                Button {
                                    loadPreset(preset)
                                } label: {
                                    Label("Load", systemImage: "arrow.down.doc")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)

                                Button(role: .destructive) {
                                    presetToDelete = preset
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(24)
        .navigationTitle("Presets")
    }

    // MARK: - Settings

    private var settingsPage: some View {
        Form {
            Section("Storage") {
                LabeledContent("Preset capacity", value: "10")
                LabeledContent("Presets saved", value: "\(presets.count)")
                LabeledContent("Storage", value: "On this device")
            }

            Section("JSON") {
                LabeledContent(
                    "Current editor",
                    value: isValidJSON ? "Valid" : "Invalid"
                )

                Button("Import JSON File") {
                    showingImporter = true
                }

                Button("Open Fast Flags Editor") {
                    selection = .flags
                }
            }

            Section("About") {
                LabeledContent("App", value: "FastFlagsManager")

                Text("This app manages local JSON configurations. Saving a preset does not automatically apply flags to Roblox.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    // MARK: - Save Preset Sheet

    private var savePresetSheet: some View {
        NavigationStack {
            Form {
                Section("Preset Name") {
                    TextField("e.g. My Configuration", text: $presetName)
                        .textInputAutocapitalization(.words)
                }

                Section("Configuration") {
                    LabeledContent(
                        "Top-level flags",
                        value: "\(flagCount(in: flagJSON))"
                    )

                    LabeledContent(
                        "JSON size",
                        value: ByteCountFormatter.string(
                            fromByteCount: Int64(flagJSON.utf8.count),
                            countStyle: .file
                        )
                    )
                }

                if presets.count >= 10 {
                    Text("All 10 preset slots are full. Delete a preset before saving another.")
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Save Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingSaveSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePreset()
                    }
                    .disabled(
                        presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !isValidJSON
                        || presets.count >= 10
                    )
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Reusable UI

    private func pageHeader(
        _ title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.bold())

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statCard(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.tint)

                Text(value)
                    .font(.title2.bold())

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func actionRow(
        _ title: String,
        description: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - JSON Import

    private func importJSON(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let imported = try String(
                    contentsOf: url,
                    encoding: .utf8
                )

                guard isJSONObject(imported) else {
                    showStatus("The selected file is not a valid JSON object.")
                    return
                }

                flagJSON = imported
                showStatus("JSON imported successfully.")
            } catch {
                showStatus("Could not read the file: \(error.localizedDescription)")
            }

        case .failure(let error):
            showStatus("Import failed: \(error.localizedDescription)")
        }
    }

    private func isJSONObject(_ json: String) -> Bool {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
              ) else {
            return false
        }

        return object is [String: Any]
    }

    private func flagCount(in json: String) -> Int {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(
                with: data
              ),
              let dictionary = object as? [String: Any] else {
            return 0
        }

        return dictionary.count
    }

    // MARK: - Preset Operations

    private func beginSavingPreset() {
        guard isValidJSON else {
            showStatus("Fix your JSON before saving a preset.")
            return
        }

        guard presets.count < 10 else {
            showStatus("You have 10 presets. Delete one before saving another.")
            return
        }

        presetName = ""
        showingSaveSheet = true
    }

    private func savePreset() {
        let name = presetName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !name.isEmpty, isValidJSON else { return }

        guard presets.count < 10 else {
            showingSaveSheet = false
            showStatus("Preset limit reached.")
            return
        }

        let preset = FlagPreset(
            name: name,
            json: flagJSON
        )

        presets.append(preset)
        persistPresets()
        showingSaveSheet = false
        showStatus("Preset '\(name)' saved successfully.")
    }

    private func loadPreset(_ preset: FlagPreset) {
        guard isJSONObject(preset.json) else {
            showStatus("This preset contains invalid JSON.")
            return
        }

        flagJSON = preset.json
        selection = .flags
        showStatus("Loaded '\(preset.name)'. Your editor now contains its saved configuration.")
    }

    private func deletePreset(_ preset: FlagPreset) {
        presets.removeAll { $0.id == preset.id }
        persistPresets()
        presetToDelete = nil
        showStatus("Preset '\(preset.name)' deleted.")
    }

    // MARK: - Persistent Storage

    private func loadPresetsFromDisk() {
        guard let data = UserDefaults.standard.data(
            forKey: storageKey
        ) else {
            return
        }

        do {
            let saved = try JSONDecoder().decode(
                [FlagPreset].self,
                from: data
            )

            presets = Array(saved.prefix(10))
        } catch {
            showStatus("Saved presets could not be read.")
        }
    }

    private func persistPresets() {
        do {
            let data = try JSONEncoder().encode(presets)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            showStatus("Could not save presets.")
        }
    }

    // MARK: - Alerts

    private func showStatus(_ message: String) {
        statusMessage = message
        showingStatus = true
    }
}

#Preview {
    ContentView()
}
