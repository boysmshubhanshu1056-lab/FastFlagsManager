import SwiftUI
import UniformTypeIdentifiers

struct FastFlag: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var value: String
}

struct ContentView: View {
    @State private var flags: [FastFlag] = []
    @State private var newFlagName = ""
    @State private var newFlagValue = ""
    @State private var showExportAlert = false
    @State private var showImportPicker = false
    @State private var exportMessage = ""
    
    // The shared folder ID
    let appGroupID = "group.com.prism.fastflags"
    
    var body: some View {
        NavigationView {
            VStack {
                // Add Flag Input
                HStack {
                    TextField("Flag Name", text: $newFlagName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    TextField("Value", text: $newFlagValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    Button(action: addFlag) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                .padding()
                
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
                
                // Action Buttons
                VStack(spacing: 12) {
                    HStack {
                        Button(action: { showImportPicker = true }) {
                            Label("Import JSON", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: exportJSON) {
                            Label("Export JSON", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button(action: launchRoblox) {
                        Label("Launch Roblox", systemImage: "gamecontroller.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }
                .padding()
            }
            .navigationTitle("FastFlags")
            .onAppear(perform: prepareAppGroup)
            .alert(isPresented: $showExportAlert) {
                Alert(title: Text("Status"), message: Text(exportMessage), dismissButton: .default(Text("OK")))
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
        }
    }
    
    // MARK: - Functions
    
    func prepareAppGroup() {
        // Ensure the App Group folder exists (prevents the Bad File Descriptor crash)
        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            print("App Group is ready at: \(sharedURL.path)")
        } else {
            print("Warning: App Group not configured in entitlements.")
        }
    }
    
    func addFlag() {
        let name = newFlagName.trimmingCharacters(in: .whitespaces)
        let value = newFlagValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !value.isEmpty else { return }
        
        flags.append(FastFlag(name: name, value: value))
        newFlagName = ""
        newFlagValue = ""
    }
    
    func deleteFlag(_ flag: FastFlag) {
        flags.removeAll { $0.id == flag.id }
    }
    
    func deleteItems(at offsets: IndexSet) {
        flags.remove(atOffsets: offsets)
    }
    
    func exportJSON() {
        var jsonDict: [String: Any] = [:]
        for flag in flags {
            jsonDict[flag.name] = flag.value
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted) else {
            exportMessage = "Failed to create JSON data."
            showExportAlert = true
            return
        }
        
        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = sharedURL.appendingPathComponent("ClientAppSettings.json")
            do {
                try jsonData.write(to: fileURL)
                exportMessage = "Successfully saved to App Group folder!\n\nPath: \(fileURL.lastPathComponent)"
            } catch {
                exportMessage = "Error saving: \(error.localizedDescription)"
            }
        } else {
            // Fallback to local
            let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ClientAppSettings.json")
            try? jsonData.write(to: localURL)
            exportMessage = "App Group not found. Saved to local Documents folder instead."
        }
        showExportAlert = true
    }
    
    func handleImport(result: Result<[URL], Error>) {
        do {
            guard let selectedFile = try result.get().first else { return }
            
            // Must access security scoped resource for imported files
            guard selectedFile.startAccessingSecurityScopedResource() else {
                exportMessage = "Permission denied to read file."
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
                exportMessage = "Successfully imported \(flags.count) flags."
            } else {
                exportMessage = "Invalid JSON format."
            }
        } catch {
            exportMessage = "Import error: \(error.localizedDescription)"
        }
        showExportAlert = true
    }
    
    func launchRoblox() {
        if let url = URL(string: "roblox://") {
            UIApplication.shared.open(url)
        }
    }
}
