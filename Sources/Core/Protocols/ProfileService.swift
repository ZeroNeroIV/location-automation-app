// Core/Protocols/ProfileService.swift
import Foundation

public enum ProfileError: Error, LocalizedError {
    case profileNotFound
    case invalidProfile
    case saveFailed
    case resetFailed
    
    public var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "Profile not found"
        case .invalidProfile:
            return "Invalid profile data"
        case .saveFailed:
            return "Failed to save profile"
        case .resetFailed:
            return "Failed to reset to default profile"
        }
    }
}

public protocol ProfileServiceProtocol: AnyObject {
    /// Applies a profile's settings to the device
    func apply(profile: Profile) async throws
    
    /// Gets the currently active profile
    func getCurrentProfile() async throws -> Profile
    
    /// Resets all device settings to the default profile
    func resetToDefault() async throws
    
    /// Gets all available profiles
    func getAllProfiles() async throws -> [Profile]
    
    /// Saves a profile for future use
    func save(profile: Profile) async throws
}
