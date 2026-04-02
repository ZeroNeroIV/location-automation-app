// Core/Protocols/LocationService.swift
import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif

#if canImport(CoreLocation)
public typealias LocationType = CLLocation
#else
public struct LocationType {
    public let coordinate: (latitude: Double, longitude: Double)
    public let timestamp: Date
    public init(latitude: Double, longitude: Double, timestamp: Date = Date()) {
        self.coordinate = (latitude, longitude)
        self.timestamp = timestamp
    }
}
#endif

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
    var detectionMethod: DetectionMethod { get }
    
    func getCurrentLocation() async throws -> LocationType
    
    func startMonitoring(zone: Zone) async throws
    func stopMonitoring(zone: Zone) async throws
    func requestPermission() async throws -> Bool
    func isAuthorized() -> Bool
}

public extension LocationServiceProtocol {
    var detectionMethod: DetectionMethod {
        .gps
    }
    
    func isAuthorized() -> Bool { false }

    var effectiveDetectionMethod: DetectionMethod { detectionMethod }

    func checkLocationAccuracy(_ location: LocationType) -> Bool { true }

    func isGpsReliable() -> Bool { true }

    func getFallbackMethod() -> DetectionMethod { .wifi }

    func resetGpsReliability() {}
}
