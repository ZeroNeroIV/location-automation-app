// iOS/Location/iOSNotificationService.swift
import Foundation
import UserNotifications

/// iOS implementation of NotificationServiceProtocol
public final class iOSNotificationService: NSObject, NotificationServiceProtocol {
    
    // MARK: - Singleton
    
    public static let shared = iOSNotificationService()
    
    // MARK: - Properties
    
    private let notificationCenter: UNUserNotificationCenter
    private var permissionContinuation: CheckedContinuation<Bool, Error>?
    
    // MARK: - Initialization
    
    private override init() {
        self.notificationCenter = UNUserNotificationCenter.current()
        super.init()
        notificationCenter.delegate = self
    }
    
    // MARK: - NotificationServiceProtocol
    
    public func requestPermission() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            self.permissionContinuation = continuation
            notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    public func hasPermission() -> Bool {
        var granted = false
        let semaphore = DispatchSemaphore(value: 0)
        
        notificationCenter.getNotificationSettings { settings in
            granted = settings.authorizationStatus == .authorized
            semaphore.signal()
        }
        
        semaphore.wait()
        return granted
    }
    
    public func send(title: String, body: String) async throws {
        try await sendNotification(title: title, body: body, userInfo: [:])
    }
    
    public func sendNotification(title: String, body: String, userInfo: [AnyHashable: Any]) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    public func clearAll() async throws {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    public func removeNotification(identifier: String) async throws {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension iOSNotificationService: UNUserNotificationCenterDelegate {
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        Logger.shared.info("Notification tapped: \(response.notification.request.identifier)")
        completionHandler()
    }
}
