import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct FastFlag: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var value: String
}

struct FastFlagsPreset: Identifiable, Codable {
    var id = UUID()
    var name: String
    var flags: [FastFlag]
}

struct ContentView: View {
    @State private var flags: [FastFlag] = []
    @State private var presets: [FastFlagsPreset] = []
    
    @State private var newFlagName = ""
    @State private var newFlagValue = ""
    @State private var newPresetName = ""
    
    @State private var showExportAlert = false
    @State private var showImportPicker = false
    @State private var showSavePresetAlert = false
    @State private var alertMessage = ""
    
    let appGroupID = "group.com.prism.fastflags"
    
    var body: some View {
        NavigationSplitView {
            // LEFT SIDEBAR
            List {
                Section(header: Text("Saved Presets")) {
                    if presets.isEmpty {
                        Text("No presets saved.").foregroundColor(.gray)
                    } else {
                        ForEach(presets) { preset in
                            Button(action: {
                                flags = preset.flags
                                alertMessage = "Loaded preset: \(preset.name)"
                                showExportAlert = true
                            }) {
                                Text(preset.name)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deletePreset(preset)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Actions")) {
                    Button(action: { showSavePresetAlert = true }) {
                        Label("Save Current as Preset", systemImage: "square.and.arrow.down.on.square")
                    }
                    .disabled(flags.isEmpty)
                    
                    Button(role: .destructive, action: clearAllFlags) {
                        Label("Delete All Flags", systemImage: "trash.fill")
                    }
                    .disabled(flags.isEmpty)
                }
            }
            .navigationTitle("FastFlags")
            .toolbar {
                Button(action: { showImportPicker = true }) {
                    Image(systemName: "square.and.arrow.down")
                }
            }
        } detail: {
            // RIGHT SIDE (MAIN BLOCK)
            VStack(spacing: 0) {
                // Add New Flag Area
                VStack(alignment: .leading) {
                    Text("Add New Flag").font(.headline).padding(.top)
                    
                    HStack {
                        TextField("Flag Name (e.g., FFlagDebug)", text: $newFlagName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .font(.system(.body, design: .monospaced))
                        
                        TextField("Value (e.g., True)", text: $newFlagValue)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 150)
                        
                        Button(action: addFlag) {
                            Image(systemName: "plus.circle.fill").font(.title2)
                        }
                        .disabled(newFlagName.isEmpty || newFlagValue.isEmpty)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                
                // Flag List
                List {
                    ForEach(flags) { flag in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(flag.name).bold().font(.system(.body, design: .monospaced))
                                Text(flag.value).foregroundColor(.gray).font(.system(.caption, design: .monospaced))
                            }
                            Spacer()
                            Button(action: { deleteFlag(flag) }) {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.plain)
                
                // Bottom Toolbar
                HStack(spacing: 20) {
                    Button(action: exportJSON) {
                        Label("Export ClientAppSettings.json", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: launchRoblox) {
                        Label("Launch Roblox", systemImage: "gamecontroller.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
            }
        }
        .onAppear(perform: loadPresets)
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            handleImport(result: result)
        }
        .alert("Status", isPresented: $showExportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("Save Preset", isPresented: $showSavePresetAlert) {
            TextField("Preset Name", text: $newPresetName)
            Button("Save") { savePreset() }
            Button("Cancel", role: .cancel) { newPresetName = "" }
        } message: {
            Text("Enter a name for these flags (Max 10).")
        }
    }
    
    // MARK: - Functions
    
    func addFlag() {
        let name = newFlagName.trimmingCharacters(in: .whitespaces)
        let value = newFlagValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !value.isEmpty else { return }
        
        if let index = flags.firstIndex(where: { $0.name == name }) {
            flags[index].value = value // Update existing
        } else {
            flags.append(FastFlag(name: name, value: value))
        }
        newFlagName = ""
        newFlagValue = ""
    }
    
    func deleteFlag(_ flag: FastFlag) {
        flags.removeAll { $0.id == flag.id }
    }
    
    func deleteItems(at offsets: IndexSet) {
        flags.remove(atOffsets: offsets)
    }
    
    func clearAllFlags() {
        flags.removeAll()
    }
    
    func savePreset() {
        let trimmedName = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, flags.count > 0 else { return }
        
        if presets.count >= 10 && !presets.contains(where: { $0.name == trimmedName }) {
            alertMessage = "You can only save up to 10 presets. Delete one first."
            showExportAlert = true
            return
        }
        
        if let index = presets.firstIndex(where: { $0.name == trimmedName }) {
            presets[index].flags = flags // Overwrite existing preset
        } else {
            presets.append(FastFlagsPreset(name: trimmedName, flags: flags))
        }
        
        savePresetsToDisk()
        newPresetName = ""
        alertMessage = "Preset saved!"
        showExportAlert = true
    }
    
    func deletePreset(_ preset: FastFlagsPreset) {
        presets.removeAll { $0.id == preset.id }
        savePresetsToDisk()
    }
    
    func savePresetsToDisk() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: "SavedPresets")
        }
    }
    
    func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: "SavedPresets"),
           let decoded = try? JSONDecoder().decode([FastFlagsPreset].self, from: data) {
            presets = decoded
        }
    }
    
    func exportJSON() {
        var jsonDict: [String: Any] = [:]
        for flag in flags {
            jsonDict[flag.name] = flag.value
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted) else {
            alertMessage = "Failed to create JSON data."
            showExportAlert = true
            return
        }
        
        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = sharedURL.appendingPathComponent("ClientAppSettings.json")
            do {
                try jsonData.write(to: fileURL)
                alertMessage = "Successfully saved to App Group folder!\n\nPath: \(fileURL.lastPathComponent)"
            } catch {
                alertMessage = "Error saving: \(error.localizedDescription)"
            }
        } else {
            let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ClientAppSettings.json")
            try? jsonData.write(to: localURL)
            alertMessage = "App Group not found. Saved to local Documents folder instead."
        }
        showExportAlert = true
    }
    
    func handleImport(result: Result<[URL], Error>) {
        do {
            guard let selectedFile = try result.get().first else { return }
            guard selectedFile.startAccessingSecurityScopedResource() else {
                alertMessage = "Permission denied to read file."
                showExportAlert = true
                return
            }
            defer { selectedFile.stopAccessingSecurityScopedResource() }
            
            let data = try Data(contentsOf: selectedFile)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                flags.removeAll()
                for (key, value) in json {
                    flags.append(FastFlag(name: key, value: "\(value)"))
                }
                alertMessage = "Successfully imported \(flags.count) flags."
            } else {
                alertMessage = "Invalid JSON format."
            }
        } catch {
            alertMessage = "Import error: \(error.localizedDescription)"
        }
        showExportAlert = true
    }
    
    func launchRoblox() {
        if let url = URL(string: "roblox://") {
            UIApplication.shared.open(url)
        }
    }
}
