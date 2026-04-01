public final class ZoneMonitor {
    
    private let locationService: AndroidLocationService
    private var geofencePendingIntent: AndroidPendingIntent?
    private var geofenceBroadcastReceiver: AndroidBroadcastReceiver?
    
    private var zoneTransitionCallbacks: [UUID: (ZoneTransition) -> Void] = [:]
    private var locationCallbacks: [UUID: (CLLocation) -> Void] = [:]
    
    private var isMonitoring = false
    private var monitoredZones: [UUID: Zone] = [:]
    
    private var foregroundService: ZoneMonitoringForegroundService?
    private var isServiceRunning = false
    
    private var powerManager: AndroidPowerManager?
    private var batteryOptimizationCallback: ((Bool) -> Void)?
    
    public enum ZoneTransition: String {
        case enter = "ENTER"
        case exit = "EXIT"
        case dwell = "DWELL"
    }
    
    public struct GeofenceTransitionEvent {
        public let zoneId: UUID
        public let transition: ZoneTransition
        public let location: CLLocation
        public let timestamp: Date
        
        public init(zoneId: UUID, transition: ZoneTransition, location: CLLocation, timestamp: Date = Date()) {
            self.zoneId = zoneId
            self.transition = transition
            self.location = location
            self.timestamp = timestamp
        }
    }
    
    public init(locationService: AndroidLocationService) {
        self.locationService = locationService
        self.powerManager = AndroidPowerManager()
        setupGeofenceBroadcastReceiver()
    }
    
    public func startMonitoring(zones: [Zone]) async throws {
        guard !isMonitoring else { return }
        
        let granted = try await locationService.requestPermission()
        guard granted else {
            throw ZoneMonitorError.permissionDenied
        }
        
        await checkBatteryOptimization()
        
        try await startForegroundService()
        
        for zone in zones {
            try await addGeofence(for: zone)
            monitoredZones[zone.id] = zone
        }
        
        isMonitoring = true
    }
    
    public func stopMonitoring() async {
        for zoneId in monitoredZones.keys {
            try? await removeGeofence(for: zoneId)
        }
        
        monitoredZones.removeAll()
        
        await stopForegroundService()
        
        isMonitoring = false
    }
    
    public func addZone(_ zone: Zone) async throws {
        guard isMonitoring else {
            throw ZoneMonitorError.notMonitoring
        }
        
        try await addGeofence(for: zone)
        monitoredZones[zone.id] = zone
    }
    
    public func removeZone(_ zoneId: UUID) async throws {
        try await removeGeofence(for: zoneId)
        monitoredZones.removeValue(forKey: zoneId)
        
        if monitoredZones.isEmpty {
            await stopMonitoring()
        }
    }
    
    public func onZoneTransition(zoneId: UUID, callback: @escaping (ZoneTransition) -> Void) {
        zoneTransitionCallbacks[zoneId] = callback
    }
    
    public func onLocationUpdate(zoneId: UUID, callback: @escaping (CLLocation) -> Void) {
        locationCallbacks[zoneId] = callback
    }
    
    public func removeCallbacks(for zoneId: UUID) {
        zoneTransitionCallbacks.removeValue(forKey: zoneId)
        locationCallbacks.removeValue(forKey: zoneId)
    }
    
    public func checkBatteryOptimization() async {
        guard let powerManager = powerManager else { return }
        
        let isIgnoringOptimizations = powerManager.isIgnoringBatteryOptimizations()
        batteryOptimizationCallback?(isIgnoringOptimizations)
    }
    
    public func requestDisableBatteryOptimization() async throws {
        guard let powerManager = powerManager else { return }
        
        if !powerManager.isIgnoringBatteryOptimizations() {
            try await powerManager.requestIgnoreBatteryOptimization()
            batteryOptimizationCallback?(true)
        }
    }
    
    public func onBatteryOptimizationChanged(callback: @escaping (Bool) -> Void) {
        batteryOptimizationCallback = callback
    }
    
    public func openBatteryOptimizationSettings() {
        powerManager?.openBatteryOptimizationSettings()
    }
    
    public func getBatteryOptimizationStatus() -> BatteryOptimizationStatus {
        guard let powerManager = powerManager else {
            return .enabled(recommended: true)
        }
        
        let isIgnoring = powerManager.isIgnoringBatteryOptimizations()
        
        if isIgnoring {
            return .disabled
        } else if monitoredZones.isEmpty {
            return .notNeeded
        } else {
            return .enabled(recommended: true)
        }
    }
    
    // MARK: - Foreground Service
    
    /// Starts the foreground service for reliable background monitoring
    public func startForegroundService() async throws {
        guard !isServiceRunning else { return }
        
        foregroundService = ZoneMonitoringForegroundService()
        try await foregroundService?.start(
            notificationId: ZoneMonitorConfig.serviceNotificationId,
            channelId: ZoneMonitorConfig.notificationChannelId,
            channelName: ZoneMonitorConfig.notificationChannelName,
            notificationTitle: ZoneMonitorConfig.defaultNotificationTitle,
            notificationText: ZoneMonitorConfig.defaultNotificationText
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
    
    public func isForegroundServiceRunning() -> Bool {
        return isServiceRunning
    }
    
    private func setupGeofenceBroadcastReceiver() {
        geofenceBroadcastReceiver = AndroidBroadcastReceiver(
            action: ZoneMonitorConfig.geofenceBroadcastAction
        )
        
        geofenceBroadcastReceiver?.onReceive = { [weak self] intent in
            self?.handleGeofenceTransition(intent: intent)
        }
    }
    
    private func addGeofence(for zone: Zone) async throws {
        let transitionTypes = [
            GeofenceTransitionType.enter.rawValue,
            GeofenceTransitionType.exit.rawValue,
            GeofenceTransitionType.dwell.rawValue
        ]
        
        let geofenceData = GeofenceData(
            id: zone.id.uuidString,
            latitude: zone.latitude,
            longitude: zone.longitude,
            radius: Float(zone.radius),
            expirationDuration: -1,
            transitionTypes: transitionTypes,
            loiteringDelayMs: Int(ZoneMonitorConfig.dwellDelaySeconds * 1000),
            notificationResponsivenessMs: ZoneMonitorConfig.notificationResponsivenessMs
        )
        
        try await locationService.getGeofencingClient()?.addGeofence(geofenceData)
    }
    
    private func removeGeofence(for zoneId: UUID) async throws {
        try await locationService.getGeofencingClient()?.removeGeofence(zoneId.uuidString)
    }
    
    private func handleGeofenceTransition(intent: AndroidIntent) {
        guard let geofenceTransition = intent.getExtraInt(key: GeofenceBroadcastKeys.transition),
              let transitionType = GeofenceTransitionType(rawValue: geofenceTransition) else {
            return
        }
        
        guard let triggeringGeofences = intent.getExtraStringArray(key: GeofenceBroadcastKeys.geofenceTransitionList) else {
            return
        }
        
        for geofenceId in triggeringGeofences {
            guard let zoneId = UUID(uuidString: geofenceId),
                  let zone = monitoredZones[zoneId] else {
                continue
            }
            
            let transition: ZoneTransition
            switch transitionType {
            case .enter:
                transition = .enter
            case .exit:
                transition = .exit
            case .dwell:
                transition = .dwell
            }
            
            let location = CLLocation(
                latitude: zone.latitude,
                longitude: zone.longitude
            )
            
            // Notify callback
            if let callback = zoneTransitionCallbacks[zoneId] {
                callback(transition)
            }
            
            Task {
                let text = "Zone '\(zone.name)' - \(transition.rawValue)"
                await updateNotification(title: "Zone Transition", text: text)
            }
        }
    }
}

// MARK: - Supporting Types

public enum ZoneMonitorError: Error, LocalizedError {
    case permissionDenied
    case notMonitoring
    case serviceUnavailable
    case geofenceAddFailed
    case geofenceRemoveFailed
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission was denied"
        case .notMonitoring:
            return "Zone monitoring is not active"
        case .serviceUnavailable:
            return "Location service is unavailable"
        case .geofenceAddFailed:
            return "Failed to add geofence"
        case .geofenceRemoveFailed:
            return "Failed to remove geofence"
        }
    }
}

public enum GeofenceTransitionType: Int {
    case enter = 1
    case exit = 2
    case dwell = 4
}

public struct ZoneMonitorConfig {
    public static let serviceNotificationId = 1001
    public static let notificationChannelId = "zone_monitor_channel"
    public static let notificationChannelName = "Zone Monitoring"
    public static let defaultNotificationTitle = "Location Monitoring Active"
    public static let defaultNotificationText = "Monitoring configured zones"
    
    public static let geofenceBroadcastAction = "com.locationapp.ZONE_TRANSITION"
    
    public static let dwellDelaySeconds: Double = 60
    public static let notificationResponsivenessMs = 30000
}

public struct GeofenceBroadcastKeys {
    public static let transition = "transition"
    public static let geofenceTransitionList = "geofence_transition_list"
}

public struct GeofenceData {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public let radius: Float
    public let expirationDuration: Int64
    public let transitionTypes: [Int]
    public let loiteringDelayMs: Int
    public let notificationResponsivenessMs: Int
    
    public init(
        id: String,
        latitude: Double,
        longitude: Double,
        radius: Float,
        expirationDuration: Int64,
        transitionTypes: [Int],
        loiteringDelayMs: Int = 0,
        notificationResponsivenessMs: Int = 0
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.expirationDuration = expirationDuration
        self.transitionTypes = transitionTypes
        self.loiteringDelayMs = loiteringDelayMs
        self.notificationResponsivenessMs = notificationResponsivenessMs
    }
}

public class ZoneMonitoringForegroundService {
    private var notificationManager: AndroidNotificationManager?
    
    public init() {
        notificationManager = AndroidNotificationManager()
    }
    
    public func start(
        notificationId: Int,
        channelId: String,
        channelName: String,
        notificationTitle: String,
        notificationText: String
    ) async throws {
        notificationManager?.createNotificationChannel(
            channelId: channelId,
            channelName: channelName,
            importance: AndroidNotificationImportance.high
        )
        
        let notification = AndroidNotification(
            id: notificationId,
            channelId: channelId,
            title: notificationTitle,
            text: notificationText,
            priority: AndroidNotificationPriority.high,
            ongoing: true,
            autoCancel: false
        )
        
        notificationManager?.notify(notification: notification)
    }
    
    public func stop() async {
        notificationManager?.cancelAll()
    }
    
    public func updateNotification(title: String, text: String) async {
        notificationManager?.updateNotification(
            id: ZoneMonitorConfig.serviceNotificationId,
            title: title,
            text: text
        )
    }
}

public class AndroidNotificationManager {
    public func createNotificationChannel(channelId: String, channelName: String, importance: AndroidNotificationImportance) {}
    public func notify(notification: AndroidNotification) {}
    public func updateNotification(id: Int, title: String, text: String) {}
    public func cancelAll() {}
}

public enum AndroidNotificationImportance: Int {
    case low = 1
    case defaultPriority = 2
    case high = 3
}

public enum AndroidNotificationPriority: Int {
    case low = -2
    case defaultPriority = 0
    case high = 1
}

public struct AndroidNotification {
    public let id: Int
    public let channelId: String
    public let title: String
    public let text: String
    public let priority: AndroidNotificationPriority
    public let ongoing: Bool
    public let autoCancel: Bool
    
    public init(
        id: Int,
        channelId: String,
        title: String,
        text: String,
        priority: AndroidNotificationPriority,
        ongoing: Bool,
        autoCancel: Bool
    ) {
        self.id = id
        self.channelId = channelId
        self.title = title
        self.text = text
        self.priority = priority
        self.ongoing = ongoing
        self.autoCancel = autoCancel
    }
}

public class AndroidPendingIntent {
    public let action: String
    
    public init(action: String) {
        self.action = action
    }
}

public class AndroidBroadcastReceiver {
    public let action: String
    public var onReceive: ((AndroidIntent) -> Void)?
    
    public init(action: String) {
        self.action = action
    }
    
    public func register() {}
    public func unregister() {}
}

public class AndroidIntent {
    public var action: String?
    private var extras: [String: Any] = [:]
    
    public init() {}
    
    public func putExtra(key: String, value: Any) {
        extras[key] = value
    }
    
    public func getExtraInt(key: String) -> Int? {
        return extras[key] as? Int
    }
    
    public func getExtraStringArray(key: String) -> [String]? {
        return extras[key] as? [String]
    }
}

extension AndroidLocationService {
    public func getGeofencingClient() -> AndroidGeofencingClientProtocol? {
        return self.geofencingClient
    }
}