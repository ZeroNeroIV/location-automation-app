// Core/Models/Zone.swift
import Foundation

public enum DetectionMethod: String, Codable, CaseIterable, Sendable {
    case gps = "gps"
    case wifi = "wifi"
    case bluetooth = "bluetooth"
    case geofence = "geofence"
}

public enum ZoneValidationError: Error, LocalizedError {
    case invalidLatitude
    case invalidLongitude
    case invalidRadius
    
    public var errorDescription: String? {
        switch self {
        case .invalidLatitude:
            return "Latitude must be between -90 and 90"
        case .invalidLongitude:
            return "Longitude must be between -180 and 180"
        case .invalidRadius:
            return "Radius must be greater than 0"
        }
    }
}

public struct Zone: Codable, Validatable, Sendable {
    public let id: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var radius: Double
    public var detectionMethods: [DetectionMethod]
    public var profileId: UUID
    
    public init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        detectionMethods: [DetectionMethod] = [],
        profileId: UUID
    ) throws {
        guard latitude >= -90 && latitude <= 90 else {
            throw ZoneValidationError.invalidLatitude
        }
        guard longitude >= -180 && longitude <= 180 else {
            throw ZoneValidationError.invalidLongitude
        }
        guard radius > 0 else {
            throw ZoneValidationError.invalidRadius
        }
        
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.detectionMethods = detectionMethods
        self.profileId = profileId
    }
}

public protocol Validatable {
    func validate() throws
}

extension Zone {
    public func validate() throws {
        guard latitude >= -90 && latitude <= 90 else {
            throw ZoneValidationError.invalidLatitude
        }
        guard longitude >= -180 && longitude <= 180 else {
            throw ZoneValidationError.invalidLongitude
        }
        guard radius > 0 else {
            throw ZoneValidationError.invalidRadius
        }
    }
}