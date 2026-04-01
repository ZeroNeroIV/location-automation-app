// iOS/Location/iOSLocationService.swift
import Foundation
import CoreLocation
import Network
import CoreBluetooth

public final class iOSLocationService: NSObject, LocationServiceProtocol, CLLocationManagerDelegate {
    
    // MARK: - Properties
    
    private let locationManager: CLLocationManager
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var permissionContinuation: CheckedContinuation<Bool, Error>?
    private var monitoredRegions: [UUID: CLRegion] = [:]
    
    // iOS 20 region limit
    private let maxMonitoredRegions = 20
    
    // WiFi and Bluetooth detection
    private let wifiMonitor: NWPathMonitor
    private let bluetoothManager: CBCentralManager?
    private let bluetoothQueue = DispatchQueue(label: "com.location.bluetooth")
    
    private var isWifiConnected = false
    private var isBluetoothEnabled = false

    private let minReliableAccuracy: Double = 50.0
    private var isGpsUnreliable = false
    private var fallbackMethod: DetectionMethod = .wifi
    public var onAccuracyChanged: ((Bool) -> Void)?
    public var onPermissionDenied: (() -> Void)?
    
    public override init() {
        self.locationManager = CLLocationManager()
        self.wifiMonitor = NWPathMonitor()
        self.bluetoothManager = CBCentralManager(delegate: nil, queue: nil)
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // meters
        
        setupWifiMonitoring()
    }
    
    deinit {
        wifiMonitor.cancel()
    }
    
    // MARK: - LocationServiceProtocol
    
    public var detectionMethod: DetectionMethod {
        .gps
    }
    
    public func getCurrentLocation() async throws -> CLLocation {
        guard isAuthorized() else {
            throw LocationError.permissionDenied
        }
        
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationError.locationUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
    
    public func startMonitoring(zone: Zone) async throws {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            throw LocationError.locationUnavailable
        }
        
        guard monitoredRegions.count < maxMonitoredRegions else {
            throw LocationError.zoneNotFound // Reuse error - at region limit
        }
        
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: zone.latitude, longitude: zone.longitude),
            radius: min(zone.radius, locationManager.maximumRegionMonitoringDistance),
            identifier: zone.id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        monitoredRegions[zone.id] = region
        locationManager.startMonitoring(for: region)
    }
    
    public func stopMonitoring(zone: Zone) async throws {
        guard let region = monitoredRegions[zone.id] else {
            throw LocationError.zoneNotFound
        }
        
        locationManager.stopMonitoring(for: region)
        monitoredRegions.removeValue(forKey: zone.id)
    }
    
    public func requestPermission() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            self.permissionContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    public func isAuthorized() -> Bool {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    public var effectiveDetectionMethod: DetectionMethod {
        isGpsUnreliable ? fallbackMethod : detectionMethod
    }

    public func checkLocationAccuracy(_ location: CLLocation) -> Bool {
        let isReliable = location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= minReliableAccuracy
        if isGpsUnreliable != !isReliable {
            isGpsUnreliable = !isReliable
            onAccuracyChanged?(!isReliable)
            fallbackMethod = isWifiConnected ? .wifi : .bluetooth
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

    // MARK: - WiFi Detection
    
    public func isWifiConnectedToNetwork(named ssid: String?) -> Bool {
        guard isWifiConnected else { return false }
        
        // Note: Getting actual SSID requires special entitlement
        // This checks connectivity status only
        if let ssid = ssid {
            // Would need location permission to get actual SSID on iOS 13+
            return false
        }
        return isWifiConnected
    }
    
    public func checkWifiConnectivity() -> Bool {
        return isWifiConnected
    }
    
    // MARK: - Bluetooth Detection
    
    public func isBluetoothEnabled() -> Bool {
        return isBluetoothEnabled
    }
    
    public func checkBluetoothState() -> Bool {
        guard let manager = bluetoothManager else { return false }
        return manager.state == .poweredOn
    }
    
    // MARK: - Private Methods
    
    private func setupWifiMonitoring() {
        wifiMonitor.pathUpdateHandler = { [weak self] path in
            self?.isWifiConnected = path.usesInterfaceType(.wifi)
        }
        wifiMonitor.start(queue: DispatchQueue(label: "com.location.wifi"))
    }
    
    // MARK: - CLLocationManagerDelegate
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let continuation = locationContinuation {
            continuation.resume(throwing: error)
            locationContinuation = nil
        }
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            permissionContinuation?.resume(returning: true)
        case .denied, .restricted:
            permissionContinuation?.resume(returning: false)
            onPermissionDenied?()
        case .notDetermined:
            break
        @unknown default:
            permissionContinuation?.resume(returning: false)
        }
        permissionContinuation = nil
    }
    
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // Post notification or trigger callback for zone entry
        NotificationCenter.default.post(
            name: .locationZoneEntered,
            object: nil,
            userInfo: ["region": region.identifier]
        )
    }
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        // Post notification or trigger callback for zone exit
        NotificationCenter.default.post(
            name: .locationZoneExited,
            object: nil,
            userInfo: ["region": region.identifier]
        )
    }
    
    public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // Handle monitoring failure
        print("Region monitoring failed: \(error.localizedDescription)")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let locationZoneEntered = Notification.Name("locationZoneEntered")
    static let locationZoneExited = Notification.Name("locationZoneExited")
}

// MARK: - Bluetooth Delegate

extension iOSLocationService: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothEnabled = central.state == .poweredOn
    }
}
