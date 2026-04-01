// Core/Protocols/LocationService.swift
import Foundation
import CoreLocation

public enum LocationError: Error, LocalizedError {
    case locationUnavailable
    case permissionDenied
    case timeout
    case zoneNotFound
    case gpsUnreliable
    
    public var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Location services are unavailable"
        case .permissionDenied:
            return "Location permission was denied"
        case .timeout:
            return "Location request timed out"
        case .zoneNotFound:
            return "Zone not found"
        case .gpsUnreliable:
            return "GPS signal unreliable, using fallback detection"
        }
    }
}

public protocol LocationServiceProtocol: AnyObject {
    /// The primary detection method used by the service
    var detectionMethod: DetectionMethod { get }
    
    /// Gets the current device location
    func getCurrentLocation() async throws -> CLLocation
    
    /// Starts monitoring a specific zone
    func startMonitoring(zone: Zone) async throws
    
    /// Stops monitoring a specific zone
    func stopMonitoring(zone: Zone) async throws
    
    /// Requests location permission from the user
    func requestPermission() async throws -> Bool
    
    /// Checks if location services are authorized
    func isAuthorized() -> Bool
}

public extension LocationServiceProtocol {
    var detectionMethod: DetectionMethod {
        .gps
    }
    
    func isAuthorized() -> Bool {
        false
    }

    var effectiveDetectionMethod: DetectionMethod {
        detectionMethod
    }

    func checkLocationAccuracy(_ location: CLLocation) -> Bool {
        true
    }

    func isGpsReliable() -> Bool {
        true
    }

    func getFallbackMethod() -> DetectionMethod {
        .wifi
    }

    func resetGpsReliability() {}
}
