import SwiftUI
import SwiftData

struct TreatmentFormView: View {
    @Environment(\.modelContext) private var modelContext
    
    let standardMeds = ["Terbinafine 1%", "Clotrimazole 1%", "Ketoconazole 2%", "Custom"]
    
    @State private var selectedMedIndex = 0
    @State private var customMedName = ""
    @State private var wasCleaned = false
    @State private var notes = ""
    @State private var logDate = Date()
    @State private var showUpdatePrompt = false
    @State private var lastCreatedLog: TreatmentLog?
    
    @Binding var selectedTab: Int
    @Binding var activeTreatmentContext: TreatmentLog?
    @Binding var isEditMode: Bool
    
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
                    TextField("Notes (optional)", text: $notes)
                }
                
                Button("Log Treatment") {
                    saveTreatment()
                }
                .disabled(standardMeds[selectedMedIndex] == "Custom" && customMedName.isEmpty)
            }
            .navigationTitle("Log Treatment")
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
        let newLog = TreatmentLog(timestamp: logDate, medicationName: medName, wasCleaned: wasCleaned, notes: notes)
        modelContext.insert(newLog)
        lastCreatedLog = newLog
        
        customMedName = ""
        wasCleaned = false
        notes = ""
        logDate = Date()
        
        showUpdatePrompt = true
    }
}
