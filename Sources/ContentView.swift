import SwiftUI
import UniformTypeIdentifiers

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
        if any is NSNull { self = .null }
        else if let b = any as? NSNumber, CFGetTypeID(b) == CFBooleanGetTypeID() { self = .bool(b.boolValue) }
        else if let n = any as? NSNumber { self = .number(n.doubleValue) }
        else if let s = any as? String { self = .string(s) }
        else if let a = any as? [Any] { self = .array(a.map { JSONValue(any: $0) }) }
        else if let o = any as? [String: Any] { self = .object(o.mapValues { JSONValue(any: $0) }) }
        else { self = .null }
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
        case .bool(let v): return v ? "true" : "false"
        case .number(let v): return v.rounded() == v ? String(Int(v)) : String(v)
        case .string(let v): return v
        case .array, .object:
            if let data = try? JSONSerialization.data(withJSONObject: any, options: [.sortedKeys]),
               let text = String(data: data, encoding: .utf8) { return text }
            return ""
        case .null: return "null"
        }
    }
}

import CoreFoundation

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText] }
    var text: String
    init(text: String = "") { self.text = text }
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

struct ContentView: View {
    @State private var flags: [FlagItem] = [
        FlagItem(key: "ExampleBooleanFlag", value: .bool(true)),
        FlagItem(key: "ExampleNumberFlag", value: .number(60)),
        FlagItem(key: "ExampleStringFlag", value: .string("example"))
    ]
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

    private var filtered: [FlagItem] {
        let result = flags.filter { search.isEmpty || $0.key.localizedCaseInsensitiveContains(search) }
        return result.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if flags.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3").font(.largeTitle).foregroundStyle(.secondary)
                        Text("No flags yet").font(.headline)
                        Text("Add a flag or import a JSON configuration.").font(.footnote).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(filtered) { flag in
                                flagRow(flag)
                                    .contentShape(Rectangle())
                                    .onTapGesture { startEditing(flag) }
                                    .swipeActions {
                                        Button(role: .destructive) { delete(flag) } label: {
                                            Label("Delete", systemImage: "trash")
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
                    Button { showingAdd = true; clearForm() } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Import JSON", systemImage: "square.and.arrow.down") { showingImporter = true }
                        Button("Export JSON", systemImage: "square.and.arrow.up") { prepareExport() }
                        Button("Load example preset", systemImage: "sparkles") { loadExample() }
                        Button("Clear all flags", systemImage: "trash", role: .destructive) { flags = [] }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .searchable(text: $search, prompt: "Search flag names")
            .sheet(isPresented: $showingAdd) { editorSheet(isEditing: false) }
            .sheet(item: $editing) { item in editorSheet(isEditing: true, item: item) }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json, .plainText]) { result in
                importJSON(result)
            }
            .fileExporter(isPresented: $showingExporter, document: exportDocument,
                          contentType: .json, defaultFilename: "ClientAppSettings") { result in
                if case .failure(let error) = result { alertMessage = "Export failed: \(error.localizedDescription)" }
            }
            .alert("FastFlags Manager", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
        .tint(.purple)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: "bolt.fill").foregroundStyle(.purple)
                Text("CONFIGURATION").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
                Text("JSON").font(.caption2.weight(.bold)).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2)).clipShape(Capsule())
            }
            Text("Manage your flags").font(.title2.bold())
            Text("Edit locally, then export a JSON file. Unsupported flags may be ignored by Roblox.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            Label("\(flags.count) total", systemImage: "list.bullet")
            Spacer()
            Text("Tap a flag to edit").foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func flagRow(_ flag: FlagItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(.purple.gradient).frame(width: 4, height: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(flag.key).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(flag.value.display)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            if case .bool(let value) = flag.value {
                Toggle("", isOn: Binding(
                    get: { value },
                    set: { newValue in
                        if let index = flags.firstIndex(where: { $0.id == flag.id }) {
                            flags[index].value = .bool(newValue)
                        }
                    }
                )).labelsHidden().scaleEffect(0.85)
            } else {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }

    private func editorSheet(isEditing: Bool, item: FlagItem? = nil) -> some View {
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
                    Text("Use the exact flag name and value expected by the target client. This app does not verify Roblox support.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isEditing ? "Edit Flag" : "Add Flag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAdd = false; editing = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveFlag(isEditing: isEditing, item: item) }
                        .disabled(newKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let item {
                    newKey = item.key
                    switch item.value {
                    case .bool(let v): newType = "Boolean"; newValue = v ? "true" : "false"
                    case .number(let v): newType = "Number"; newValue = item.value.display
                    case .string(let v): newType = "String"; newValue = v
                    default: newType = "String"; newValue = item.value.display
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func clearForm() { newKey = ""; newValue = "true"; newType = "Boolean" }

    private func startEditing(_ flag: FlagItem) {
        clearForm()
        editing = flag
    }

    private func saveFlag(isEditing: Bool, item: FlagItem?) {
        let key = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
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

        if isEditing, let item, let index = flags.firstIndex(where: { $0.id == item.id }) {
            if key != item.key && flags.contains(where: { $0.key == key && $0.id != item.id }) {
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

    private func delete(_ flag: FlagItem) { flags.removeAll { $0.id == flag.id } }

    private func loadExample() {
        flags = [
            FlagItem(key: "ExampleBooleanFlag", value: .bool(true)),
            FlagItem(key: "ExampleNumberFlag", value: .number(60)),
            FlagItem(key: "ExampleStringFlag", value: .string("example"))
        ]
        alertMessage = "Example preset loaded. These are placeholders, not guaranteed Roblox-supported flags."
    }

    private func makeJSON() throws -> String {
        var dictionary: [String: Any] = [:]
        for flag in flags {
            guard dictionary[flag.key] == nil else { throw NSError(domain: "FastFlags", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Duplicate key: \(flag.key)"]) }
            dictionary[flag.key] = flag.value.any
        }
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
        guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
        return text
    }

    private func prepareExport() {
        do {
            let text = try makeJSON()
            guard (try JSONSerialization.jsonObject(with: Data(text.utf8))) is [String: Any] else {
                alertMessage = "JSON must be an object of flag names and values."
                return
            }
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
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any] else {
                alertMessage = "Expected a JSON object with flag names as keys."
                return
            }
            flags = dictionary.keys.sorted().map { FlagItem(key: $0, value: JSONValue(any: dictionary[$0]!)) }
            alertMessage = "Imported \(flags.count) flags."
        } catch {
            alertMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}
