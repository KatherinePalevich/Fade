import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    
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
                
                if notificationManager.isAuthorized {
                    ReminderSettingsSection(notificationManager: notificationManager, type: .daily)
                    ReminderSettingsSection(notificationManager: notificationManager, type: .prescription)
                    ReminderSettingsSection(notificationManager: notificationManager, type: .photo)
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

struct ReminderSettingsSection: View {
    @ObservedObject var notificationManager: NotificationManager
    let type: NotificationType
    
    @State private var isEnabled: Bool = false
    @State private var startDate: Date = Date()
    @State private var frequency: NotificationFrequency = .daily
    @State private var customDays: String = "1"
    @State private var message: String = ""
    
    var body: some View {
        Section(header: Text(type.displayName)) {
            Toggle("Enable Reminder", isOn: $isEnabled)
                .onChange(of: isEnabled) { newValue in
                    if !newValue {
                        notificationManager.cancelReminder(type: type)
                    } else if notificationManager.activeSettings[type] == nil {
                        save()
                    }
                }
            
            if isEnabled {
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
                    TextField(type.defaultMessage, text: $message)
                }
                
                Button("Save Changes") {
                    save()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
            }
        }
        .onAppear {
            if let active = notificationManager.activeSettings[type] {
                isEnabled = true
                startDate = active.startDate
                frequency = active.frequency
                customDays = String(active.customDays)
                message = active.message
            } else {
                isEnabled = false
                startDate = Date()
                frequency = type == .daily ? .daily : .weekly
                customDays = "1"
                message = type.defaultMessage
            }
        }
    }
    
    private func save() {
        let days = max(1, Int(customDays) ?? 1)
        let settings = ReminderSettings(
            type: type,
            startDate: startDate,
            frequency: frequency,
            customDays: days,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? type.defaultMessage : message
        )
        notificationManager.scheduleReminder(settings: settings)
        
        // Update local state to reflect exact saved values
        customDays = String(days)
        message = settings.message
    }
}
