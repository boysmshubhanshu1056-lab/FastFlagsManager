
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Preset Model

struct FlagPreset: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var json: String
    var createdAt: Date = Date()
}

// MARK: - Main View

struct ContentView: View {

    private enum Page: String, CaseIterable, Identifiable {
        case engine = "Engine"
        case flags = "Fast Flags"
        case presets = "Presets"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .engine: return "speedometer"
            case .flags: return "slider.horizontal.3"
            case .presets: return "square.stack.3d.up"
            case .settings: return "gearshape"
            }
        }
    }

    private static let flagsKey = "FastFlagsManager.flags.v1"
    private static let presetsKey = "FastFlagsManager.presets.v1"
    private static let maxPresets = 10

    @State private var selection: Page = .engine

    @State private var flagJSON: String =
        UserDefaults.standard.string(
            forKey: "FastFlagsManager.flags.v1"
        ) ?? "{}"

    @State private var presets: [FlagPreset] = Self.loadPresets()

    @State private var presetName = ""
    @State private var showSavePreset = false
    @State private var showFileImporter = false
    @State private var showDeleteConfirmation = false
    @State private var presetToDelete: FlagPreset?
    @State private var statusMessage = ""
    @State private var showStatus = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            Group {
                switch selection {
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
            .background(Color(uiColor: .systemBackground))
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.cyan)
        .onChange(of: flagJSON) { newValue in
            UserDefaults.standard.set(newValue, forKey: Self.flagsKey)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importJSON(result)
        }
        .alert("Save Preset", isPresented: $showSavePreset) {
            TextField("Preset name", text: $presetName)

            Button("Cancel", role: .cancel) {
                presetName = ""
            }

            Button("Save") {
                savePreset()
            }
        } message: {
            Text("Save your current JSON for later.")
        }
        .confirmationDialog(
            "Delete this preset?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let preset = presetToDelete {
                    deletePreset(preset)
                }
            }

            Button("Cancel", role: .cancel) {}
        }
        .alert("FastFlags Manager", isPresented: $showStatus) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List {
            Section {
                ForEach(Page.allCases) { page in
                    Button {
                        selection = page
                    } label: {
                        Label(page.rawValue, systemImage: page.icon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        selection == page
                        ? Color.cyan.opacity(0.18)
                        : Color.clear
                    )
                }
            } header: {
                Text("FASTFLAGS")
                    .font(.caption.weight(.bold))
            }

            Section {
                Label("Local JSON Storage", systemImage: "internaldrive")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(presets.count)/\(Self.maxPresets) presets saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("FFlags")
    }

    // MARK: - Engine Page

    private var enginePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                pageHeader(
                    "Engine",
                    subtitle: "Your FastFlags Manager dashboard."
                )

                HStack(spacing: 12) {
                    statCard(
                        title: "Presets",
                        value: "\(presets.count)/\(Self.maxPresets)",
                        icon: "square.stack.3d.up"
                    )

                    statCard(
                        title: "JSON",
                        value: isValidJSON ? "Valid" : "Invalid",
                        icon: "curlybraces"
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Roblox", systemImage: "gamecontroller.fill")
                        .font(.headline)

                    Text(
                        "Open Roblox from here. This app manages your JSON locally; " +
                        "it cannot directly inject custom FastFlags into the official Roblox iOS app."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Button(action: launchRoblox) {
                        Label("Launch Roblox", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 12) {
                    Label("Quick Actions", systemImage: "bolt.fill")
                        .font(.headline)

                    Button {
                        selection = .flags
                    } label: {
                        Label("Edit Fast Flags", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        selection = .presets
                    } label: {
                        Label("Manage Presets", systemImage: "square.stack.3d.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Import JSON File", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
    }

    // MARK: - Fast Flags Page

    private var flagsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            pageHeader(
                "Fast Flags",
                subtitle: "Edit or import your JSON configuration."
            )

            HStack {
                Label(
                    isValidJSON ? "Valid JSON" : "Invalid JSON",
                    systemImage: isValidJSON ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .foregroundStyle(isValidJSON ? .green : .red)

                Spacer()

                Button {
                    showFileImporter = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
            }

            TextEditor(text: $flagJSON)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                }

            HStack {
                Button {
                    formatJSON()
                } label: {
                    Label("Format JSON", systemImage: "text.alignleft")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    presetName = ""
                    showSavePreset = true
                } label: {
                    Label("Save as Preset", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidJSON || presets.count >= Self.maxPresets)
            }

            Text("Changes are saved locally on this device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Presets Page

    private var presetsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            pageHeader(
                "Presets",
                subtitle: "Save and reuse your JSON configurations."
            )

            HStack {
                Text("\(presets.count) of \(Self.maxPresets) slots used")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    presetName = ""
                    showSavePreset = true
                } label: {
                    Label("New Preset", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidJSON || presets.count >= Self.maxPresets)
            }

            if presets.isEmpty {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)

                    Text("No Presets Yet")
                        .font(.title3.weight(.semibold))

                    Text("Edit your JSON and save it as a preset.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Spacer()
            } else {
                List {
                    ForEach(presets) { preset in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.name)
                                        .font(.headline)

                                    Text(preset.createdAt.formatted(
                                        date: .abbreviated,
                                        time: .shortened
                                    ))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    presetToDelete = preset
                                    showDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }

                            HStack {
                                Button {
                                    flagJSON = preset.json
                                    selection = .flags
                                    report("Loaded preset: \(preset.name)")
                                } label: {
                                    Label("Load", systemImage: "arrow.down.doc")
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    GenUICopyJSON(preset.json)
                                    report("Preset JSON copied.")
                                } label: {
                                    Label("Copy JSON", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .padding()
    }

    // MARK: - Settings Page

    private var settingsPage: some View {
        Form {
            Section("Storage") {
                LabeledContent("Preset limit", value: "\(Self.maxPresets)")
                LabeledContent("Saved presets", value: "\(presets.count)")
                LabeledContent("Configuration", value: "On this device")
            }

            Section("Actions") {
                Button {
                    showFileImporter = true
                } label: {
                    Label("Import JSON", systemImage: "square.and.arrow.down")
                }

                Button {
                    flagJSON = "{}"
                    report("JSON editor reset.")
                } label: {
                    Label("Reset JSON Editor", systemImage: "arrow.counterclockwise")
                }

                Button(role: .destructive) {
                    presets = []
                    persistPresets()
                    report("All presets deleted.")
                } label: {
                    Label("Delete All Presets", systemImage: "trash")
                }
            }

            Section("Important") {
                Text(
                    "This app stores and edits JSON files. The official Roblox iOS app " +
                    "does not provide a supported method for this app to apply arbitrary custom FastFlags to the running game."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("App", value: "FastFlags Manager")
                LabeledContent("Platform", value: "iOS 16+")
            }
        }
        .navigationTitle("Settings")
    }

    // MARK: - Reusable UI

    private func pageHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.weight(.bold))

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
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.cyan)

            Text(value)
                .font(.title2.weight(.bold))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - JSON

    private var isValidJSON: Bool {
        guard let data = flagJSON.data(using: .utf8) else {
            return false
        }

        do {
            let object = try JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
            )
            return object is [String: Any]
        } catch {
            return false
        }
    }

    private func formatJSON() {
        guard let data = flagJSON.data(using: .utf8) else {
            report("Could not read the JSON text.")
            return
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data)

            guard object is [String: Any] else {
                report("FastFlags JSON must be a JSON object.")
                return
            }

            let formatted = try JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
            )

            flagJSON = String(decoding: formatted, as: UTF8.self)
            report("JSON formatted successfully.")
        } catch {
            report("Invalid JSON: \(error.localizedDescription)")
        }
    }

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
                let data = try Data(contentsOf: url)
                let object = try JSONSerialization.jsonObject(with: data)

                guard object is [String: Any] else {
                    report("The imported file must contain a JSON object.")
                    return
                }

                let formatted = try JSONSerialization.data(
                    withJSONObject: object,
                    options: [.prettyPrinted, .sortedKeys]
                )

                flagJSON = String(decoding: formatted, as: UTF8.self)
                selection = .flags
                report("JSON imported successfully.")
            } catch {
                report("Import failed: \(error.localizedDescription)")
            }

        case .failure(let error):
            report("Import failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Preset Management

    private static func loadPresets() -> [FlagPreset] {
        guard
            let data = UserDefaults.standard.data(forKey: presetsKey),
            let saved = try? JSONDecoder().decode([FlagPreset].self, from: data)
        else {
            return []
        }

        return Array(saved.prefix(maxPresets))
    }

    private func savePreset() {
        let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            report("Enter a preset name.")
            return
        }

        guard isValidJSON else {
            report("Fix your JSON before saving.")
            return
        }

        guard presets.count < Self.maxPresets else {
            report("You can save up to \(Self.maxPresets) presets.")
            return
        }

        let preset = FlagPreset(name: name, json: flagJSON)
        presets.append(preset)
        persistPresets()
        presetName = ""
        report("Preset saved successfully.")
    }

    private func deletePreset(_ preset: FlagPreset) {
        presets.removeAll { $0.id == preset.id }
        persistPresets()
        presetToDelete = nil
        report("Preset deleted.")
    }

    private func persistPresets() {
        do {
            let data = try JSONEncoder().encode(presets)
            UserDefaults.standard.set(data, forKey: Self.presetsKey)
        } catch {
            report("Could not save presets: \(error.localizedDescription)")
        }
    }

    // MARK: - Launch Roblox

    private func launchRoblox() {
        guard let url = URL(string: "roblox://") else {
            report("Could not create the Roblox launch link.")
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                report("Roblox could not be opened. Check that Roblox is installed.")
            }
        }
    }

    // MARK: - Status

    private func report(_ message: String) {
        statusMessage = message
        showStatus = true
    }
}

// MARK: - Copy Helper

private func GenUICopyJSON(_ text: String) {
    UIPasteboard.general.string = text
}

#Preview {
    ContentView()
}
