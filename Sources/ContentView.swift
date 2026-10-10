
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Models

struct FlagItem: Identifiable, Codable, Hashable {
    var id: String { name }
    var name: String
    var value: String
}

struct FlagDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var text: String

    init(text: String = "{}") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

// MARK: - Main View

struct ContentView: View {
    @State private var selectedTab = "Home"
    @State private var flags: [FlagItem] = []
    @State private var searchText = ""
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var showingAddFlag = false
    @State private var exportDocument = FlagDocument()
    @State private var status = "Configuration saved locally"
    @State private var launchMessage = ""

    private let accent = Color(red: 0.20, green: 0.57, blue: 1.0)
    private let tabs = [
        ("Home", "house.fill"),
        ("Engine", "cpu"),
        ("FastFlags", "slider.horizontal.3"),
        ("Presets", "square.stack.3d.up.fill"),
        ("Settings", "gearshape.fill")
    ]

    private let presets: [(String, String, [FlagItem])] = [
        ("Default", "Start with no custom overrides", []),
        ("Performance", "Example rendering configuration", [
            .init(name: "DFIntTaskSchedulerTargetFps", value: "60")
        ]),
        ("High FPS", "Example frame limit setting", [
            .init(name: "DFIntTaskSchedulerTargetFps", value: "120")
        ]),
        ("Low FPS", "Example frame limit setting", [
            .init(name: "DFIntTaskSchedulerTargetFps", value: "30")
        ]),
        ("Balanced", "Example balanced configuration", [
            .init(name: "DFIntTaskSchedulerTargetFps", value: "60")
        ]),
        ("Visuals", "Empty visual configuration template", []),
        ("Minimal", "No custom flag overrides", []),
        ("Testing", "Empty testing template", []),
        ("Custom A", "Your own configuration", []),
        ("Custom B", "Your own configuration", [])
    ]

    private var filteredFlags: [FlagItem] {
        if searchText.isEmpty { return flags }
        return flags.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case "Home":
                            homePage
                        case "Engine":
                            enginePage
                        case "FastFlags":
                            flagsPage
                        case "Presets":
                            presetsPage
                        default:
                            settingsPage
                        }
                    }
                    .padding(18)
                }

                bottomNavigation
            }
            .background(Color(red: 0.055, green: 0.065, blue: 0.09))
            .foregroundStyle(.white)
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json]
            ) { result in
                importFlags(result)
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "AppleBlox-FastFlags"
            ) { result in
                switch result {
                case .success:
                    status = "JSON exported"
                case .failure(let error):
                    status = "Export failed: \(error.localizedDescription)"
                }
            }
            .sheet(isPresented: $showingAddFlag) {
                addFlagSheet
            }
            .onAppear(perform: loadSavedFlags)
        }
        .tint(accent)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "apple.logo")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("AppleBlox")
                    .font(.title2.bold())
                Text("ROBLOX CONFIGURATION")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)

            Text("READY")
                .font(.caption.bold())
                .foregroundStyle(.green)
        }
        .padding(18)
        .background(Color.white.opacity(0.035))
    }

    // MARK: - Home

    private var homePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            titleBlock("Welcome back", subtitle: "Your Roblox configuration center.")

            card {
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("APPLEBLOX")
                            .font(.caption.bold())
                            .tracking(2)
                            .foregroundStyle(accent)

                        Text("Your settings.\nYour setup.")
                            .font(.system(size: 30, weight: .bold))

                        Text("\(flags.count) saved flag entries")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 45))
                        .foregroundStyle(accent)
                }

                Button {
                    launchRoblox()
                } label: {
                    Label("Launch Roblox", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)

                Text("Launching Roblox does not apply custom flags.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            card {
                Label("Configuration status", systemImage: "info.circle")
                    .font(.headline)

                Text(status)
                    .foregroundStyle(.secondary)

                Text("Flags are stored in AppleBlox. Roblox may ignore unsupported flags.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            quickButton("Manage FastFlags", icon: "slider.horizontal.3") {
                selectedTab = "FastFlags"
            }

            quickButton("Browse presets", icon: "square.stack.3d.up") {
                selectedTab = "Presets"
            }
        }
    }

    // MARK: - Engine

    private var enginePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            titleBlock("Engine", subtitle: "Manage your local configuration.")

            card {
                Label("FastFlag configuration", systemImage: "cpu")
                    .font(.headline)

                Text("AppleBlox can prepare JSON overrides, but the official iPad Roblox client does not expose a supported interface for loading arbitrary custom flags from another app.")
                    .foregroundStyle(.secondary)

                Button("Open FastFlags editor") {
                    selectedTab = "FastFlags"
                }
                .buttonStyle(.borderedProminent)
            }

            card {
                Label("Configuration tools", systemImage: "wrench.and.screwdriver")
                    .font(.headline)

                Button {
                    showingImporter = true
                } label: {
                    Label("Import JSON", systemImage: "square.and.arrow.down")
                }

                Button {
                    prepareExport()
                } label: {
                    Label("Export JSON", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    flags = []
                    saveFlags()
                    status = "Custom overrides cleared"
                } label: {
                    Label("Clear all custom flags", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - FastFlags

    private var flagsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleBlock("FastFlags", subtitle: "Edit and export string-valued JSON entries.")

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search flags", text: $searchText)
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Text("\(flags.count) entries")
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showingAddFlag = true
                } label: {
                    Label("Add", systemImage: "plus")
                }

                Button {
                    showingImporter = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .accessibilityLabel("Import JSON")
            }

            if filteredFlags.isEmpty {
                card {
                    Image(systemName: "slider.horizontal.3")
                        .font(.largeTitle)
                        .foregroundStyle(accent)

                    Text("No flags found")
                        .font(.headline)

                    Text("Add a flag or import a JSON file.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(filteredFlags) { flag in
                card {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(flag.name)
                                .font(.subheadline.bold())
                                .textSelection(.enabled)

                            Text(flag.value)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(accent)
                        }

                        Spacer()

                        Button {
                            flags.removeAll { $0.name == flag.name }
                            saveFlags()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete \(flag.name)")
                    }
                }
            }

            Button {
                prepareExport()
            } label: {
                Label("Export configuration JSON", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Presets

    private var presetsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleBlock("Presets", subtitle: "Choose a starting configuration.")

            Text("Example templates only. These settings are not verified as supported or effective by Roblox on iPad.")
                .font(.caption)
                .foregroundStyle(.orange)

            ForEach(presets, id: \.0) { preset in
                card {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(preset.0)
                                .font(.headline)

                            Text(preset.1)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Load") {
                            flags = preset.2
                            saveFlags()
                            status = "\(preset.0) template loaded locally"
                            selectedTab = "FastFlags"
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    // MARK: - Settings

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleBlock("Settings", subtitle: "AppleBlox preferences.")

            card {
                Label("Application", systemImage: "info.circle")
                    .font(.headline)

                settingRow("App name", value: "AppleBlox")
                settingRow("Platform", value: "iPadOS")
                settingRow("Configuration", value: "Local JSON")
                settingRow("Custom flags", value: "\(flags.count)")
            }

            card {
                Label("Data management", systemImage: "externaldrive")
                    .font(.headline)

                Button {
                    prepareExport()
                } label: {
                    Label("Export backup", systemImage: "square.and.arrow.up")
                }

                Button {
                    showingImporter = true
                } label: {
                    Label("Restore from JSON", systemImage: "square.and.arrow.down")
                }
            }

            Text("AppleBlox is an independent project and is not affiliated with Roblox or Bloxstrap.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Add Flag Sheet

    private var addFlagSheet: some View {
        AddFlagView { name, value in
            guard !name.isEmpty else { return }

            if let index = flags.firstIndex(where: { $0.name == name }) {
                flags[index].value = value
            } else {
                flags.append(FlagItem(name: name, value: value))
            }

            saveFlags()
            showingAddFlag = false
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Navigation

    private var bottomNavigation: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.0) { tab in
                Button {
                    selectedTab = tab.0
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.1)
                            .font(.system(size: 17))

                        Text(tab.0)
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(selectedTab == tab.0 ? accent : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white.opacity(0.035))
    }

    // MARK: - Reusable UI

    private func titleBlock(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 27, weight: .bold))

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func card<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.045))
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 17))
    }

    private func quickButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white.opacity(0.045))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func settingRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }

    // MARK: - Persistence

    private func saveFlags() {
        do {
            let data = try JSONEncoder().encode(flags)
            UserDefaults.standard.set(data, forKey: "AppleBlox.Flags")
            status = "Configuration saved locally"
        } catch {
            status = "Could not save configuration"
        }
    }

    private func loadSavedFlags() {
        guard let data = UserDefaults.standard.data(forKey: "AppleBlox.Flags") else {
            return
        }

        do {
            flags = try JSONDecoder().decode([FlagItem].self, from: data)
        } catch {
            status = "Saved configuration could not be read"
        }
    }

    // MARK: - Import / Export

    private func importFlags(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            let object = try JSONSerialization.jsonObject(with: data)

            guard let dictionary = object as? [String: Any] else {
                status = "Invalid JSON: expected an object"
                return
            }

            var imported: [FlagItem] = []

            for (key, value) in dictionary {
                guard let stringValue = value as? String,
                      !key.isEmpty else {
                    continue
                }

                imported.append(FlagItem(name: key, value: stringValue))
            }

            flags = imported.sorted { $0.name < $1.name }
            saveFlags()
            status = "Imported \(flags.count) string-valued entries"
        } catch {
            status = "Import failed: \(error.localizedDescription)"
        }
    }

    private func prepareExport() {
        let dictionary = Dictionary(
            flags.map { ($0.name, $0.value) },
            uniquingKeysWith: { _, latest in latest }
        )

        do {
            let data = try JSONSerialization.data(
                withJSONObject: dictionary,
                options: [.prettyPrinted, .sortedKeys]
            )

            guard let text = String(data: data, encoding: .utf8) else {
                status = "Could not encode JSON"
                return
            }

            exportDocument = FlagDocument(text: text)
            showingExporter = true
        } catch {
            status = "Export failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Launch

    private func launchRoblox() {
        guard let url = URL(string: "roblox://") else { return }

        UIApplication.shared.open(url, options: [:]) { success in
            launchMessage = success
                ? "Roblox launch requested"
                : "Could not open Roblox"
            status = launchMessage
        }
    }
}

// MARK: - Add Flag Form

struct AddFlagView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var value = ""

    let onSave: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Flag details") {
                    TextField("Flag name", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("String value", text: $value)
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Text("This saves a local JSON entry. It does not confirm that Roblox supports or applies the flag.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add FastFlag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), value)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
