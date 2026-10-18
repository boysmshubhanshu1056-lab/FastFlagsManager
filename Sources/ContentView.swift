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
    
    @State private var showAlert = false
    @State private var showImportPicker = false
    @State private var showSavePresetAlert = false
    @State private var alertMessage = ""
    
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
                                showAlert = true
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
        .sheet(isPresented: $showImportPicker) {
            JSONDocumentPicker { importedFlags, errorMessage in
                if let importedFlags = importedFlags {
                    // Filter out dangerous flags on import
                    let safeFlags = importedFlags.filter { !isDangerous($0.name) }
                    self.flags = safeFlags
                    self.alertMessage = "Imported \(safeFlags.count) flags. (Dangerous flags removed)."
                } else {
                    self.alertMessage = errorMessage ?? "Unknown error."
                }
                self.showAlert = true
            }
        }
        .alert("Status", isPresented: $showAlert) {
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
    
    func isDangerous(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower.contains("anticheat") || lower.contains("bypass") || lower.contains("hitbox") || lower.contains("memoryscan") {
            return true
        }
        return false
    }
    
    func addFlag() {
        let name = newFlagName.trimmingCharacters(in: .whitespaces)
        let value = newFlagValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !value.isEmpty else { return }
        
        if isDangerous(name) {
            alertMessage = "Blocked: Anti-Cheat bypass flags will get you banned."
            showAlert = true
            return
        }
        
        if let index = flags.firstIndex(where: { $0.name == name }) {
            flags[index].value = value
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
            showAlert = true
            return
        }
        
        if let index = presets.firstIndex(where: { $0.name == trimmedName }) {
            presets[index].flags = flags
        } else {
            presets.append(FastFlagsPreset(name: trimmedName, flags: flags))
        }
        
        savePresetsToDisk()
        newPresetName = ""
        alertMessage = "Preset saved!"
        showAlert = true
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
            showAlert = true
            return
        }
        
        // LIVE CONTAINER FIX: Save to local documents
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("ClientAppSettings.json")
        
        do {
            try jsonData.write(to: fileURL)
            alertMessage = "Saved successfully!\n\nNow go to LiveContainer, long-press FastFlags, and tap 'Open Data Folder' to find it."
        } catch {
            alertMessage = "Error saving: \(error.localizedDescription)"
        }
        
        showAlert = true
    }
    
    func launchRoblox() {
        if let url = URL(string: "roblox://") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - UIKit Document Picker for JSON
struct JSONDocumentPicker: UIViewControllerRepresentable {
    var completion: ([FastFlag]?, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: JSONDocumentPicker
        
        init(_ parent: JSONDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selectedFile = urls.first else { return }
            
            do {
                let data = try Data(contentsOf: selectedFile)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    var newFlags: [FastFlag] = []
                    for (key, value) in json {
                        newFlags.append(FastFlag(name: key, value: "\(value)"))
                    }
                    DispatchQueue.main.async {
                        self.parent.completion(newFlags, nil)
                        self.parent.dismiss()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.parent.completion(nil, "Invalid JSON format.")
                        self.parent.dismiss()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.parent.completion(nil, "Import error: \(error.localizedDescription)")
                    self.parent.dismiss()
                }
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}
