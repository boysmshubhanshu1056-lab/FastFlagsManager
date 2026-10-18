import SwiftUI
import UniformTypeIdentifiers
import UIKit

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
            .sheet(isPresented: $showImportPicker) {
                // Using the reliable UIKit picker
                JSONDocumentPicker { importedFlags, errorMessage in
                    if let importedFlags = importedFlags {
                        self.flags = importedFlags
                        self.exportMessage = "Successfully imported \(importedFlags.count) flags."
                    } else {
                        self.exportMessage = errorMessage ?? "Unknown error."
                    }
                    self.showExportAlert = true
                }
            }
        }
    }
    
    // MARK: - Functions
    
    func prepareAppGroup() {
        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            print("App Group is ready at: \(sharedURL.path)")
        } else {
            print("Warning: App Group not configured.")
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
            let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ClientAppSettings.json")
            try? jsonData.write(to: localURL)
            exportMessage = "App Group not found. Saved to local Documents folder instead."
        }
        showExportAlert = true
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
