// Core/Protocols/NotificationService.swift
import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

public enum NotificationError: Error, LocalizedError {
    case permissionDenied
    case sendFailed
    case invalidPayload
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied"
        case .sendFailed:
            return "Failed to send notification"
        case .invalidPayload:
            return "Invalid notification payload"
        }
    }
}

public protocol NotificationServiceProtocol: AnyObject {
    /// Requests permission to send notifications
    func requestPermission() async throws -> Bool
    
    /// Checks if notification permission is granted
    func hasPermission() -> Bool
    
    /// Sends a notification with title and body
    func send(title: String, body: String) async throws
    
    /// Sends a notification with custom payload
    func sendNotification(title: String, body: String, userInfo: [AnyHashable: Any]) async throws
    
    /// Removes all pending notifications
    func clearAll() async throws
    
    /// Removes specific notification by identifier
    func removeNotification(identifier: String) async throws
}
