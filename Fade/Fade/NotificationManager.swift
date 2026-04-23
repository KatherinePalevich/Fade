import Foundation
import UserNotifications
import SwiftUI
import Combine
import Combine

struct ScheduledReminder: Identifiable {
    let id: String
    let time: Date
    let message: String
}

@MainActor
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized: Bool = false
    @Published var pendingReminders: [ScheduledReminder] = []
    @Published var selectedTabFromNotification: Int? = nil
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
        fetchPendingRequests()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    self.fetchPendingRequests()
                }
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
    
    func fetchPendingRequests() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let reminderRequests = requests.filter { $0.identifier.hasPrefix("daily_treatment_reminder") }
            var newReminders: [ScheduledReminder] = []
            
            for request in reminderRequests {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    let hour = trigger.dateComponents.hour ?? 0
                    let minute = trigger.dateComponents.minute ?? 0
                    var comps = DateComponents()
                    comps.hour = hour
                    comps.minute = minute
                    if let date = Calendar.current.date(from: comps) {
                        newReminders.append(ScheduledReminder(id: request.identifier, time: date, message: request.content.body))
                    }
                }
            }
            
            newReminders.sort { $0.time < $1.time }
            
            DispatchQueue.main.async {
                self.pendingReminders = newReminders
            }
        }
    }
    
    func scheduleDailyReminder(time: Date, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Fade Reminder"
        content.body = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Time to log your Fade treatments!" : message
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let uniqueID = "daily_treatment_reminder_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: uniqueID, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                self.fetchPendingRequests()
            }
        }
    }
    
    func cancelReminder(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        self.fetchPendingRequests()
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier.hasPrefix("daily_treatment_reminder") {
            DispatchQueue.main.async {
                self.selectedTabFromNotification = 1
            }
        }
        completionHandler()
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
