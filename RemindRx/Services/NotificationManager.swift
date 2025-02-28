import Foundation
import CoreData
import UserNotifications


class NotificationManager {
    static let shared = NotificationManager()
    
    func scheduleNotification(for medicine: Medicine) {
        let content = UNMutableNotificationContent()
        content.title = "Medicine Expiring Soon"
        content.body = "\(medicine.name) will expire on \(formatDate(medicine.expirationDate))"
        content.sound = UNNotificationSound.default
        
        // Calculate notification date based on alert preference
        let notificationDate = medicine.expirationDate.addingTimeInterval(-Double(medicine.alertInterval.days * 24 * 60 * 60))
        
        // Only schedule if notification date is in the future
        if notificationDate > Date() {
            let components = Calendar.current.dateComponents([.year, .month, .day], from: notificationDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "expiration-\(medicine.id.uuidString)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func removeNotifications(for medicine: Medicine) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["expiration-\(medicine.id.uuidString)"])
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
