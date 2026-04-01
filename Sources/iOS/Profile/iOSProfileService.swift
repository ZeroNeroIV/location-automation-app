// iOS/Profile/iOSProfileService.swift
import Foundation
import AVFoundation
import AudioToolbox
import UserNotifications

public final class iOSProfileService: ProfileServiceProtocol {
    
    // MARK: - Properties
    
    private let audioSession = AVAudioSession.sharedInstance()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // MARK: - Initialization
    
    public init() {
        setupNotifications()
    }
    
    // MARK: - ProfileServiceProtocol
    
    public func apply(profile: Profile) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                // Apply ringtone setting
                try applyRingtone(profile.ringtone)
                
                // Apply vibrate setting
                applyVibrate(profile.vibrate)
                
                // Apply unmute setting
                try applyUnmute(profile.unmute)
                
                // Apply DND setting (iOS 15+ Focus API)
                try await applyDND(profile.dnd)
                
                // Apply alarms setting
                try applyAlarms(profile.alarms)
                
                // Apply timers setting
                try applyTimers(profile.timers)
                
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    public func getCurrentProfile() async throws -> Profile {
        // Get current audio session state for ringtone/unmute
        let currentRoute = audioSession.currentRoute
        let isMuted = audioSession.isMuted
        let category = audioSession.category
        
        // Get notification settings for DND, alarms, timers
        let settings = try await notificationCenter.notificationSettings()
        
        return Profile(
            name: "Current",
            ringtone: .on,  // AVAudioSession doesn't expose exact ringer state
            vibrate: .on,   // Can't detect vibrate state
            unmute: isMuted ? ProfileSetting.off : ProfileSetting.on,
            dnd: settings.authorizationStatus == .authorized ? .on : .off,
            alarms: settings.alertSetting == .enabled ? ProfileSetting.on : .off,
            timers: settings.badgeSetting == .enabled ? ProfileSetting.on : .off
        )
    }
    
    public func resetToDefault() async throws {
        // Reset to default iOS settings
        try audioSession.setCategory(.default, mode: .default)
        try audioSession.setActive(true)
        
        // Request notification settings to open permission dialog if needed
        _ = try await notificationCenter.notificationSettings()
    }
    
    public func getAllProfiles() async throws -> [Profile] {
        // Load profiles from storage (placeholder - would integrate with DatabaseManager)
        return []
    }
    
    public func save(profile: Profile) async throws {
        // Save profile to storage (placeholder - would integrate with DatabaseManager)
    }
    
    // MARK: - Ringtone (AVAudioSession)
    
    private func applyRingtone(_ setting: ProfileSetting) throws {
        switch setting {
        case .on:
            // Set to playback mode which allows audio
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        case .off:
            // Set to silent mode - but iOS doesn't allow apps to silence ringer
            // We can only set the audio session to not interfere
            try audioSession.setCategory(.ambient, mode: .default)
            try audioSession.setActive(true)
        case .automatic:
            // Reset to default
            try audioSession.setCategory(.default, mode: .default)
            try audioSession.setActive(true)
        }
    }
    
    // MARK: - Vibrate (AudioServices)
    
    private func applyVibrate(_ setting: ProfileSetting) {
        switch setting {
        case .on:
            // Enable haptic feedback - but actual vibrate setting is system-level
            // We can use AudioServicesPlaySystemSound for haptic feedback
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        case .off, .automatic:
            // Cannot programmatically disable device vibrate
            // This is a system-level setting
            break
        }
    }
    
    // MARK: - Unmute (AVAudioSession)
    
    private func applyUnmute(_ setting: ProfileSetting) throws {
        switch setting {
        case .on:
            try audioSession.setMuted(false)
        case .off:
            try audioSession.setMuted(true)
        case .automatic:
            // Reset to system default
            try audioSession.setMuted(false)
        }
    }
    
    // MARK: - DND (Focus API - iOS 15+)
    
    private func applyDND(_ setting: ProfileSetting) async throws {
        // Note: iOS does NOT provide a public API to programmatically enable/disable DND
        // Focus modes can only be controlled through the Settings app or Shortcuts
        // This implementation checks notification authorization as a proxy
        
        switch setting {
        case .on:
            // Request notification authorization (prerequisite for Focus)
            let settings = try await notificationCenter.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                let granted = try await requestNotificationPermission()
                if !granted {
                    throw ProfileError.invalidProfile
                }
            }
        case .off, .automatic:
            // Cannot disable DND programmatically
            break
        }
    }
    
    // MARK: - Alarms
    
    private func applyAlarms(_ setting: ProfileSetting) throws {
        // iOS does NOT provide public API to modify system alarm settings
        // Alarms are managed through Clock app
        // We can only request notification permissions which are used for some alarms
        
        switch setting {
        case .on:
            // Ensure we have notification permissions
            Task {
                _ = try? await notificationCenter.notificationSettings()
            }
        case .off, .automatic:
            // Cannot modify system alarm settings
            break
        }
    }
    
    // MARK: - Timers
    
    private func applyTimers(_ setting: ProfileSetting) throws {
        // iOS does NOT provide public API to modify system timer settings
        // Timers are managed through Clock app (Timer tab)
        
        switch setting {
        case .on:
            // Ensure we have notification permissions for timer alerts
            Task {
                _ = try? await notificationCenter.notificationSettings()
            }
        case .off, .automatic:
            // Cannot modify system timer settings
            break
        }
    }
    
    // MARK: - Private Helpers
    
    private func setupNotifications() {
        notificationCenter.delegate = nil // Could set delegate for more control
    }
    
    private func requestNotificationPermission() async throws -> Bool {
        let settings = try await notificationCenter.notificationSettings()
        
        if settings.authorizationStatus == .notDetermined {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        }
        
        return settings.authorizationStatus == .authorized
    }
}

// MARK: - Custom Errors

extension iOSProfileService {
    public enum iOSProfileError: Error, LocalizedError {
        case audioSessionFailed
        case notificationPermissionDenied
        case focusNotAvailable
        
        public var errorDescription: String? {
            switch self {
            case .audioSessionFailed:
                return "Failed to configure audio session"
            case .notificationPermissionDenied:
                return "Notification permission denied"
            case .focusNotAvailable:
                return "Focus/DND API not available on this iOS version"
            }
        }
    }
}