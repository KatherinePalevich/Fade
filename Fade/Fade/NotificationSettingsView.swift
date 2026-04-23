import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var selectedTime: Date = Date()
    @State private var customMessage: String = ""
    
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
                    if !notificationManager.pendingReminders.isEmpty {
                        Section(header: Text("Current Reminders")) {
                            List {
                                ForEach(notificationManager.pendingReminders) { reminder in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(reminder.time, style: .time)
                                                .font(.headline)
                                            Text(reminder.message)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Button(role: .destructive) {
                                            notificationManager.cancelReminder(id: reminder.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                    } else {
                        Section(header: Text("Current Reminders")) {
                            Text("No active reminders.")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section(header: Text("Add New Reminder")) {
                        DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        
                        TextField("Message (optional)", text: $customMessage)
                        
                        Button("Add Reminder") {
                            notificationManager.scheduleDailyReminder(time: selectedTime, message: customMessage)
                            selectedTime = Date()
                            customMessage = ""
                        }
                        .buttonStyle(.borderless)
                        .disabled(notificationManager.isAuthorized == false)
                    }
                } else {
                    Section {
                        Text("Please enable notifications to set a daily reminder.")
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
                notificationManager.fetchPendingRequests()
            }
        }
    }
}
