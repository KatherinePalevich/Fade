import SwiftUI
import Combine
import SwiftData

class MedicationFrequencySettings: ObservableObject {
    static let shared = MedicationFrequencySettings()
    
    @Published var frequencies: [String: Int] = [:] {
        didSet {
            if let encoded = try? JSONEncoder().encode(frequencies) {
                UserDefaults.standard.set(encoded, forKey: "MedicationFrequencies")
            }
        }
    }
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "MedicationFrequencies"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            frequencies = decoded
        }
    }
}

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var medicationSettings = MedicationFrequencySettings.shared
    
    @Query private var treatments: [TreatmentLog]
    
    var availableMedications: [String] {
        let standard = ["Terbinafine 1%", "Clotrimazole 1%", "Ketoconazole 2%", "Terbinafine", "Itraconazole"]
        let loggedCreams = treatments.map { $0.medicationName }
        let loggedOrals = treatments.compactMap { $0.oralMedicationName }
        let all = Set(standard + loggedCreams + loggedOrals)
        return Array(all).sorted()
    }
    
    @State private var newMedicationName = ""
    @State private var newMedicationFrequency = 1
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Permission Status")) {
                    HStack {
                        Text("Notifications Enabled")
                        Spacer()
                        Image(systemName: notificationManager.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                    }
                    if !notificationManager.isAuthorized {
                        Button("Request Permission") {
                            notificationManager.requestAuthorization()
                        }
                    }
                }
                
                Section(header: Text("Medication Daily Frequencies")) {
                    ForEach(medicationSettings.frequencies.keys.sorted(), id: \.self) { key in
                        HStack {
                            Text(key)
                            Spacer()
                            Text("\(medicationSettings.frequencies[key]!) times/day")
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        let keys = medicationSettings.frequencies.keys.sorted()
                        for index in indexSet {
                            medicationSettings.frequencies.removeValue(forKey: keys[index])
                        }
                    }
                    
                    HStack {
                        Picker("Medication", selection: $newMedicationName) {
                            Text("Select Medication").tag("")
                            ForEach(availableMedications, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        
                        Stepper("\(newMedicationFrequency) / day", value: $newMedicationFrequency, in: 1...5)
                        Button(action: {
                            if !newMedicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                medicationSettings.frequencies[newMedicationName] = newMedicationFrequency
                                newMedicationName = ""
                                newMedicationFrequency = 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newMedicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
                if notificationManager.isAuthorized {
                    ForEach(NotificationType.allCases) { type in
                        let typeReminders = notificationManager.activeSettings.filter { $0.type == type }
                        
                        if typeReminders.isEmpty {
                            EmptyReminderSettingsSection(notificationManager: notificationManager, type: type)
                        } else {
                            ForEach(typeReminders) { reminder in
                                ReminderSettingsSection(notificationManager: notificationManager, reminderId: reminder.id)
                            }
                            Section {
                                Button("Add Another \(type.displayName)") {
                                    let newReminder = ReminderSettings(id: UUID(), type: type, startDate: Date(), frequency: type == .daily ? .daily : .weekly, customDays: 1, message: type.defaultMessage)
                                    notificationManager.scheduleReminder(settings: newReminder)
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        Text("Please enable notifications to set reminders.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                notificationManager.checkAuthorizationStatus()
            }
        }
    }
}

struct EmptyReminderSettingsSection: View {
    @ObservedObject var notificationManager: NotificationManager
    let type: NotificationType

    @State private var isEnabled = false

    var body: some View {
        Section(header: Text(type.displayName)) {
            Toggle("Enable Reminder", isOn: $isEnabled)
                .onChange(of: isEnabled) { newValue in
                    if newValue {
                        let newReminder = ReminderSettings(id: UUID(), type: type, startDate: Date(), frequency: type == .daily ? .daily : .weekly, customDays: 1, message: type.defaultMessage)
                        notificationManager.scheduleReminder(settings: newReminder)
                        isEnabled = false // reset for next time it might appear
                    }
                }
        }
    }
}

struct ReminderSettingsSection: View {
    @ObservedObject var notificationManager: NotificationManager
    let reminderId: UUID
    
    @State private var startDate: Date = Date()
    @State private var frequency: NotificationFrequency = .daily
    @State private var customDays: String = "1"
    @State private var message: String = ""
    
    var reminder: ReminderSettings? {
        notificationManager.activeSettings.first(where: { $0.id == reminderId })
    }
    
    var hasChanges: Bool {
        guard let rem = reminder else { return false }
        let currentDays = max(1, Int(customDays) ?? 1)
        let currentMessage = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? rem.type.defaultMessage : message
        
        return rem.startDate != startDate ||
               rem.frequency != frequency ||
               rem.customDays != currentDays ||
               rem.message != currentMessage
    }
    
    var body: some View {
        if let rem = reminder {
            Section(header: Text(rem.type.displayName)) {
                DatePicker("Start Date & Time", selection: $startDate)
                
                Picker("Frequency", selection: $frequency) {
                    ForEach(NotificationFrequency.allCases) { freq in
                        Text(freq.rawValue).tag(freq)
                    }
                }
                
                if frequency == .custom {
                    HStack {
                        Text("Every (days)")
                        Spacer()
                        TextField("Days", text: $customDays)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Message")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField(rem.type.defaultMessage, text: $message)
                }
                
                HStack {
                    Button("Save Changes") {
                        save()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(hasChanges ? .blue : .secondary)
                    .disabled(!hasChanges)
                    
                    Spacer()
                    
                    Button("Delete") {
                        notificationManager.cancelReminder(id: rem.id, type: rem.type)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
            }
            .onAppear {
                startDate = rem.startDate
                frequency = rem.frequency
                customDays = String(rem.customDays)
                message = rem.message
            }
        }
    }
    
    private func save() {
        guard let rem = reminder else { return }
        let days = max(1, Int(customDays) ?? 1)
        var updated = rem
        updated.startDate = startDate
        updated.frequency = frequency
        updated.customDays = days
        updated.message = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? rem.type.defaultMessage : message
        
        notificationManager.scheduleReminder(settings: updated)
        
        customDays = String(days)
        message = updated.message
    }
}
