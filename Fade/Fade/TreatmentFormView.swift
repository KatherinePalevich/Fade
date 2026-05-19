import SwiftUI
import SwiftData

struct TreatmentFormView: View {
    @Environment(\.modelContext) private var modelContext
    
    let standardMeds = ["Terbinafine 1%", "Clotrimazole 1%", "Ketoconazole 2%", "Custom"]
    
    @State private var selectedMedIndex = 0
    @State private var customMedName = ""
    @State private var wasCleaned = false
    @State private var changedUndergarments = false
    @State private var notes = ""
    @State private var logDate = Date()
    @State private var showUpdatePrompt = false
    @State private var lastCreatedLog: TreatmentLog?
    
    @Binding var selectedTab: Int
    @Binding var activeTreatmentContext: TreatmentLog?
    @Binding var isEditMode: Bool
    @Binding var editingTreatmentLog: TreatmentLog?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Medication")) {
                    Picker("Select Treatment", selection: $selectedMedIndex) {
                        ForEach(0..<standardMeds.count, id: \.self) { index in
                            Text(standardMeds[index]).tag(index)
                        }
                    }
                    
                    if standardMeds[selectedMedIndex] == "Custom" {
                        TextField("Custom Medication Name", text: $customMedName)
                    }
                }
                
                Section(header: Text("Application Details")) {
                    DatePicker("Date and Time", selection: $logDate)
                    Toggle("Applied after shower?", isOn: $wasCleaned)
                    Toggle("Changed base undergarments?", isOn: $changedUndergarments)
                    TextField("Notes (optional)", text: $notes)
                }
                
                Button(editingTreatmentLog != nil ? "Update Log Treatment" : "Log Treatment") {
                    saveTreatment()
                }
                .disabled(standardMeds[selectedMedIndex] == "Custom" && customMedName.isEmpty)
            }
            .navigationTitle(editingTreatmentLog != nil ? "Update Log Treatment" : "Log Treatment")
            .onChange(of: editingTreatmentLog) { newLog in
                if let log = newLog {
                    if let idx = standardMeds.firstIndex(of: log.medicationName) {
                        selectedMedIndex = idx
                        customMedName = ""
                    } else {
                        selectedMedIndex = standardMeds.firstIndex(of: "Custom") ?? 3
                        customMedName = log.medicationName
                    }
                    wasCleaned = log.wasCleaned
                    changedUndergarments = log.changedUndergarments
                    notes = log.notes
                    logDate = log.timestamp
                } else {
                    customMedName = ""
                    wasCleaned = false
                    changedUndergarments = false
                    notes = ""
                    logDate = Date()
                    selectedMedIndex = 0
                }
            }
            .alert("Treatment Logged", isPresented: $showUpdatePrompt) {
                Button("Yes") {
                    activeTreatmentContext = lastCreatedLog
                    isEditMode = true
                    selectedTab = 0 // Switch to Body Map
                }
                Button("No, thanks", role: .cancel) { }
            } message: {
                Text("Would you like to update your rash sizes now?")
            }
        }
    }
    
    private func saveTreatment() {
        let medName = standardMeds[selectedMedIndex] == "Custom" ? customMedName : standardMeds[selectedMedIndex]
        
        if let existingLog = editingTreatmentLog {
            existingLog.medicationName = medName
            existingLog.wasCleaned = wasCleaned
            existingLog.changedUndergarments = changedUndergarments
            existingLog.notes = notes
            existingLog.timestamp = logDate
            
            editingTreatmentLog = nil
            selectedTab = 2 // Return to Summary view
        } else {
            let newLog = TreatmentLog(timestamp: logDate, medicationName: medName, wasCleaned: wasCleaned, changedUndergarments: changedUndergarments, notes: notes)
            modelContext.insert(newLog)
            lastCreatedLog = newLog
            
            customMedName = ""
            wasCleaned = false
            changedUndergarments = false
            notes = ""
            logDate = Date()
            
            showUpdatePrompt = true
        }
    }
}
