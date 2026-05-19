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
    var id: UUID
    var type: NotificationType
    var startDate: Date
    var frequency: NotificationFrequency
    var customDays: Int
    var message: String
    
    enum CodingKeys: String, CodingKey {
        case id, type, startDate, frequency, customDays, message
    }
    
    init(id: UUID = UUID(), type: NotificationType, startDate: Date, frequency: NotificationFrequency, customDays: Int, message: String) {
        self.id = id
        self.type = type
        self.startDate = startDate
        self.frequency = frequency
        self.customDays = customDays
        self.message = message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.type = try container.decode(NotificationType.self, forKey: .type)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.frequency = try container.decode(NotificationFrequency.self, forKey: .frequency)
        self.customDays = try container.decode(Int.self, forKey: .customDays)
        self.message = try container.decode(String.self, forKey: .message)
    }
}

@MainActor
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized: Bool = false
    @Published var activeSettings: [ReminderSettings] = []
    @Published var selectedTabFromNotification: Int? = nil
    
    private let settingsKey = "FadeReminderSettings"
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        loadSettings()
        checkAuthorizationStatus()
    }
    
    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else { return }
        do {
            self.activeSettings = try JSONDecoder().decode([ReminderSettings].self, from: data)
        } catch {
            if let decodedDict = try? JSONDecoder().decode([String: ReminderSettings].self, from: data) {
                self.activeSettings = Array(decodedDict.values)
                saveSettings()
            } else if let decodedDict = try? JSONDecoder().decode([NotificationType: ReminderSettings].self, from: data) {
                self.activeSettings = Array(decodedDict.values)
                saveSettings()
            }
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
        cancelReminder(id: settings.id, type: settings.type)
        
        if let index = activeSettings.firstIndex(where: { $0.id == settings.id }) {
            activeSettings[index] = settings
        } else {
            activeSettings.append(settings)
        }
        saveSettings()
        
        let content = UNMutableNotificationContent()
        content.title = "Fade Reminder"
        let msg = settings.message.trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = msg.isEmpty ? settings.type.defaultMessage : msg
        content.sound = .default
        
        let calendar = Calendar.current
        let baseId = "\(settings.type.rawValue)-\(settings.id.uuidString)"
        
        if settings.frequency == .custom {
            let limit = min(max(1, settings.customDays), 365)
            // Schedule up to 60 occurrences
            for i in 0..<60 {
                if let triggerDate = calendar.date(byAdding: .day, value: i * limit, to: settings.startDate) {
                    if triggerDate > Date() {
                        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                        let req = UNNotificationRequest(identifier: "\(baseId)_\(i)", content: content, trigger: trigger)
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
            let req = UNNotificationRequest(identifier: baseId, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(req)
        }
    }
    
    func cancelReminder(id: UUID, type: NotificationType) {
        let baseId = "\(type.rawValue)-\(id.uuidString)"
        var ids = [baseId, type.rawValue]
        for i in 0..<60 {
            ids.append("\(baseId)_\(i)")
            ids.append("\(type.rawValue)_\(i)") // Cancel old legacy format as well
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        
        activeSettings.removeAll { $0.id == id }
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
