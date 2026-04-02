// Core/Location/DetectionPriorityManager.swift
import Foundation

/// Detection method priority: Manual (highest) > GPS > WiFi > Bluetooth (lowest)
public enum DetectionPriority: Int, Comparable, Codable {
    case manual = 0
    case gps = 1
    case wifi = 2
    case bluetooth = 3
    
    public static func < (lhs: DetectionPriority, rhs: DetectionPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Manual override state for location detection
public enum ManualOverrideState: Equatable {
    case inactive
    case active(zoneId: UUID, activatedAt: Date)
}

/// Zone change event for tracking
public struct ZoneChangeEvent {
    public let zoneId: UUID
    public let method: DetectionMethod
    public let timestamp: Date
    
    public init(zoneId: UUID, method: DetectionMethod, timestamp: Date = Date()) {
        self.zoneId = zoneId
        self.method = method
        self.timestamp = timestamp
    }
}

/// Active zone info
public struct ActiveZone: Sendable {
    public let zone: Zone
    public let method: DetectionMethod
    public let detectedAt: Date
    
    public init(zone: Zone, method: DetectionMethod, detectedAt: Date = Date()) {
        self.zone = zone
        self.method = method
        self.detectedAt = detectedAt
    }
}

/// Manager for prioritizing detection methods and handling zone changes
public final class DetectionPriorityManager: @unchecked Sendable {
    public static let shared = DetectionPriorityManager()
    
    // MARK: - Configuration
    
    /// Debounce interval for rapid zone changes (default: 30 seconds)
    public var debounceInterval: TimeInterval = 30.0
    
    // MARK: - State
    
    /// Currently active zone (mutually exclusive)
    private(set) public var activeZone: ActiveZone?
    
    /// Manual override state
    private(set) public var manualOverride: ManualOverrideState = .inactive
    
    /// Pending zone change (for debouncing)
    private var pendingChange: ZoneChangeEvent?
    
    /// Timer for debounce
    private var debounceTimer: DispatchTimer?
    
    /// Queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.location-automation.priority-manager", qos: .userInitiated)
    
    // MARK: - Callbacks
    
    /// Called when zone changes
    public var onZoneChanged: ((ActiveZone?) -> Void)?
    
    /// Called when manual override is activated/deactivated
    public var onManualOverrideChanged: ((ManualOverrideState) -> Void)?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Priority Resolution
    
    /// Resolves priority between detection methods
    /// - Parameters:
    ///   - method: The detection method
    ///   - zone: The zone being considered
    /// - Returns: The priority level for the method/zone combination
    public func resolvePriority(for method: DetectionMethod, zone: Zone) -> DetectionPriority {
        // Manual override has highest priority
        if case .active(let overrideZoneId, _) = manualOverride {
            if overrideZoneId == zone.id {
                return .manual
            }
            // If manual override is active for different zone, it takes precedence
            return .manual
        }
        
        // Map detection method to priority
        switch method {
        case .gps:
            return .gps
        case .wifi:
            return .wifi
        case .bluetooth:
            return .bluetooth
        case .geofence:
            return .gps // Geofence uses GPS internally
        }
    }
    
    /// Determines which zone should be active given multiple zone candidates
    /// - Parameter candidates: Array of (zone, detection method) tuples
    /// - Returns: The winning zone and method, or nil if no candidates
    public func resolveWinner(from candidates: [(zone: Zone, method: DetectionMethod)]) -> (zone: Zone, method: DetectionMethod)? {
        guard !candidates.isEmpty else { return nil }
        
        // Sort by priority (lower is higher priority)
        let sorted = candidates.sorted { a, b in
            resolvePriority(for: a.method, zone: a.zone) < resolvePriority(for: b.method, zone: b.zone)
        }
        
        return (sorted[0].zone, sorted[0].method)
    }
    
    // MARK: - Manual Override
    
    /// Activates manual override for a specific zone
    /// - Parameter zone: The zone to set as manually active
    public func activateManualOverride(for zone: Zone) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let previousState = self.manualOverride
            self.manualOverride = .active(zoneId: zone.id, activatedAt: Date())
            
            // Cancel any pending debounced change
            self.cancelPendingChange()
            
            // Immediately activate the manual zone
            let newActiveZone = ActiveZone(zone: zone, method: .gps)
            self.setActiveZone(newActiveZone)
            
            Logger.shared.info("Manual override activated for zone: \(zone.name)")
            
            DispatchQueue.main.async {
                self.onManualOverrideChanged?(self.manualOverride)
            }
        }
    }
    
    /// Deactivates manual override
    public func deactivateManualOverride() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            guard case .active(let zoneId, _) = self.manualOverride else { return }
            
            let previousZone = self.activeZone?.zone
            self.manualOverride = .inactive
            
            Logger.shared.info("Manual override deactivated")
            
            DispatchQueue.main.async {
                self.onManualOverrideChanged?(self.manualOverride)
            }
            
            // If there was a previously pending zone from auto-detection, activate it
            if let previousZone = previousZone {
                let newActiveZone = ActiveZone(zone: previousZone, method: .gps)
                self.setActiveZone(newActiveZone)
            }
        }
    }
    
    /// Checks if manual override is currently active
    public var isManualOverrideActive: Bool {
        if case .active = manualOverride {
            return true
        }
        return false
    }
    
    // MARK: - Zone Management
    
    /// Requests a zone change with debounce handling
    /// - Parameters:
    ///   - zone: The zone to change to
    ///   - method: The detection method that detected the zone
    public func requestZoneChange(zone: Zone, method: DetectionMethod) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Ignore if manual override is active
            if self.isManualOverrideActive {
                Logger.shared.debug("Ignoring zone change request - manual override active")
                return
            }
            
            // Ignore if same zone
            if let activeZone = self.activeZone, activeZone.zone.id == zone.id {
                Logger.shared.debug("Ignoring zone change - same zone: \(zone.name)")
                return
            }
            
            let event = ZoneChangeEvent(zoneId: zone.id, method: method)
            
            // Check if we have a pending change
            if let pending = self.pendingChange {
                // Check if pending change is same zone
                if pending.zoneId == zone.id {
                    Logger.shared.debug("Zone change already pending: \(zone.name)")
                    return
                }
                
                // Different zone - cancel existing pending and start new debounce
                self.cancelPendingChange()
            }
            
            // Start debounce timer
            self.pendingChange = event
            self.startDebounceTimer(zone: zone, method: method)
            
            Logger.shared.info("Zone change debounced: \(zone.name) via \(method.rawValue)")
        }
    }
    
    /// Immediately applies a zone change without debouncing (for high-priority methods)
    /// - Parameters:
    ///   - zone: The zone to activate
    ///   - method: The detection method
    public func applyImmediateZoneChange(zone: Zone, method: DetectionMethod) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Cancel any pending debounced change
            self.cancelPendingChange()
            
            let newActiveZone = ActiveZone(zone: zone, method: method)
            self.setActiveZone(newActiveZone)
            
            Logger.shared.info("Immediate zone change applied: \(zone.name) via \(method.rawValue)")
        }
    }
    
    /// Clears the active zone
    public func clearActiveZone() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.cancelPendingChange()
            self.activeZone = nil
            
            Logger.shared.info("Active zone cleared")
            
            DispatchQueue.main.async {
                self.onZoneChanged?(nil)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setActiveZone(_ zone: ActiveZone) {
        let previousZone = self.activeZone
        self.activeZone = zone
        
        if previousZone?.zone.id != zone.zone.id {
            Logger.shared.info("Active zone changed: \(zone.zone.name) (method: \(zone.method.rawValue))")
            
            let zoneCopy = zone
            DispatchQueue.main.async { [weak self] in
                self?.onZoneChanged?(zoneCopy)
            }
        }
    }
    
    private func startDebounceTimer(zone: Zone, method: DetectionMethod) {
        debounceTimer?.invalidate()
        
        let zoneId = zone.id
        let zoneName = zone.name
        let methodCopy = method
        
        debounceTimer = DispatchTimer(interval: debounceInterval, queue: .main) { [weak self] in
            guard let self = self else { return }
            self.queue.async { [weak self] in
                guard let self = self else { return }
                
                if let pending = self.pendingChange, pending.zoneId == zoneId {
                    self.pendingChange = nil
                    
                    let newActiveZone = ActiveZone(zone: zone, method: methodCopy)
                    self.setActiveZone(newActiveZone)
                    
                    Logger.shared.info("Debounce completed: \(zoneName)")
                }
            }
        }
        debounceTimer?.start()
    }
    
    private func cancelPendingChange() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        pendingChange = nil
    }
    
    // MARK: - State Queries
    
    /// Gets the current detection priority for display
    public var currentPriority: DetectionPriority? {
        if case .active = manualOverride {
            return .manual
        }
        guard let activeZone = activeZone else { return nil }
        
        return resolvePriority(for: activeZone.method, zone: activeZone.zone)
    }
    
    /// Returns a description of the current state
    public func getStateDescription() -> String {
        if case .active(let zoneId, let date) = manualOverride {
            if let zone = activeZone?.zone, zone.id == zoneId {
                return "Manual Override: \(zone.name) (since \(date))"
            }
            return "Manual Override: \(zoneId)"
        }
        
        guard let active = activeZone else {
            return "No active zone"
        }
        
        return "Active: \(active.zone.name) via \(active.method.rawValue)"
    }
}

// MARK: - Dispatch Timer Helper

private final class DispatchTimer {
    private var timer: DispatchSourceTimer?
    private let queue: DispatchQueue
    
    init(interval: TimeInterval, queue: DispatchQueue = .main, handler: @escaping () -> Void) {
        self.queue = queue
        self.timer = DispatchSource.makeTimerSource(queue: queue)
        self.timer?.schedule(deadline: .now() + interval)
        self.timer?.setEventHandler(handler: handler)
    }
    
    func start() {
        timer?.resume()
    }
    
    func invalidate() {
        timer?.cancel()
        timer = nil
    }
}
