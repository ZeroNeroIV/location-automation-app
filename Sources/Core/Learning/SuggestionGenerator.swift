// Core/Learning/SuggestionGenerator.swift
import Foundation

/// SuggestionGenerator analyzes patterns and deviations to generate smart suggestions
/// for profile changes, zone creation, and zone deletion.
/// Rate limited to 1 suggestion per day to avoid notification fatigue.
public final class SuggestionGenerator {
    
    // MARK: - Singleton
    
    public static let shared = SuggestionGenerator()
    
    // MARK: - Configuration
    
    /// Minimum visits required before generating suggestions
    public static let minimumVisitsForSuggestion: Int = 5
    
    /// Days of inactivity before suggesting zone deletion
    public static let zoneInactivityDays: Int = 30
    
    /// Minimum visit frequency to suggest new zone
    public static let newLocationMinVisits: Int = 3
    
    // MARK: - Properties
    
    private let deviationDetector = DeviationDetector.shared
    private let patternTracker = PatternTracker.shared
    private let database = DatabaseManager.shared
    private let logger = Logger.shared
    private let calendar = Calendar.current
    
    /// Last suggestion date for rate limiting
    private var lastSuggestionDate: Date?
    
    /// Lock for thread-safe access to lastSuggestionDate
    private let rateLimitLock = NSLock()
    
    // MARK: - Initialization
    
    private init() {
        loadLastSuggestionDate()
    }
    
    // MARK: - Rate Limiting
    
    /// Check if a new suggestion can be generated (1 per day limit)
    /// - Returns: true if more than 24 hours since last suggestion
    public func canGenerateSuggestion() -> Bool {
        rateLimitLock.lock()
        defer { rateLimitLock.unlock() }
        
        guard let lastDate = lastSuggestionDate else {
            return true
        }
        
        let now = Date()
        let timeSinceLastSuggestion = now.timeIntervalSince(lastDate)
        let oneDay: TimeInterval = 24 * 60 * 60 // 24 hours in seconds
        
        return timeSinceLastSuggestion >= oneDay
    }
    
    /// Get time remaining until next suggestion is allowed
    /// - Returns: TimeInterval representing seconds until next suggestion, or 0 if available
    public func timeUntilNextSuggestion() -> TimeInterval {
        rateLimitLock.lock()
        defer { rateLimitLock.unlock() }
        
        guard let lastDate = lastSuggestionDate else {
            return 0
        }
        
        let now = Date()
        let timeSinceLastSuggestion = now.timeIntervalSince(lastDate)
        let oneDay: TimeInterval = 24 * 60 * 60
        
        let remaining = oneDay - timeSinceLastSuggestion
        return max(0, remaining)
    }
    
    /// Mark that a suggestion was generated (update last suggestion date)
    private func markSuggestionGenerated() {
        rateLimitLock.lock()
        lastSuggestionDate = Date()
        rateLimitLock.unlock()
        
        // Persist to database
        saveLastSuggestionDate()
    }
    
    /// Load last suggestion date from database
    private func loadLastSuggestionDate() {
        // For now, use UserDefaults-like storage via a file
        // In production, this would be stored in the database
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let supportDir = appSupport else { return }
        
        let dateFile = supportDir.appendingPathComponent("last_suggestion_date.txt")
        if let data = try? Data(contentsOf: dateFile),
           let dateString = String(data: data, encoding: .utf8),
           let timestamp = Double(dateString) {
            lastSuggestionDate = Date(timeIntervalSince1970: timestamp)
        }
    }
    
    /// Save last suggestion date to database
    private func saveLastSuggestionDate() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let supportDir = appSupport else { return }
        
        try? fileManager.createDirectory(at: supportDir, withIntermediateDirectories: true)
        
        let dateFile = supportDir.appendingPathComponent("last_suggestion_date.txt")
        if let date = lastSuggestionDate {
            let timestamp = String(date.timeIntervalSince1970)
            try? timestamp.write(to: dateFile, atomically: true, encoding: .utf8)
        }
    }
    
    // MARK: - Main Suggestion Generation
    
    /// Generate a single suggestion based on current data
    /// - Returns: A Suggestion if one can be generated, nil if rate limited or no data
    public func generateSuggestion() -> Suggestion? {
        guard canGenerateSuggestion() else {
            logger.debug("Suggestion generation blocked by rate limit")
            return nil
        }
        
        // Priority order: profile change > zone creation > zone deletion
        if let profileSuggestion = generateProfileChangeSuggestion() {
            markSuggestionGenerated()
            return profileSuggestion
        }
        
        if let zoneCreationSuggestion = generateZoneCreationSuggestion() {
            markSuggestionGenerated()
            return zoneCreationSuggestion
        }
        
        if let zoneDeletionSuggestion = generateZoneDeletionSuggestion() {
            markSuggestionGenerated()
            return zoneDeletionSuggestion
        }
        
        logger.info("No suggestions available at this time")
        return nil
    }
    
    /// Force generate a suggestion (for testing, bypasses rate limit)
    /// - Returns: A Suggestion if one can be generated, nil if no data
    public func forceGenerateSuggestion() -> Suggestion? {
        // Priority order: profile change > zone creation > zone deletion
        if let profileSuggestion = generateProfileChangeSuggestion() {
            return profileSuggestion
        }
        
        if let zoneCreationSuggestion = generateZoneCreationSuggestion() {
            return zoneCreationSuggestion
        }
        
        if let zoneDeletionSuggestion = generateZoneDeletionSuggestion() {
            return zoneDeletionSuggestion
        }
        
        return nil
    }
    
    // MARK: - Profile Change Suggestions
    
    /// Generate suggestions for profile changes based on deviation patterns
    /// - Returns: ProfileChangeSuggestion if patterns warrant a change
    private func generateProfileChangeSuggestion() -> Suggestion? {
        do {
            let zones = try database.getAllZones()
            
            for zone in zones {
                guard let deviations = deviationDetector.detectAllDeviations(for: zone.id),
                      !deviations.isEmpty else {
                    continue
                }
                
                // Check for significant deviations
                let significantDeviations = deviations.filter { $0.exceedsThreshold }
                guard !significantDeviations.isEmpty else {
                    continue
                }
                
                let deviation = significantDeviations.first!
                let zoneName = zone.name
                let currentProfile = try database.getProfile(id: zone.profileId)
                
                // Determine suggested profile change based on deviation type
                let suggestedSetting: ProfileSetting
                let suggestionMessage: String
                
                if deviation.deviationType == .entryTime {
                    // User arriving at unusual times - suggest DND
                    suggestedSetting = .dnd
                    suggestionMessage = "Your pattern at \(zoneName) has changed. You've been arriving at unusual times. Consider enabling DND automatically."
                } else if deviation.deviationType == .duration {
                    // User spending different amount of time - suggest vibrate
                    suggestedSetting = .vibrate
                    suggestionMessage = "Your time at \(zoneName) varies significantly from your usual pattern. Consider enabling vibrate mode."
                } else {
                    continue
                }
                
                let profileChange = ProfileChangeSuggestion(
                    id: UUID(),
                    zoneId: zone.id,
                    zoneName: zoneName,
                    currentProfileName: currentProfile?.name ?? "Unknown",
                    currentProfile: currentProfile,
                    suggestedSetting: suggestedSetting,
                    reason: suggestionMessage,
                    deviation: deviation,
                    createdAt: Date()
                )
                
                logger.info("Generated profile change suggestion for zone \(zoneName)")
                return .profileChange(profileChange)
            }
        } catch {
            logger.error("Failed to generate profile change suggestion: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // MARK: - Zone Creation Suggestions
    
    /// Generate suggestions for new zones based on visit patterns
    /// - Returns: ZoneCreationSuggestion if new locations are frequently visited
    private func generateZoneCreationSuggestion() -> Suggestion? {
        // Analyze GPS locations to find frequently visited new areas
        // This is a simplified implementation - in production you'd use actual GPS data
        // For now, we'll look at patterns that might indicate new zones
        
        do {
            let zones = try database.getAllZones()
            let existingZoneIds = Set(zones.map { $0.id })
            
            // Look for patterns that don't match any existing zone
            // This would require GPS coordinate tracking - placeholder logic
            // In a real implementation, we'd analyze raw GPS coordinates
            
            // For demonstration, check if we have enough data to suggest a new zone
            // based on visit frequency at unusual locations
            logger.debug("Zone creation suggestion: analyzing visit patterns")
            
            // Return nil for now - would require GPS coordinate analysis
            return nil
        } catch {
            logger.error("Failed to generate zone creation suggestion: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Alternative: Check for frequent visits to known but unzoned locations
    /// - Parameter coordinates: Array of (latitude, longitude) tuples
    /// - Returns: ZoneCreationSuggestion if clusters found
    public func suggestNewZoneFromCoordinates(_ coordinates: [(latitude: Double, longitude: Double)]) -> Suggestion? {
        guard coordinates.count >= SuggestionGenerator.newLocationMinVisits else {
            return nil
        }
        
        // Cluster coordinates to find common location
        let center = calculateCentroid(coordinates)
        
        // Check distance from existing zones
        do {
            let zones = try database.getAllZones()
            for zone in zones {
                let distance = haversineDistance(
                    lat1: center.latitude, lon1: center.longitude,
                    lat2: zone.latitude, lon2: zone.longitude
                )
                
                // If far from existing zones, suggest new zone
                if distance > zone.radius * 2 { // At least 2x the largest radius
                    let suggestion = ZoneCreationSuggestion(
                        id: UUID(),
                        suggestedName: "New Location at \(String(format: "%.4f", center.latitude)), \(String(format: "%.4f", center.longitude))",
                        latitude: center.latitude,
                        longitude: center.longitude,
                        radius: 100, // Default 100m radius
                        visitCount: coordinates.count,
                        reason: "You frequently visit this location (\(coordinates.count) times). Create a zone to automate profile changes?",
                        suggestedCoordinates: center,
                        createdAt: Date()
                    )
                    
                    logger.info("Generated zone creation suggestion for new location")
                    return .zoneCreation(suggestion)
                }
            }
        } catch {
            logger.error("Failed to check existing zones: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // MARK: - Zone Deletion Suggestions
    
    /// Generate suggestions for zone deletion based on inactivity
    /// - Returns: ZoneDeletionSuggestion if zones are inactive
    private func generateZoneDeletionSuggestion() -> Suggestion? {
        do {
            let zones = try database.getAllZones()
            
            let now = Date()
            let cutoffDate = calendar.date(byAdding: .day, value: -SuggestionGenerator.zoneInactivityDays, to: now) ?? now
            
            for zone in zones {
                guard let pattern = patternTracker.getPattern(for: zone.id) else {
                    // No pattern data - might be good candidate for deletion
                    let suggestion = ZoneDeletionSuggestion(
                        id: UUID(),
                        zoneId: zone.id,
                        zoneName: zone.name,
                        reason: "No visit data recorded for \(zone.name). This zone may no longer be relevant.",
                        lastVisitDate: nil,
                        inactivityDays: nil,
                        createdAt: Date()
                    )
                    
                    logger.info("Generated zone deletion suggestion for \(zone.name) (no data)")
                    return .zoneDeletion(suggestion)
                }
                
                // Check last visit date
                guard let lastDate = pattern.dates.last else {
                    continue
                }
                
                if lastDate < cutoffDate {
                    let inactivityDays = Int(now.timeIntervalSince(lastDate) / (24 * 60 * 60))
                    
                    let suggestion = ZoneDeletionSuggestion(
                        id: UUID(),
                        zoneId: zone.id,
                        zoneName: zone.name,
                        reason: "You haven't visited \(zone.name) in \(inactivityDays) days. Consider removing this zone to keep your list up to date.",
                        lastVisitDate: lastDate,
                        inactivityDays: inactivityDays,
                        createdAt: Date()
                    )
                    
                    logger.info("Generated zone deletion suggestion for \(zone.name) (\(inactivityDays) days inactive)")
                    return .zoneDeletion(suggestion)
                }
            }
        } catch {
            logger.error("Failed to generate zone deletion suggestion: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // MARK: - Utility Methods
    
    /// Calculate centroid of coordinates
    private func calculateCentroid(_ coordinates: [(latitude: Double, longitude: Double)]) -> (latitude: Double, longitude: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0)
        }
        
        let sumLat = coordinates.reduce(0.0) { $0 + $1.latitude }
        let sumLon = coordinates.reduce(0.0) { $0 + $1.longitude }
        
        return (latitude: sumLat / Double(coordinates.count), longitude: sumLon / Double(coordinates.count))
    }
    
    /// Calculate distance between two coordinates using Haversine formula
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius: Double = 6371000 // meters
        
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let deltaLat = (lat2 - lat1) * .pi / 180
        let deltaLon = (lon2 - lon1) * .pi / 180
        
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                 cos(lat1Rad) * cos(lat2Rad) *
                 sin(deltaLon / 2) * sin(deltaLon / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadius * c
    }
    
    // MARK: - Bulk Analysis
    
    /// Generate all available suggestions (bypasses rate limit, for testing/admin)
    /// - Returns: Array of all possible suggestions
    public func generateAllSuggestions() -> [Suggestion] {
        var suggestions: [Suggestion] = []
        
        if let profileSuggestion = generateProfileChangeSuggestion() {
            suggestions.append(profileSuggestion)
        }
        
        if let zoneCreationSuggestion = generateZoneCreationSuggestion() {
            suggestions.append(zoneCreationSuggestion)
        }
        
        if let zoneDeletionSuggestion = generateZoneDeletionSuggestion() {
            suggestions.append(zoneDeletionSuggestion)
        }
        
        return suggestions
    }
}

// MARK: - Suggestion Types

/// Container for all suggestion types
public enum Suggestion: Identifiable {
    case profileChange(ProfileChangeSuggestion)
    case zoneCreation(ZoneCreationSuggestion)
    case zoneDeletion(ZoneDeletionSuggestion)
    
    public var id: UUID {
        switch self {
        case .profileChange(let s): return s.id
        case .zoneCreation(let s): return s.id
        case .zoneDeletion(let s): return s.id
        }
    }
    
    public var type: SuggestionType {
        switch self {
        case .profileChange: return .profileChange
        case .zoneCreation: return .zoneCreation
        case .zoneDeletion: return .zoneDeletion
        }
    }
    
    public var message: String {
        switch self {
        case .profileChange(let s): return s.reason
        case .zoneCreation(let s): return s.reason
        case .zoneDeletion(let s): return s.reason
        }
    }
    
    public var createdAt: Date {
        switch self {
        case .profileChange(let s): return s.createdAt
        case .zoneCreation(let s): return s.createdAt
        case .zoneDeletion(let s): return s.createdAt
        }
    }
}

public enum SuggestionType: String, Codable {
    case profileChange
    case zoneCreation
    case zoneDeletion
}

/// Suggestion to change profile settings based on deviation patterns
public struct ProfileChangeSuggestion: Identifiable {
    public let id: UUID
    public let zoneId: UUID
    public let zoneName: String
    public let currentProfileName: String
    public let currentProfile: Profile?
    public let suggestedSetting: ProfileSetting
    public let reason: String
    public let deviation: DeviationResult
    public let createdAt: Date
    
    public init(
        id: UUID,
        zoneId: UUID,
        zoneName: String,
        currentProfileName: String,
        currentProfile: Profile?,
        suggestedSetting: ProfileSetting,
        reason: String,
        deviation: DeviationResult,
        createdAt: Date
    ) {
        self.id = id
        self.zoneId = zoneId
        self.zoneName = zoneName
        self.currentProfileName = currentProfileName
        self.currentProfile = currentProfile
        self.suggestedSetting = suggestedSetting
        self.reason = reason
        self.deviation = deviation
        self.createdAt = createdAt
    }
}

/// Suggestion to create a new zone based on frequent visits
public struct ZoneCreationSuggestion: Identifiable {
    public let id: UUID
    public let suggestedName: String
    public let latitude: Double
    public let longitude: Double
    public let radius: Double
    public let visitCount: Int
    public let reason: String
    public let suggestedCoordinates: (latitude: Double, longitude: Double)
    public let createdAt: Date
    
    public init(
        id: UUID,
        suggestedName: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        visitCount: Int,
        reason: String,
        suggestedCoordinates: (latitude: Double, longitude: Double),
        createdAt: Date
    ) {
        self.id = id
        self.suggestedName = suggestedName
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.visitCount = visitCount
        self.reason = reason
        self.suggestedCoordinates = suggestedCoordinates
        self.createdAt = createdAt
    }
}

/// Suggestion to delete an inactive zone
public struct ZoneDeletionSuggestion: Identifiable {
    public let id: UUID
    public let zoneId: UUID
    public let zoneName: String
    public let reason: String
    public let lastVisitDate: Date?
    public let inactivityDays: Int?
    public let createdAt: Date
    
    public init(
        id: UUID,
        zoneId: UUID,
        zoneName: String,
        reason: String,
        lastVisitDate: Date?,
        inactivityDays: Int?,
        createdAt: Date
    ) {
        self.id = id
        self.zoneId = zoneId
        self.zoneName = zoneName
        self.reason = reason
        self.lastVisitDate = lastVisitDate
        self.inactivityDays = inactivityDays
        self.createdAt = createdAt
    }
}
