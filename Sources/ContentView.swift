
import SwiftUI
import UniformTypeIdentifiers
import UIKit
import CoreFoundation

struct FlagItem: Identifiable, Hashable {
    var id = UUID()
    var key: String
    var value: JSONValue
}

indirect enum JSONValue: Hashable {
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(any: Any) {
        if any is NSNull {
            self = .null
        } else if let b = any as? NSNumber,
                  CFGetTypeID(b) == CFBooleanGetTypeID() {
            self = .bool(b.boolValue)
        } else if let n = any as? NSNumber {
            self = .number(n.doubleValue)
        } else if let s = any as? String {
            self = .string(s)
        } else if let a = any as? [Any] {
            self = .array(a.map { JSONValue(any: $0) })
        } else if let o = any as? [String: Any] {
            self = .object(o.mapValues { JSONValue(any: $0) })
        } else {
            self = .null
        }
    }

    var any: Any {
        switch self {
        case .bool(let v): return v
        case .number(let v): return v
        case .string(let v): return v
        case .array(let v): return v.map(\.any)
        case .object(let v): return v.mapValues(\.any)
        case .null: return NSNull()
        }
    }

    var display: String {
        switch self {
        case .bool(let v):
            return v ? "true" : "false"
        case .number(let v):
            return v.rounded() == v ? String(Int(v)) : String(v)
        case .string(let v):
            return v
        case .array, .object:
            if let data = try? JSONSerialization.data(
                withJSONObject: any,
                options: [.sortedKeys]
            ), let text = String(data: data, encoding: .utf8) {
                return text
            }
            return ""
        case .null:
            return "null"
        }
    }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.json, .plainText]
    }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct SavedPreset: Identifiable, Codable {
    var id = UUID()
    var name: String
    var json: String
}

struct ContentView: View {
    @State private var flags: [FlagItem] = [
        FlagItem(key: "ExampleBooleanFlag", value: .bool(true)),
        FlagItem(key: "ExampleNumberFlag", value: .number(60)),
        FlagItem(key: "ExampleStringFlag", value: .string("example"))
    ]

    @State private var selectedTab = "Fast Flags"
    @State private var search = ""
    @State private var showingAdd = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument = JSONDocument()
    @State private var alertMessage: String?
    @State private var editing: FlagItem?
    @State private var newKey = ""
    @State private var newValue = "true"
    @State private var newType = "Boolean"
    @State private var showingPresets = false
    @State private var presetName = ""

    @AppStorage("savedFlagPresetsData")
    private var savedPresetsData: Data = Data()

    // This is a local UI preference, not an actual Roblox FPS limiter.
    @AppStorage("generalFPSCap")
    private var fpsCap = 60

    private var savedPresets: [SavedPreset] {
        (try? JSONDecoder().decode(
            [SavedPreset].self,
            from: savedPresetsData
        )) ?? []
    }

    private var filtered: [FlagItem] {
        flags
            .filter {
                search.isEmpty ||
                $0.key.localizedCaseInsensitiveContains(search)
            }
            .sorted {
                $0.key.localizedCaseInsensitiveCompare($1.key)
                    == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                Picker("Section", selection: $selectedTab) {
                    Text("General").tag("General")
                    Text("Fast Flags").tag("Fast Flags")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                if selectedTab == "General" {
                    generalSettings
                } else if flags.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("No flags yet")
                            .font(.headline)

                        Text("Add a flag or import a JSON configuration.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(filtered) { flag in
                                flagRow(flag)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        startEditing(flag)
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            delete(flag)
                                        } label: {
                                            Label(
                                                "Delete",
                                                systemImage: "trash"
                                            )
                                        }
                                    }
                            }
                        } header: {
                            Text("\(filtered.count) FLAGS")
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                footer
            }
            .background(Color.black)
            .navigationTitle("FastFlags")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == "Fast Flags" {
                        Button {
                            clearForm()
                            showingAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(
                            "Import JSON",
                            systemImage: "square.and.arrow.down"
                        ) {
                            showingImporter = true
                        }

                        Button(
                            "Export JSON",
                            systemImage: "square.and.arrow.up"
                        ) {
                            prepareExport()
                        }

                        Button(
                            "Saved Presets (\(savedPresets.count)/10)",
                            systemImage: "square.stack.3d.up"
                        ) {
                            showingPresets = true
                        }

                        Button(
                            "Load example preset",
                            systemImage: "sparkles"
                        ) {
                            loadExample()
                        }

                        Button(
                            "Clear all flags",
                            systemImage: "trash",
                            role: .destructive
                        ) {
                            flags = []
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .searchable(
                text: $search,
                prompt: selectedTab == "General"
                    ? "Search settings"
                    : "Search flag names"
            )
            .sheet(isPresented: $showingAdd) {
                editorSheet(isEditing: false)
            }
            .sheet(item: $editing) { item in
                editorSheet(isEditing: true, item: item)
            }
            .sheet(isPresented: $showingPresets) {
                presetsSheet
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json, .plainText]
            ) { result in
                importJSON(result)
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "ClientAppSettings"
            ) { result in
                if case .failure(let error) = result {
                    alertMessage = "Export failed: \(error.localizedDescription)"
                }
            }
            .alert(
                "FastFlags Manager",
                isPresented: Binding(
                    get: { alertMessage != nil },
                    set: { if !$0 { alertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    alertMessage = nil
                }
            } message: {
                Text(alertMessage ?? "")
            }
        }
        .tint(.purple)
    }

    // MARK: - General

    private var generalSettings: some View {
        Form {
            Section("Appearance") {
                Toggle(
                    "Grey Sky",
                    isOn: Binding(
                        get: {
                            boolFlag("FFlagDebugSkyGray") ?? false
                        },
                        set: { enabled in
                            setFlag(
                                "FFlagDebugSkyGray",
                                value: .bool(enabled)
                            )
                        }
                    )
                )

                Toggle(
                    "Reduced Visuals",
                    isOn: Binding(
                        get: {
                            numberFlag(
                                "DFIntDebugFRMQualityLevelOverride"
                            ) != nil
                        },
                        set: { enabled in
                            if enabled {
                                setFlag(
                                    "DFIntDebugFRMQualityLevelOverride",
                                    value: .number(1)
                                )
                            } else {
                                removeFlag(
                                    "DFIntDebugFRMQualityLevelOverride"
                                )
                            }
                        }
                    )
                )

                Text(
                    "These controls edit candidate values in your JSON. " +
                    "Roblox may ignore flags that aren't supported."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Frame Rate") {
                Picker("FPS Preference", selection: $fpsCap) {
                    Text("30 FPS").tag(30)
                    Text("60 FPS").tag(60)
                    Text("120 FPS").tag(120)
                    Text("Unlimited").tag(0)
                }

                Text(
                    "This preference is saved locally in this app. " +
                    "It does not cap Roblox's frame rate or export an " +
                    "unverified FPS flag."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Configuration") {
                Button("Export JSON") {
                    prepareExport()
                }

                Button("Import JSON") {
                    showingImporter = true
                }

                Button("Saved Presets") {
                    showingPresets = true
                }

                Button("Open Fast Flags Editor") {
                    selectedTab = "Fast Flags"
                }
            }

            Section("Roblox") {
                Button {
                    launchRoblox()
                } label: {
                    Label(
                        "Launch Roblox",
                        systemImage: "play.fill"
                    )
                }

                Text(
                    "Launching Roblox does not apply this app's JSON. " +
                    "Actual effects depend on supported Roblox settings " +
                    "and a working way to deliver them to the client."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Header and footer

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.purple)

                Text("CONFIGURATION")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("JSON")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .clipShape(Capsule())
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Manage your flags")
                        .font(.title2.bold())

                    Text(
                        "Edit locally and export JSON. " +
                        "Unsupported flags may be ignored by Roblox."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button(action: launchRoblox) {
                    Label("Roblox", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.purple.opacity(0.22))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            Label(
                "\(flags.count) total",
                systemImage: "list.bullet"
            )

            Spacer()

            Text(
                selectedTab == "General"
                    ? "General settings"
                    : "Tap a flag to edit"
            )
            .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Flag rows

    @ViewBuilder
    private func flagRow(_ flag: FlagItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(.purple.gradient)
                .frame(width: 4, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(flag.key)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text(flag.value.display)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            if case .bool(let value) = flag.value {
                Toggle(
                    "",
                    isOn: Binding(
                        get: {
                            flags.first(where: { $0.id == flag.id })?
                                .value.display == "true"
                        },
                        set: { newValue in
                            if let index = flags.firstIndex(
                                where: { $0.id == flag.id }
                            ) {
                                flags[index].value = .bool(newValue)
                            }
                        }
                    )
                )
                .labelsHidden()
                .scaleEffect(0.85)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Editor

    private func editorSheet(
        isEditing: Bool,
        item: FlagItem? = nil
    ) -> some View {
        NavigationStack {
            Form {
                Section("Flag") {
                    TextField("Flag name", text: $newKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Value type", selection: $newType) {
                        Text("Boolean").tag("Boolean")
                        Text("Number").tag("Number")
                        Text("String").tag("String")
                    }
                    .pickerStyle(.segmented)

                    TextField("Value", text: $newValue, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Text(
                        "Use the exact flag name and value expected by " +
                        "the target client. This app cannot verify Roblox support."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isEditing ? "Edit Flag" : "Add Flag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAdd = false
                        editing = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveFlag(isEditing: isEditing, item: item)
                    }
                    .disabled(
                        newKey.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
            }
            .onAppear {
                if let item {
                    newKey = item.key

                    switch item.value {
                    case .bool(let v):
                        newType = "Boolean"
                        newValue = v ? "true" : "false"
                    case .number:
                        newType = "Number"
                        newValue = item.value.display
                    case .string(let v):
                        newType = "String"
                        newValue = v
                    default:
                        newType = "String"
                        newValue = item.value.display
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Presets

    private var presetsSheet: some View {
        NavigationStack {
            Form {
                Section("Save current flags") {
                    TextField("Preset name", text: $presetName)

                    Button {
                        saveCurrentPreset()
                    } label: {
                        Label(
                            "Save Preset (\(savedPresets.count)/10)",
                            systemImage: "square.and.arrow.down"
                        )
                    }
                    .disabled(
                        presetName.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty || savedPresets.count >= 10
                    )

                    if savedPresets.count >= 10 {
                        Text(
                            "You've reached the limit of 10 saved presets. " +
                            "Delete one to save another."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Your saved presets") {
                    if savedPresets.isEmpty {
                        Text("No saved presets yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(savedPresets) { preset in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.name)
                                        .font(.headline)

                                    Text(
                                        "\(presetFlagCount(preset.json)) flags"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Load") {
                                    loadPreset(preset)
                                }
                                .buttonStyle(.borderedProminent)

                                Button(role: .destructive) {
                                    deletePreset(preset)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Section {
                    Text(
                        "Presets are stored on this iPad. " +
                        "Loading a preset changes local JSON only."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Saved Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingPresets = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func updateSavedPresets(_ presets: [SavedPreset]) {
        savedPresetsData = (try? JSONEncoder().encode(presets)) ?? Data()
    }

    private func saveCurrentPreset() {
        guard savedPresets.count < 10 else {
            alertMessage = "You can save a maximum of 10 presets."
            return
        }

        let name = presetName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !name.isEmpty else { return }

        do {
            let json = try makeJSON()
            var presets = savedPresets
            presets.append(SavedPreset(name: name, json: json))
            updateSavedPresets(presets)
            presetName = ""
            alertMessage = "Preset saved on this iPad."
        } catch {
            alertMessage = "Could not save preset: \(error.localizedDescription)"
        }
    }

    private func loadPreset(_ preset: SavedPreset) {
        do {
            let object = try JSONSerialization.jsonObject(
                with: Data(preset.json.utf8)
            )

            guard let dictionary = object as? [String: Any] else {
                alertMessage = "This preset is not a valid flags object."
                return
            }

            flags = dictionary.keys.sorted().map {
                FlagItem(key: $0, value: JSONValue(any: dictionary[$0]!))
            }

            showingPresets = false
            alertMessage =
                "Loaded \(preset.name). The configuration is local and " +
                "has not been applied to Roblox."
        } catch {
            alertMessage = "Could not load preset: \(error.localizedDescription)"
        }
    }

    private func deletePreset(_ preset: SavedPreset) {
        updateSavedPresets(
            savedPresets.filter { $0.id != preset.id }
        )
    }

    private func presetFlagCount(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return "0"
        }

        return String(dictionary.count)
    }

    // MARK: - Flag helpers

    private func setFlag(_ key: String, value: JSONValue) {
        if let index = flags.firstIndex(where: { $0.key == key }) {
            flags[index].value = value
        } else {
            flags.append(FlagItem(key: key, value: value))
        }
    }

    private func removeFlag(_ key: String) {
        flags.removeAll { $0.key == key }
    }

    private func boolFlag(_ key: String) -> Bool? {
        guard let flag = flags.first(where: { $0.key == key }),
              case .bool(let value) = flag.value else {
            return nil
        }

        return value
    }

    private func numberFlag(_ key: String) -> Double? {
        guard let flag = flags.first(where: { $0.key == key }),
              case .number(let value) = flag.value else {
            return nil
        }

        return value
    }

    // MARK: - Launch Roblox

    private func launchRoblox() {
        guard let url = URL(string: "roblox://") else {
            alertMessage = "Could not create the Roblox launch URL."
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                alertMessage =
                    "Roblox couldn't be opened. Make sure it is installed. " +
                    "This button launches Roblox but does not apply FastFlags."
            }
        }
    }

    // MARK: - Add, edit and delete flags

    private func clearForm() {
        newKey = ""
        newValue = "true"
        newType = "Boolean"
    }

    private func startEditing(_ flag: FlagItem) {
        clearForm()
        editing = flag
    }

    private func saveFlag(isEditing: Bool, item: FlagItem?) {
        let key = newKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let value: JSONValue

        switch newType {
        case "Boolean":
            guard ["true", "false"].contains(newValue.lowercased()) else {
                alertMessage = "Boolean values must be true or false."
                return
            }

            value = .bool(newValue.lowercased() == "true")

        case "Number":
            guard let number = Double(newValue) else {
                alertMessage = "Enter a valid number."
                return
            }

            value = .number(number)

        default:
            value = .string(newValue)
        }

        if isEditing,
           let item,
           let index = flags.firstIndex(where: { $0.id == item.id }) {
            if key != item.key &&
                flags.contains(where: { $0.key == key && $0.id != item.id }) {
                alertMessage = "A flag with that name already exists."
                return
            }

            flags[index].key = key
            flags[index].value = value
            editing = nil
        } else {
            guard !flags.contains(where: { $0.key == key }) else {
                alertMessage = "A flag with that name already exists."
                return
            }

            flags.append(FlagItem(key: key, value: value))
            showingAdd = false
        }
    }

    private func delete(_ flag: FlagItem) {
        flags.removeAll { $0.id == flag.id }
    }

    private func loadExample() {
        flags = [
            FlagItem(key: "ExampleBooleanFlag", value: .bool(true)),
            FlagItem(key: "ExampleNumberFlag", value: .number(60)),
            FlagItem(key: "ExampleStringFlag", value: .string("example"))
        ]

        alertMessage =
            "Example configuration loaded. These are placeholders, " +
            "not guaranteed Roblox-supported flags."
    }

    // MARK: - JSON import and export

    private func makeJSON() throws -> String {
        var dictionary: [String: Any] = [:]

        for flag in flags {
            guard dictionary[flag.key] == nil else {
                throw NSError(
                    domain: "FastFlags",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Duplicate key: \(flag.key)"
                    ]
                )
            }

            dictionary[flag.key] = flag.value.any
        }

        let data = try JSONSerialization.data(
            withJSONObject: dictionary,
            options: [.prettyPrinted, .sortedKeys]
        )

        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }

        return text
    }

    private func prepareExport() {
        do {
            let text = try makeJSON()

            exportDocument = JSONDocument(text: text)
            showingExporter = true
        } catch {
            alertMessage = "Could not create JSON: \(error.localizedDescription)"
        }
    }

    private func importJSON(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let object = try JSONSerialization.jsonObject(with: data)

            guard let dictionary = object as? [String: Any] else {
                alertMessage =
                    "Expected a JSON object with flag names as keys."
                return
            }

            flags = dictionary.keys.sorted().map {
                FlagItem(key: $0, value: JSONValue(any: dictionary[$0]!))
            }

            alertMessage = "Imported \(flags.count) flags."
        } catch {
            alertMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}
 
