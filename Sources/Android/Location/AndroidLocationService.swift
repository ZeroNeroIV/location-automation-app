import Foundation
import CoreLocation

public final class AndroidLocationService: LocationServiceProtocol {
    
    public var detectionMethod: DetectionMethod { .geofence }
    
    private var fusedLocationClient: AndroidFusedLocationProviderClient?
    private var locationCallback: AndroidLocationCallback?
    private var geofencingClient: AndroidGeofencingClient?
    private var pendingGeofenceRequests: [String: GeofenceData] = [:]
    
    private var wifiStateCallback: ((Bool) -> Void)?
    private var bluetoothStateCallback: ((Bool) -> Void)?
    private var wifiManager: AndroidWifiManager?
    private var bluetoothAdapter: AndroidBluetoothAdapter?
    
    private var foregroundService: AndroidForegroundService?
    private var isServiceRunning = false
    
    private var powerManager: AndroidPowerManager?
    private var batteryOptimizationEnabled = true
    
    private var lastKnownLocation: CLLocation?
    private var locationUpdateListeners: [(CLLocation) -> Void] = []

    private let minReliableAccuracy: Double = 50.0
    private var isGpsUnreliable = false
    private var fallbackMethod: DetectionMethod = .wifi
    public var onAccuracyChanged: ((Bool) -> Void)?
    public var onPermissionDenied: (() -> Void)?
    
    public init() {
        fusedLocationClient = AndroidFusedLocationProviderClient()
        locationCallback = AndroidLocationCallback()
        geofencingClient = AndroidGeofencingClient()
        wifiManager = AndroidWifiManager()
        bluetoothAdapter = AndroidBluetoothAdapter()
        powerManager = AndroidPowerManager()
    }
    
    public func getCurrentLocation() async throws -> CLLocation {
        guard let client = fusedLocationClient else { throw LocationError.locationUnavailable }
        guard await requestPermission() else { throw LocationError.permissionDenied }
        
        if let location = try await client.getLastLocation() {
            lastKnownLocation = location
            return location
        }
        
        let location = try await client.requestLocationUpdate(interval: 10000)
        lastKnownLocation = location
        return location
    }
    
    public func startMonitoring(zone: Zone) async throws {
        guard let geofenceClient = geofencingClient else { throw LocationError.locationUnavailable }
        
        let geofenceData = GeofenceData(
            id: zone.id.uuidString,
            latitude: zone.latitude,
            longitude: zone.longitude,
            radius: Float(zone.radius),
            expirationDuration: -1,
            transitionTypes: [1, 4, 2]
        )
        
        pendingGeofenceRequests[zone.id.uuidString] = geofenceData
        try await geofenceClient.addGeofence(geofenceData)
        
        if !isServiceRunning { try await startForegroundService() }
    }
    
    public func stopMonitoring(zone: Zone) async throws {
        guard let geofenceClient = geofencingClient else { throw LocationError.locationUnavailable }
        try await geofenceClient.removeGeofence(zone.id.uuidString)
        pendingGeofenceRequests.removeValue(forKey: zone.id.uuidString)
        if pendingGeofenceRequests.isEmpty { await stopForegroundService() }
    }
    
    public func requestPermission() async throws -> Bool {
        await withCheckedContinuation { continuation in
            AndroidPermissionManager.requestLocationPermission { [weak self] granted in
                if !granted { self?.onPermissionDenied?() }
                continuation.resume(returning: granted)
            }
        }
    }
    
    public func isAuthorized() -> Bool { AndroidPermissionManager.isLocationAuthorized() }

    public var effectiveDetectionMethod: DetectionMethod {
        isGpsUnreliable ? fallbackMethod : detectionMethod
    }

    public func checkLocationAccuracy(_ location: CLLocation) -> Bool {
        let isReliable = location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= minReliableAccuracy
        if isGpsUnreliable != !isReliable {
            isGpsUnreliable = !isReliable
            onAccuracyChanged?(!isReliable)
            fallbackMethod = isWifiConnected() ? .wifi : .bluetooth
        }
        return isReliable
    }

    public func isGpsReliable() -> Bool {
        !isGpsUnreliable
    }

    public func getFallbackMethod() -> DetectionMethod {
        fallbackMethod
    }

    public func resetGpsReliability() {
        isGpsUnreliable = false
        onAccuracyChanged?(false)
    }

    public func startLocationUpdates(interval: Int64 = 10000) async throws {
        guard let client = fusedLocationClient, let callback = locationCallback else {
            throw LocationError.locationUnavailable
        }
        
        callback.onLocationResult = { [weak self] location in
            self?.lastKnownLocation = location
            self?.locationUpdateListeners.forEach { $0(location) }
        }
        
        try await client.requestLocationUpdates(interval: interval, callback: callback)
    }
    
    public func stopLocationUpdates() async throws {
        guard let client = fusedLocationClient, let callback = locationCallback else { return }
        try await client.removeLocationUpdates(callback)
    }
    
    public func addLocationListener(_ listener: @escaping (CLLocation) -> Void) {
        locationUpdateListeners.append(listener)
    }
    
    public func removeLocationListener(_ listener: @escaping (CLLocation) -> Void) {
        locationUpdateListeners.removeAll { $0 === listener }
    }
    
    public func getActiveGeofences() -> [String] { Array(pendingGeofenceRequests.keys) }
    
    public func startWifiMonitoring(callback: @escaping (Bool) -> Void) {
        wifiStateCallback = callback
        wifiManager?.startWifiStateMonitoring { [weak self] isConnected in
            self?.wifiStateCallback?(isConnected)
        }
    }
    
    public func stopWifiMonitoring() {
        wifiManager?.stopWifiStateMonitoring()
        wifiStateCallback = nil
    }
    
    public func isWifiConnected() -> Bool { wifiManager?.isWifiConnected() ?? false }
    public func getWifiSsid() -> String? { wifiManager?.getConnectionInfo()?.ssid }
    
    public func startBluetoothMonitoring(callback: @escaping (Bool) -> Void) {
        bluetoothStateCallback = callback
        bluetoothAdapter?.registerBluetoothStateListener { [weak self] isEnabled in
            self?.bluetoothStateCallback?(isEnabled)
        }
    }
    
    public func stopBluetoothMonitoring() {
        bluetoothAdapter?.unregisterBluetoothStateListener()
        bluetoothStateCallback = nil
    }
    
    public func isBluetoothEnabled() -> Bool { bluetoothAdapter?.isEnabled() ?? false }
    public func getPairedDevices() -> [BluetoothDevice] { bluetoothAdapter?.getBondedDevices() ?? [] }
    
    public func startForegroundService() async throws {
        guard !isServiceRunning else { return }
        foregroundService = AndroidForegroundService()
        try await foregroundService?.start(
            notificationId: 1001,
            channelId: "location_service_channel",
            channelName: "Location Service",
            notificationTitle: "Location Tracking Active",
            notificationText: "Monitoring your location for automation rules"
        )
        isServiceRunning = true
    }
    
    public func stopForegroundService() async {
        await foregroundService?.stop()
        foregroundService = nil
        isServiceRunning = false
    }
    
    public func updateNotification(title: String, text: String) async {
        await foregroundService?.updateNotification(title: title, text: text)
    }
    
    public func isForegroundServiceRunning() -> Bool { isServiceRunning }
    
    public func isBatteryOptimizationEnabled() -> Bool {
        guard let powerManager = powerManager else { return true }
        batteryOptimizationEnabled = powerManager.isIgnoringBatteryOptimizations()
        return batteryOptimizationEnabled
    }
    
    public func requestDisableBatteryOptimization() async throws {
        guard let powerManager = powerManager else { return }
        if !powerManager.isIgnoringBatteryOptimizations() {
            try await powerManager.requestIgnoreBatteryOptimization()
            batteryOptimizationEnabled = false
        }
    }
    
    public func openBatteryOptimizationSettings() { powerManager?.openBatteryOptimizationSettings() }
    
    public func getBatteryOptimizationStatus() -> BatteryOptimizationStatus {
        let isEnabled = isBatteryOptimizationEnabled()
        if !isEnabled { return .disabled }
        else if pendingGeofenceRequests.isEmpty { return .notNeeded }
        else { return .enabled(recommended: true) }
    }
    
    deinit {
        Task { await stopLocationUpdates(); await stopForegroundService() }
        stopWifiMonitoring()
        stopBluetoothMonitoring()
    }
}

public struct GeofenceData {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public let radius: Float
    public let expirationDuration: Int64
    public let transitionTypes: [Int]
    
    public init(id: String, latitude: Double, longitude: Double, radius: Float, expirationDuration: Int64, transitionTypes: [Int]) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.expirationDuration = expirationDuration
        self.transitionTypes = transitionTypes
    }
}

public struct BluetoothDevice: Identifiable {
    public let id: String
    public let name: String
    public let address: String
    
    public init(id: String, name: String, address: String) {
        self.id = id
        self.name = name
        self.address = address
    }
}

public enum BatteryOptimizationStatus {
    case disabled
    case enabled(recommended: Bool)
    case notNeeded
}

public protocol AndroidFusedLocationProviderClientProtocol {
    func getLastLocation() async throws -> CLLocation?
    func requestLocationUpdate(interval: Int64) async throws -> CLLocation
    func requestLocationUpdates(interval: Int64, callback: AndroidLocationCallback) async throws
    func removeLocationUpdates(_ callback: AndroidLocationCallback) async throws
}

public class AndroidLocationCallback {
    public var onLocationResult: ((CLLocation) -> Void)?
    public var onLocationAvailabilityChanged: ((Bool) -> Void)?
}

public protocol AndroidGeofencingClientProtocol {
    func addGeofence(_ geofence: GeofenceData) async throws
    func removeGeofence(_ geofenceId: String) async throws
    func removeAllGeofences() async throws
}

class AndroidFusedLocationProviderClient: AndroidFusedLocationProviderClientProtocol {
    func getLastLocation() async throws -> CLLocation? { nil }
    func requestLocationUpdate(interval: Int64) async throws -> CLLocation { CLLocation(latitude: 0, longitude: 0) }
    func requestLocationUpdates(interval: Int64, callback: AndroidLocationCallback) async throws {}
    func removeLocationUpdates(_ callback: AndroidLocationCallback) async throws {}
}

class AndroidGeofencingClient: AndroidGeofencingClientProtocol {
    func addGeofence(_ geofence: GeofenceData) async throws {}
    func removeGeofence(_ geofenceId: String) async throws {}
    func removeAllGeofences() async throws {}
}

class AndroidWifiManager {
    func startWifiStateMonitoring(_ callback: @escaping (Bool) -> Void) {}
    func stopWifiStateMonitoring() {}
    func isWifiConnected() -> Bool { false }
    func getConnectionInfo() -> WifiInfo? { nil }
}

struct WifiInfo { var ssid: String? }

class AndroidBluetoothAdapter {
    func registerBluetoothStateListener(_ callback: @escaping (Bool) -> Void) {}
    func unregisterBluetoothStateListener() {}
    func isEnabled() -> Bool { false }
    func getBondedDevices() -> [BluetoothDevice] { [] }
}

class AndroidForegroundService {
    func start(notificationId: Int, channelId: String, channelName: String, notificationTitle: String, notificationText: String) async throws {}
    func stop() async {}
    func updateNotification(title: String, text: String) async {}
}

class AndroidPowerManager {
    func isIgnoringBatteryOptimizations() -> Bool { false }
    func requestIgnoreBatteryOptimization() async throws {}
    func openBatteryOptimizationSettings() {}
}

class AndroidPermissionManager {
    static func requestLocationPermission(_ callback: @escaping (Bool) -> Void) { callback(false) }
    static func isLocationAuthorized() -> Bool { false }
}