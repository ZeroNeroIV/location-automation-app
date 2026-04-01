// iOS/Location/ZoneMonitor.swift
import Foundation
import CoreLocation
import UIKit

/// iOS Zone Monitoring Service
/// Handles significant location changes, region monitoring, and background fetch
public final class ZoneMonitor: NSObject {
    
    // MARK: - Singleton
    
    public static let shared = ZoneMonitor()
    
    // MARK: - Properties
    
    private let locationManager: CLLocationManager
    private var monitoredRegions: [UUID: CLCircularRegion] = [:]
    private var zoneEntryCallbacks: [UUID: (Zone) -> Void] = [:]
    private var zoneExitCallbacks: [UUID: (Zone) -> Void] = [:]
    
    /// iOS 20 region limit
    private let maxMonitoredRegions = 20
    
    // MARK: - Initialization
    
    private override init() {
        self.locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    // MARK: - Public Interface
    
    /// Start significant location change monitoring
    public func startSignificantLocationChanges() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            Logger.shared.log("Significant location changes not available", level: .error)
            return
        }
        
        locationManager.startMonitoringSignificantLocationChanges()
        Logger.shared.log("Started significant location changes monitoring", level: .info)
    }
    
    /// Stop significant location change monitoring
    public func stopSignificantLocationChanges() {
        locationManager.stopMonitoringSignificantLocationChanges()
        Logger.shared.log("Stopped significant location changes monitoring", level: .info)
    }
    
    /// Add a region to monitor
    /// - Parameters:
    ///   - zone: The zone to monitor
    ///   - onEnter: Callback when entering the zone
    ///   - onExit: Callback when exiting the zone
    public func addRegion(
        for zone: Zone,
        onEnter: @escaping (Zone) -> Void,
        onExit: @escaping (Zone) -> Void
    ) throws {
        // Enforce iOS 20 region limit
        guard monitoredRegions.count < maxMonitoredRegions else {
            Logger.shared.log("Cannot add region - iOS 20 region limit reached", level: .error)
            throw ZoneMonitorError.regionLimitReached
        }
        
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            throw ZoneMonitorError.monitoringNotAvailable
        }
        
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: zone.latitude,
                longitude: zone.longitude
            ),
            radius: min(zone.radius, locationManager.maximumRegionMonitoringDistance),
            identifier: zone.id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        monitoredRegions[zone.id] = region
        zoneEntryCallbacks[zone.id] = onEnter
        zoneExitCallbacks[zone.id] = onExit
        
        locationManager.startMonitoring(for: region)
        
        Logger.shared.log("Started monitoring region: \(zone.name)", level: .info)
    }
    
    /// Remove a region from monitoring
    /// - Parameter zone: The zone to stop monitoring
    public func removeRegion(for zone: Zone) {
        guard let region = monitoredRegions[zone.id] else {
            Logger.shared.log("Region not found: \(zone.name)", level: .warning)
            return
        }
        
        locationManager.stopMonitoring(for: region)
        monitoredRegions.removeValue(forKey: zone.id)
        zoneEntryCallbacks.removeValue(forKey: zone.id)
        zoneExitCallbacks.removeValue(forKey: zone.id)
        
        Logger.shared.log("Stopped monitoring region: \(zone.name)", level: .info)
    }
    
    /// Remove all monitored regions
    public func removeAllRegions() {
        for region in monitoredRegions.values {
            locationManager.stopMonitoring(for: region)
        }
        
        monitoredRegions.removeAll()
        zoneEntryCallbacks.removeAll()
        zoneExitCallbacks.removeAll()
        
        Logger.shared.log("Removed all monitored regions", level: .info)
    }
    
    /// Get the current number of monitored regions
    public var monitoredRegionCount: Int {
        monitoredRegions.count
    }
    
    /// Check if at region limit
    public var isAtRegionLimit: Bool {
        monitoredRegions.count >= maxMonitoredRegions
    }
    
    // MARK: - Background Fetch
    
    /// Enable background fetch
    public func enableBackgroundFetch() {
        UIApplication.shared.setMinimumBackgroundFetchInterval(
            UIApplication.backgroundFetchIntervalMinimum
        )
        Logger.shared.log("Background fetch enabled", level: .info)
    }
    
    /// Disable background fetch
    public func disableBackgroundFetch() {
        UIApplication.shared.setMinimumBackgroundFetchInterval(
            UIApplication.backgroundFetchIntervalNever
        )
        Logger.shared.log("Background fetch disabled", level: .info)
    }
    
    /// Check if background fetch is available
    public var isBackgroundFetchAvailable: Bool {
        true
    }
    
    // MARK: - Authorization
    
    /// Request always authorization (required for background location)
    public func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    /// Check current authorization status
    public var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }
    
    /// Check if always authorization is granted
    public var isAlwaysAuthorized: Bool {
        authorizationStatus == .authorizedAlways
    }
    
    /// Check if monitoring is available
    public var isMonitoringAvailable: Bool {
        CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
    }
}

// MARK: - CLLocationManagerDelegate

extension ZoneMonitor: CLLocationManagerDelegate {
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Logger.shared.log(
            "Significant location change: \(location.coordinate.latitude), \(location.coordinate.longitude)",
            level: .debug
        )
        
        // Post notification for significant location change
        NotificationCenter.default.post(
            name: .significantLocationChanged,
            object: nil,
            userInfo: ["location": location]
        )
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger.shared.log("Location manager error: \(error.localizedDescription)", level: .error)
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        switch status {
        case .authorizedAlways:
            Logger.shared.log("Location always authorization granted", level: .info)
            NotificationCenter.default.post(name: .locationAuthorizationChanged, object: nil)
        case .authorizedWhenInUse:
            Logger.shared.log("Location when-in-use authorization granted", level: .info)
        case .denied, .restricted:
            Logger.shared.log("Location authorization denied/restricted", level: .warning)
            NotificationCenter.default.post(name: .locationAuthorizationChanged, object: nil)
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion,
              let zoneId = UUID(uuidString: region.identifier),
              let callback = zoneEntryCallbacks[zoneId] else {
            return
        }
        
        // Create temporary zone for callback
        let zone = Zone(
            id: zoneId,
            name: region.identifier,
            latitude: region.center.latitude,
            longitude: region.center.longitude,
            radius: circularRegion.radius,
            detectionMethods: [],
            profileId: UUID()
        )
        
        Logger.shared.log("Entered region: \(region.identifier)", level: .info)
        
        // Post notification
        NotificationCenter.default.post(
            name: .zoneEntered,
            object: nil,
            userInfo: ["zoneId": zoneId, "identifier": region.identifier]
        )
        
        // Execute callback
        callback(zone)
    }
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion,
              let zoneId = UUID(uuidString: region.identifier),
              let callback = zoneExitCallbacks[zoneId] else {
            return
        }
        
        // Create temporary zone for callback
        let zone = Zone(
            id: zoneId,
            name: region.identifier,
            latitude: region.center.latitude,
            longitude: region.center.longitude,
            radius: circularRegion.radius,
            detectionMethods: [],
            profileId: UUID()
        )
        
        Logger.shared.log("Exited region: \(region.identifier)", level: .info)
        
        // Post notification
        NotificationCenter.default.post(
            name: .zoneExited,
            object: nil,
            userInfo: ["zoneId": zoneId, "identifier": region.identifier]
        )
        
        // Execute callback
        callback(zone)
    }
    
    public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        guard let region = region else { return }
        
        Logger.shared.log(
            "Region monitoring failed for \(region.identifier): \(error.localizedDescription)",
            level: .error
        )
        
        // Clean up failed region
        if let zoneId = UUID(uuidString: region.identifier) {
            monitoredRegions.removeValue(forKey: zoneId)
            zoneEntryCallbacks.removeValue(forKey: zoneId)
            zoneExitCallbacks.removeValue(forKey: zoneId)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        Logger.shared.log("Started monitoring for region: \(region.identifier)", level: .debug)
    }
}

// MARK: - Error Types

public enum ZoneMonitorError: Error, LocalizedError {
    case regionLimitReached
    case monitoringNotAvailable
    case regionNotFound
    case authorizationDenied
    
    public var errorDescription: String? {
        switch self {
        case .regionLimitReached:
            return "iOS 20 region limit has been reached"
        case .monitoringNotAvailable:
            return "Region monitoring is not available on this device"
        case .regionNotFound:
            return "Region not found"
        case .authorizationDenied:
            return "Location authorization denied"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when significant location changes
    static let significantLocationChanged = Notification.Name("significantLocationChanged")
    
    /// Posted when entering a monitored zone
    static let zoneEntered = Notification.Name("zoneEntered")
    
    /// Posted when exiting a monitored zone
    static let zoneExited = Notification.Name("zoneExited")
    
    /// Posted when location authorization changes
    static let locationAuthorizationChanged = Notification.Name("locationAuthorizationChanged")
}
