import Foundation
import UserNotifications
import SwiftUI
import Combine

enum NotificationType: String, CaseIterable, Identifiable, Codable {
    case daily = "daily_treatment_reminder"
    case prescription = "prescription_pickup_reminder"
    case photo = "rash_photo_reminder"
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .daily: return "Daily Treatment"
        case .prescription: return "Prescription Pickup"
        case .photo: return "Rash Photo Update"
        }
    }
    
    var defaultMessage: String {
        switch self {
        case .daily: return "Time to log your Fade treatments!"
        case .prescription: return "Your prescription is ready for pickup."
        case .photo: return "Time to upload a new photo for your rash sites."
        }
    }
}

enum NotificationFrequency: String, CaseIterable, Identifiable, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case custom = "Custom"
    var id: String { rawValue }
}

struct ReminderSettings: Codable, Equatable, Identifiable {
    var id: String { type.rawValue }
    var type: NotificationType
    var startDate: Date
    var frequency: NotificationFrequency
    var customDays: Int
    var message: String
}

@MainActor
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized: Bool = false
    @Published var activeSettings: [NotificationType: ReminderSettings] = [:]
    @Published var selectedTabFromNotification: Int? = nil
    
    private let settingsKey = "FadeReminderSettings"
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        loadSettings()
        checkAuthorizationStatus()
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode([NotificationType: ReminderSettings].self, from: data) {
            self.activeSettings = decoded
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(activeSettings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func scheduleReminder(settings: ReminderSettings) {
        cancelReminder(type: settings.type)
        
        activeSettings[settings.type] = settings
        saveSettings()
        
        let content = UNMutableNotificationContent()
        content.title = "Fade Reminder"
        let msg = settings.message.trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = msg.isEmpty ? settings.type.defaultMessage : msg
        content.sound = .default
        
        let calendar = Calendar.current
        
        if settings.frequency == .custom {
            let limit = min(max(1, settings.customDays), 365)
            // Schedule up to 60 occurrences
            for i in 0..<60 {
                if let triggerDate = calendar.date(byAdding: .day, value: i * limit, to: settings.startDate) {
                    if triggerDate > Date() {
                        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                        let req = UNNotificationRequest(identifier: "\(settings.type.rawValue)_\(i)", content: content, trigger: trigger)
                        UNUserNotificationCenter.current().add(req)
                    }
                }
            }
        } else {
            var comps = calendar.dateComponents([.hour, .minute], from: settings.startDate)
            if settings.frequency == .weekly {
                comps = calendar.dateComponents([.weekday, .hour, .minute], from: settings.startDate)
            } else if settings.frequency == .monthly {
                comps = calendar.dateComponents([.day, .hour, .minute], from: settings.startDate)
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let req = UNNotificationRequest(identifier: settings.type.rawValue, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(req)
        }
    }
    
    func cancelReminder(type: NotificationType) {
        var ids = [type.rawValue]
        for i in 0..<60 {
            ids.append("\(type.rawValue)_\(i)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        
        activeSettings.removeValue(forKey: type)
        saveSettings()
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        DispatchQueue.main.async {
            if identifier.hasPrefix(NotificationType.daily.rawValue) {
                self.selectedTabFromNotification = 1 // Summary tab?
            } else if identifier.hasPrefix(NotificationType.photo.rawValue) {
                self.selectedTabFromNotification = 0 // Body map tab?
            } else if identifier.hasPrefix(NotificationType.prescription.rawValue) {
                self.selectedTabFromNotification = 1 // Summary tab?
            }
        }
        completionHandler()
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
