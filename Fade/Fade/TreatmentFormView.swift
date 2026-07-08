import SwiftUI
import SwiftData

struct TreatmentFormView: View {
    @Environment(\.modelContext) private var modelContext
    
    let standardMeds = ["Terbinafine 1%", "Clotrimazole 1%", "Ketoconazole 2%", "Custom"]
    
    @State private var selectedMedIndex = 2
    @State private var customMedName = ""
    @State private var wasCleaned = false
    @State private var changedUndergarments = false
    @State private var notes = ""
    @State private var logDate = Date()
    @State private var showUpdatePrompt = false
    @State private var lastCreatedLog: TreatmentLog?
    
    @State private var tookOralPill = false
    @State private var selectedOralMed = "Terbinafine"
    
    @Binding var selectedTab: Int
    @Binding var activeTreatmentContext: TreatmentLog?
    @Binding var isEditMode: Bool
    @Binding var editingTreatmentLog: TreatmentLog?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Topical Cream")) {
                    Picker("Select Cream", selection: $selectedMedIndex) {
                        ForEach(0..<standardMeds.count, id: \.self) { index in
                            Text(standardMeds[index]).tag(index)
                        }
                    }
                    
                    if standardMeds[selectedMedIndex] == "Custom" {
                        TextField("Custom Medication Name", text: $customMedName)
                    }
                }
                
                Section(header: Text("Oral Pill")) {
                    Toggle("Oral medication taken?", isOn: $tookOralPill)
                    if tookOralPill {
                        Picker("Select Oral Medication", selection: $selectedOralMed) {
                            Text("Itraconazole").tag("Itraconazole")
                            Text("Terbinafine").tag("Terbinafine")
                        }
                        .pickerStyle(.segmented)
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
                    
                    if let oral = log.oralMedicationName, !oral.isEmpty {
                        tookOralPill = true
                        selectedOralMed = oral
                    } else {
                        tookOralPill = false
                        selectedOralMed = "Itraconazole"
                    }
                } else {
                    customMedName = ""
                    wasCleaned = false
                    changedUndergarments = false
                    notes = ""
                    logDate = Date()
                    selectedMedIndex = 2
                    tookOralPill = false
                    selectedOralMed = "Itraconazole"
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
        let oralMed: String? = tookOralPill ? selectedOralMed : nil
        
        if let existingLog = editingTreatmentLog {
            existingLog.medicationName = medName
            existingLog.wasCleaned = wasCleaned
            existingLog.changedUndergarments = changedUndergarments
            existingLog.notes = notes
            existingLog.timestamp = logDate
            existingLog.oralMedicationName = oralMed
            
            editingTreatmentLog = nil
            selectedTab = 2 // Return to Summary view
        } else {
            let newLog = TreatmentLog(timestamp: logDate, medicationName: medName, wasCleaned: wasCleaned, changedUndergarments: changedUndergarments, notes: notes, oralMedicationName: oralMed)
            modelContext.insert(newLog)
            lastCreatedLog = newLog
            
            customMedName = ""
            wasCleaned = false
            changedUndergarments = false
            notes = ""
            logDate = Date()
            selectedMedIndex = 2
            tookOralPill = false
            selectedOralMed = "Itraconazole"
            
            showUpdatePrompt = true
        }
    }
}
