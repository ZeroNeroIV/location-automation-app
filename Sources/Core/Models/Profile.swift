// Core/Models/Profile.swift
import Foundation

public enum ProfileSetting: String, Codable {
    case on = "on"
    case off = "off"
    case automatic = "automatic"
}

public struct Profile: Codable, Validatable {
    public let id: UUID
    public var name: String
    public var ringtone: ProfileSetting
    public var vibrate: ProfileSetting
    public var unmute: ProfileSetting
    public var dnd: ProfileSetting
    public var alarms: ProfileSetting
    public var timers: ProfileSetting
    
    public init(
        id: UUID = UUID(),
        name: String,
        ringtone: ProfileSetting = .off,
        vibrate: ProfileSetting = .off,
        unmute: ProfileSetting = .off,
        dnd: ProfileSetting = .off,
        alarms: ProfileSetting = .on,
        timers: ProfileSetting = .on
    ) {
        self.id = id
        self.name = name
        self.ringtone = ringtone
        self.vibrate = vibrate
        self.unmute = unmute
        self.dnd = dnd
        self.alarms = alarms
        self.timers = timers
    }
}

extension Profile {
    public func validate() throws {
        guard !name.isEmpty else {
            throw ProfileValidationError.invalidName
        }
    }
}

public enum ProfileValidationError: Error, LocalizedError {
    case invalidName
    
    public var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Profile name cannot be empty"
        }
    }
}