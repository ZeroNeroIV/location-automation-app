// Core/BatteryManager.swift
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Battery Target Configuration

public struct BatteryTarget {
    public let maxDrainPerDay: Double
    public let minUpdateIntervalSeconds: Double
    public let maxGeofences: Int
    public let preferSignificantChanges: Bool
    public let useApproximateLocation: Bool
    
    public static let defaultTarget = BatteryTarget(
        maxDrainPerDay: 5.0,
        minUpdateIntervalSeconds: 300.0,
        maxGeofences: 20,
        preferSignificantChanges: true,
        useApproximateLocation: true
    )
    
    public static let aggressiveSaving = BatteryTarget(
        maxDrainPerDay: 2.0,
        minUpdateIntervalSeconds: 600.0,
        maxGeofences: 10,
        preferSignificantChanges: true,
        useApproximateLocation: true
    )
    
    public static let balanced = BatteryTarget(
        maxDrainPerDay: 8.0,
        minUpdateIntervalSeconds: 60.0,
        maxGeofences: 20,
        preferSignificantChanges: false,
        useApproximateLocation: false
    )
}

// MARK: - Battery Configuration

public struct BatteryConfiguration: Codable {
    public var iosUseApproximateLocation: Bool
    public var iosAllowBackgroundLocationUpdates: Bool
    public var iosPausesLocationUpdatesAutomatically: Bool
    public var iosUseSignificantLocationChanges: Bool
    public var iosDesiredAccuracy: Double
    public var iosDistanceFilter: Double
    public var iosActivityType: String
    
    public var androidUseApproximateLocation: Bool
    public var androidUseBatching: Bool
    public var androidFastestInterval: Int64
    public var androidUpdateInterval: Int64
    public var androidMaxUpdateDelay: Int64
    public var androidMinDisplacement: Float
    public var androidPriority: String
    public var androidGeofenceLoiteringDelay: Int
    public var androidGeofenceNotificationResponsiveness: Int
    
    public var batchGeofences: Bool
    public var batchSize: Int
    public var batchMaxSize: Int
    
    public static let `default` = BatteryConfiguration(
        iosUseApproximateLocation: true,
        iosAllowBackgroundLocationUpdates: true,
        iosPausesLocationUpdatesAutomatically: true,
        iosUseSignificantLocationChanges: true,
        iosDesiredAccuracy: 100.0,
        iosDistanceFilter: 100.0,
        iosActivityType: "other",
        
        androidUseApproximateLocation: true,
        androidUseBatching: true,
        androidFastestInterval: 300000,
        androidUpdateInterval: 300000,
        androidMaxUpdateDelay: 600000,
        androidMinDisplacement: 100.0,
        androidPriority: "PRIORITY_BALANCED_POWER_ACCURACY",
        androidGeofenceLoiteringDelay: 60000,
        androidGeofenceNotificationResponsiveness: 300000,
        
        batchGeofences: true,
        batchSize: 10,
        batchMaxSize: 100
    )
    
    public static let highAccuracy = BatteryConfiguration(
        iosUseApproximateLocation: false,
        iosAllowBackgroundLocationUpdates: true,
        iosPausesLocationUpdatesAutomatically: false,
        iosUseSignificantLocationChanges: false,
        iosDesiredAccuracy: 10.0,
        iosDistanceFilter: 10.0,
        iosActivityType: "other",
        
        androidUseApproximateLocation: false,
        androidUseBatching: false,
        androidFastestInterval: 5000,
        androidUpdateInterval: 5000,
        androidMaxUpdateDelay: 5000,
        androidMinDisplacement: 5.0,
        androidPriority: "PRIORITY_HIGH_ACCURACY",
        androidGeofenceLoiteringDelay: 30000,
        androidGeofenceNotificationResponsiveness: 10000,
        
        batchGeofences: false,
        batchSize: 10,
        batchMaxSize: 100
    )
}

// MARK: - iOS Location Manager Configuration

#if canImport(CoreLocation)
import CoreLocation

public final class iOSBatteryConfiguration {
    
    private let locationManager: CLLocationManager
    
    public init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
    }
    
    public func configureForBattery(target: BatteryTarget = .defaultTarget) {
        if target.useApproximateLocation {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        } else {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        }
        
        locationManager.distanceFilter = 100.0
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.activityType = .other
        
        Logger.shared.log("iOS location configured for battery optimization", level: .info)
    }
    
    public func configure(with config: BatteryConfiguration) {
        if config.iosUseApproximateLocation {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        } else {
            locationManager.desiredAccuracy = config.iosDesiredAccuracy
        }
        
        locationManager.distanceFilter = config.iosDistanceFilter
        locationManager.allowsBackgroundLocationUpdates = config.iosAllowBackgroundLocationUpdates
        locationManager.pausesLocationUpdatesAutomatically = config.iosPausesLocationUpdatesAutomatically
        
        switch config.iosActivityType {
        case "fitness":
            locationManager.activityType = .fitness
        case "navigation":
            locationManager.activityType = .navigation
        case "automotiveNavigation":
            locationManager.activityType = .automotiveNavigation
        default:
            locationManager.activityType = .other
        }
        
        Logger.shared.log("iOS location configured with custom settings", level: .info)
    }
    
    public func startSignificantLocationChanges() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            Logger.shared.log("Significant location changes not available", level: .warning)
            return
        }
        locationManager.startMonitoringSignificantLocationChanges()
        Logger.shared.log("Started significant location changes", level: .info)
    }
    
    public func stopSignificantLocationChanges() {
        locationManager.stopMonitoringSignificantLocationChanges()
        Logger.shared.log("Stopped significant location changes", level: .info)
    }
    
    public var isSignificantLocationChangesActive: Bool {
        false
    }
    
    public var currentAccuracy: CLLocationAccuracy {
        locationManager.desiredAccuracy
    }
    
    public var currentDistanceFilter: CLLocationDistance {
        locationManager.distanceFilter
    }
}
#endif

// MARK: - Android Location Configuration

public final class AndroidBatteryConfiguration {
    
    public enum LocationPriority: String {
        case highAccuracy = "PRIORITY_HIGH_ACCURACY"
        case balancedPower = "PRIORITY_BALANCED_POWER_ACCURACY"
        case lowPower = "PRIORITY_LOW_POWER"
        case noPower = "PRIORITY_NO_POWER"
    }
    
    public func configureForBattery(target: BatteryTarget = .defaultTarget) -> [String: Any] {
        let priority: LocationPriority = target.useApproximateLocation ? .lowPower : .balancedPower
        
        return createConfiguration(
            priority: priority,
            updateInterval: target.minUpdateIntervalSeconds * 1000,
            fastestInterval: target.minUpdateIntervalSeconds * 1000,
            displacement: 100.0,
            batching: true,
            maxUpdateDelay: 600000
        )
    }
    
    public func configure(with config: BatteryConfiguration) -> [String: Any] {
        let priority: LocationPriority
        switch config.androidPriority {
        case "PRIORITY_HIGH_ACCURACY":
            priority = .highAccuracy
        case "PRIORITY_LOW_POWER":
            priority = .lowPower
        case "PRIORITY_NO_POWER":
            priority = .noPower
        default:
            priority = .balancedPower
        }
        
        return createConfiguration(
            priority: priority,
            updateInterval: config.androidUpdateInterval,
            fastestInterval: config.androidFastestInterval,
            displacement: config.androidMinDisplacement,
            batching: config.androidUseBatching,
            maxUpdateDelay: config.androidMaxUpdateDelay
        )
    }
    
    public func configureGeofences(config: BatteryConfiguration, count: Int) -> GeofenceBatchConfig {
        let effectiveBatchSize = min(config.batchSize, config.batchMaxSize)
        
        return GeofenceBatchConfig(
            batchSize: effectiveBatchSize,
            useBatching: config.batchGeofences && count > effectiveBatchSize,
            loiteringDelayMs: config.androidGeofenceLoiteringDelay,
            notificationResponsivenessMs: config.androidGeofenceNotificationResponsiveness,
            expirationDuration: -1,
            transitionTypes: [1, 2, 4]
        )
    }
    
    private func createConfiguration(
        priority: LocationPriority,
        updateInterval: Int64,
        fastestInterval: Int64,
        displacement: Float,
        batching: Bool,
        maxUpdateDelay: Int64
    ) -> [String: Any] {
        return [
            "priority": priority.rawValue,
            "interval": updateInterval,
            "fastestInterval": fastestInterval,
            "displacement": displacement,
            "batchingEnabled": batching,
            "maxUpdateDelay": maxUpdateDelay,
            "waitForAccuracy": false,
            "numUpdates": 0
        ]
    }
}

// MARK: - Geofence Batch Configuration

public struct GeofenceBatchConfig {
    public let batchSize: Int
    public let useBatching: Bool
    public let loiteringDelayMs: Int
    public let notificationResponsivenessMs: Int
    public let expirationDuration: Int64
    public let transitionTypes: [Int]
    
    public var estimatedDrainPerDay: Double {
        guard useBatching else { return 3.0 }
        return Double(batchSize) * 0.1
    }
}

// MARK: - Battery Manager

public final class BatteryManager: @unchecked Sendable {
    
    public static let shared = BatteryManager()
    
    private var currentConfiguration: BatteryConfiguration = .default
    private var currentTarget: BatteryTarget = .defaultTarget
    
    #if canImport(CoreLocation)
    private var iosConfig: iOSBatteryConfiguration?
    #endif
    private var androidConfig: AndroidBatteryConfiguration?
    
    private var isTracking = false
    private var batteryDrainSamples: [Date: Double] = [:]
    private let maxSamples = 144
    
    private init() {
        setupDefaultConfigurations()
    }
    
    private func setupDefaultConfigurations() {
        #if canImport(CoreLocation)
        iosConfig = iOSBatteryConfiguration()
        #endif
        androidConfig = AndroidBatteryConfiguration()
    }
    
    public func configure(for target: BatteryTarget) {
        currentTarget = target
        currentConfiguration = generateConfiguration(for: target)
        
        Logger.shared.log(
            "Battery manager configured for target: \(target.maxDrainPerDay)% drain",
            level: .info
        )
    }
    
    public func apply(_ configuration: BatteryConfiguration) {
        currentConfiguration = configuration
        Logger.shared.log("Battery configuration applied", level: .info)
    }
    
    public func getConfiguration() -> BatteryConfiguration {
        currentConfiguration
    }
    
    public func getTarget() -> BatteryTarget {
        currentTarget
    }
    
    #if canImport(CoreLocation)
    public func configureiOS(_ locationManager: CLLocationManager) {
        let config = iOSBatteryConfiguration(locationManager: locationManager)
        
        if currentTarget.useApproximateLocation {
            config.configureForBattery(target: currentTarget)
        } else {
            config.configure(with: currentConfiguration)
        }
        
        if currentTarget.preferSignificantChanges {
            config.startSignificantLocationChanges()
        }
        
        iosConfig = config
        Logger.shared.log("iOS location manager configured", level: .info)
    }
    
    public func getiOSConfiguration() -> BatteryConfiguration {
        currentConfiguration
    }
    #endif
    
    public func getAndroidLocationRequest() -> [String: Any] {
        androidConfig?.configureForBattery(target: currentTarget) ?? [:]
    }
    
    public func getAndroidConfiguration() -> BatteryConfiguration {
        currentConfiguration
    }
    
    public func getGeofenceBatchConfig(zoneCount: Int) -> GeofenceBatchConfig {
        androidConfig?.configureGeofences(config: currentConfiguration, count: zoneCount)
            ?? GeofenceBatchConfig(
                batchSize: 10,
                useBatching: false,
                loiteringDelayMs: 60000,
                notificationResponsivenessMs: 300000,
                expirationDuration: -1,
                transitionTypes: [1, 2, 4]
            )
    }
    
    public func calculateOptimalBatchSize() -> Int {
        let targetDrain = currentTarget.maxDrainPerDay
        let baseDrainPerGeofence: Double = 0.15
        
        let maxGeofences = Int(targetDrain / baseDrainPerGeofence)
        return min(maxGeofences, currentTarget.maxGeofences)
    }
    
    public func verifyBatteryTarget() -> BatteryVerificationResult {
        let estimatedDrain = estimateDrainPerDay()
        let meetsTarget = estimatedDrain <= currentTarget.maxDrainPerDay
        
        return BatteryVerificationResult(
            target: currentTarget,
            estimatedDrainPerDay: estimatedDrain,
            meetsTarget: meetsTarget,
            recommendations: generateRecommendations(estimatedDrain: estimatedDrain)
        )
    }
    
    public func estimateDrainPerDay() -> Double {
        var baseDrain: Double = 1.0
        
        if currentConfiguration.iosUseApproximateLocation {
            baseDrain += 0.5
        } else {
            baseDrain += 2.0
        }
        
        if currentConfiguration.iosAllowBackgroundLocationUpdates {
            baseDrain += 1.0
        }
        
        if currentConfiguration.iosUseSignificantLocationChanges {
            baseDrain -= 0.5
        }
        
        if currentConfiguration.batchGeofences {
            baseDrain += 0.5
        }
        
        if currentConfiguration.androidPriority == "PRIORITY_HIGH_ACCURACY" {
            baseDrain += 2.0
        } else if currentConfiguration.androidPriority == "PRIORITY_BALANCED_POWER_ACCURACY" {
            baseDrain += 1.0
        }
        
        return min(baseDrain, 10.0)
    }
    
    private func generateRecommendations(estimatedDrain: Double) -> [String] {
        var recommendations: [String] = []
        
        if estimatedDrain > currentTarget.maxDrainPerDay {
            if !currentConfiguration.iosUseApproximateLocation {
                recommendations.append("Enable approximate location mode to reduce GPS battery drain")
            }
            if currentConfiguration.iosUseSignificantLocationChanges == false {
                recommendations.append("Consider using significant location changes for background tracking")
            }
            if currentConfiguration.androidPriority == "PRIORITY_HIGH_ACCURACY" {
                recommendations.append("Switch Android priority to PRIORITY_BALANCED_POWER_ACCURACY")
            }
            if currentConfiguration.batchGeofences == false {
                recommendations.append("Enable geofence batching to reduce update frequency")
            }
        }
        
        if recommendations.isEmpty {
            recommendations.append("Configuration is optimized for battery target")
        }
        
        return recommendations
    }
    
    public func startTracking() {
        isTracking = true
        Logger.shared.log("Battery-optimized tracking started", level: .info)
    }
    
    public func stopTracking() {
        isTracking = false
        Logger.shared.log("Battery-optimized tracking stopped", level: .info)
    }
    
    public var trackingActive: Bool {
        isTracking
    }
    
    public func recordBatteryDrain(_ drainPercentage: Double, at date: Date = Date()) {
        batteryDrainSamples[date] = drainPercentage
        
        if batteryDrainSamples.count > maxSamples {
            let oldestDate = batteryDrainSamples.keys.min() ?? date
            batteryDrainSamples.removeValue(forKey: oldestDate)
        }
    }
    
    public func getAverageDrainPerDay() -> Double {
        guard !batteryDrainSamples.isEmpty else {
            return estimateDrainPerDay()
        }
        
        let total = batteryDrainSamples.values.reduce(0, +)
        let count = Double(batteryDrainSamples.count)
        
        let scaleFactor = 24.0 * 60.0 / 10.0
        return (total / count) * scaleFactor
    }
    
    public func getBatteryStatistics() -> BatteryStatistics {
        let average = getAverageDrainPerDay()
        let estimate = estimateDrainPerDay()
        
        return BatteryStatistics(
            averageDrainPerDay: average,
            estimatedDrainPerDay: estimate,
            sampleCount: batteryDrainSamples.count,
            monitoringDurationHours: Double(batteryDrainSamples.count) / 6.0,
            meetsTarget: average <= currentTarget.maxDrainPerDay
        )
    }
    
    private func generateConfiguration(for target: BatteryTarget) -> BatteryConfiguration {
        var config = BatteryConfiguration.default
        
        if target.maxDrainPerDay <= 2.0 {
            config.iosUseApproximateLocation = true
            config.iosUseSignificantLocationChanges = true
            config.androidPriority = "PRIORITY_LOW_POWER"
            config.androidUpdateInterval = 600000
            config.androidFastestInterval = 600000
            config.batchGeofences = true
        } else if target.maxDrainPerDay <= 5.0 {
            config.iosUseApproximateLocation = true
            config.iosUseSignificantLocationChanges = true
            config.androidPriority = "PRIORITY_BALANCED_POWER_ACCURACY"
            config.androidUpdateInterval = 300000
            config.androidFastestInterval = 300000
            config.batchGeofences = true
        } else {
            config.iosUseApproximateLocation = false
            config.iosUseSignificantLocationChanges = false
            config.androidPriority = "PRIORITY_BALANCED_POWER_ACCURACY"
            config.androidUpdateInterval = 60000
            config.androidFastestInterval = 30000
            config.batchGeofences = true
        }
        
        return config
    }
}

// MARK: - Verification Result

public struct BatteryVerificationResult {
    public let target: BatteryTarget
    public let estimatedDrainPerDay: Double
    public let meetsTarget: Bool
    public let recommendations: [String]
    
    public var formattedEstimate: String {
        String(format: "%.1f%%", estimatedDrainPerDay)
    }
    
    public var targetString: String {
        String(format: "<%.1f%%", target.maxDrainPerDay)
    }
}

// MARK: - Battery Statistics

public struct BatteryStatistics {
    public let averageDrainPerDay: Double
    public let estimatedDrainPerDay: Double
    public let sampleCount: Int
    public let monitoringDurationHours: Double
    public let meetsTarget: Bool
    
    public var formattedAverage: String {
        String(format: "%.1f%%", averageDrainPerDay)
    }
    
    public var formattedEstimate: String {
        String(format: "%.1f%%", estimatedDrainPerDay)
    }
}

// MARK: - Extensions

#if canImport(CoreLocation)
import CoreLocation

extension iOSLocationService {
    public func applyBatteryOptimization() {
        BatteryManager.shared.configureiOS(locationManager)
    }
    
    public func getBatteryConfiguration() -> BatteryConfiguration {
        BatteryManager.shared.getiOSConfiguration()
    }
}
#endif
