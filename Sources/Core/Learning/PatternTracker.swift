// Core/Learning/PatternTracker.swift
import Foundation

/// PatternTracker tracks zone entry/exit timestamps and calculates duration patterns.
/// Maintains historical data for day-of-week pattern analysis.
public final class PatternTracker {
    
    // MARK: - Singleton
    
    public static let shared = PatternTracker()
    
    // MARK: - Properties
    
    private let database = DatabaseManager.shared
    private let logger = Logger.shared
    private let calendar = Calendar.current
    
    /// Tracks pending entry times (zoneId -> entry timestamp)
    private var pendingEntries: [UUID: Date] = [:]
    
    /// Lock for thread-safe access to pendingEntries
    private let pendingEntriesLock = NSLock()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public API
    
    /// Record a zone entry with current timestamp
    /// - Parameter zoneId: The UUID of the zone that was entered
    public func recordEntry(zoneId: UUID) {
        let now = Date()
        
        pendingEntriesLock.lock()
        pendingEntries[zoneId] = now
        pendingEntriesLock.unlock()
        
        // Also update the pattern's entry times in database
        do {
            var pattern = try database.getPattern(zoneId: zoneId) ?? Pattern(zoneId: zoneId)
            pattern.entryTimes.append(now)
            // Add date to track which days have activity
            if !pattern.dates.contains(where: { calendar.isDate($0, inSameDayAs: now) }) {
                pattern.dates.append(now)
            }
            try database.savePattern(pattern)
            logger.info("Recorded entry for zone \(zoneId.uuidString)")
        } catch {
            logger.error("Failed to record entry for zone \(zoneId.uuidString): \(error.localizedDescription)")
        }
    }
    
    /// Record a zone exit with current timestamp and calculate duration
    /// - Parameter zoneId: The UUID of the zone that was exited
    public func recordExit(zoneId: UUID) {
        let now = Date()
        
        // Calculate duration from pending entry
        pendingEntriesLock.lock()
        let entryTime = pendingEntries.removeValue(forKey: zoneId)
        pendingEntriesLock.unlock()
        
        do {
            var pattern = try database.getPattern(zoneId: zoneId) ?? Pattern(zoneId: zoneId)
            pattern.exitTimes.append(now)
            
            // Calculate duration if we have a matching entry
            if let entry = entryTime {
                let duration = now.timeIntervalSince(entry)
                pattern.durations.append(duration)
                logger.info("Recorded exit for zone \(zoneId.uuidString), duration: \(duration)s")
            } else {
                logger.warning("No matching entry found for zone \(zoneId.uuidString) exit")
            }
            
            try database.savePattern(pattern)
        } catch {
            logger.error("Failed to record exit for zone \(zoneId.uuidString): \(error.localizedDescription)")
        }
    }
    
    /// Get the overall pattern for a specific zone
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: Pattern if exists, nil otherwise
    public func getPattern(for zoneId: UUID) -> Pattern? {
        do {
            return try database.getPattern(zoneId: zoneId)
        } catch {
            logger.error("Failed to get pattern for zone \(zoneId.uuidString): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get pattern filtered by day-of-week type (weekday vs weekend)
    /// - Parameters:
    ///   - zoneId: The UUID of the zone
    ///   - isWeekday: true for weekday pattern, false for weekend pattern
    /// - Returns: Pattern with filtered times/durations for the day type
    public func getDayOfWeekPattern(for zoneId: UUID, isWeekday: Bool) -> Pattern? {
        guard let pattern = getPattern(for: zoneId) else {
            return nil
        }
        
        // Filter entry/exit times and durations by day of week
        var filteredEntryTimes: [Date] = []
        var filteredExitTimes: [Date] = []
        var filteredDurations: [TimeInterval] = []
        
        let weekdayPredicate: (Date) -> Bool = isWeekday ? { date in
            let weekday = self.calendar.component(.weekday, from: date)
            return weekday >= 2 && weekday <= 6 // Monday = 2, Saturday = 7
        } : { date in
            let weekday = self.calendar.component(.weekday, from: date)
            return weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
        }
        
        // Match entry times with corresponding durations
        for (index, entryTime) in pattern.entryTimes.enumerated() {
            if weekdayPredicate(entryTime) {
                filteredEntryTimes.append(entryTime)
                // Get corresponding duration if available
                if index < pattern.durations.count {
                    filteredDurations.append(pattern.durations[index])
                }
            }
        }
        
        // Filter exit times
        for exitTime in pattern.exitTimes {
            if weekdayPredicate(exitTime) {
                filteredExitTimes.append(exitTime)
            }
        }
        
        return Pattern(
            zoneId: zoneId,
            entryTimes: filteredEntryTimes,
            exitTimes: filteredExitTimes,
            durations: filteredDurations,
            dates: pattern.dates.filter(weekdayPredicate)
        )
    }
    
    /// Clean up old pattern data
    /// - Parameter days: Remove data older than this many days
    public func cleanupOldData(olderThan days: Int) {
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        do {
            let allZones = try database.getAllZones()
            for zone in allZones {
                if var pattern = try database.getPattern(zoneId: zone.id) {
                    // Filter entry times
                    pattern.entryTimes = pattern.entryTimes.filter { $0 > cutoffDate }
                    // Filter exit times
                    pattern.exitTimes = pattern.exitTimes.filter { $0 > cutoffDate }
                    // Filter durations (based on corresponding entry dates)
                    var filteredDurations: [TimeInterval] = []
                    for (index, entryTime) in pattern.entryTimes.enumerated() {
                        if entryTime > cutoffDate && index < pattern.durations.count {
                            filteredDurations.append(pattern.durations[index])
                        }
                    }
                    pattern.durations = filteredDurations
                    // Filter dates
                    pattern.dates = pattern.dates.filter { $0 > cutoffDate }
                    
                    try database.savePattern(pattern)
                    logger.info("Cleaned up old data for zone \(zone.id.uuidString)")
                }
            }
        } catch {
            logger.error("Failed to cleanup old data: \(error.localizedDescription)")
        }
    }
    
    /// Calculate average duration for a zone
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: Average duration in seconds, or nil if no data
    public func getAverageDuration(for zoneId: UUID) -> TimeInterval? {
        guard let pattern = getPattern(for: zoneId),
              !pattern.durations.isEmpty else {
            return nil
        }
        
        let total = pattern.durations.reduce(0, +)
        return total / Double(pattern.durations.count)
    }
    
    /// Calculate average duration for weekdays or weekends
    /// - Parameters:
    ///   - zoneId: The UUID of the zone
    ///   - isWeekday: true for weekday average, false for weekend average
    /// - Returns: Average duration in seconds, or nil if no data
    public func getAverageDuration(for zoneId: UUID, isWeekday: Bool) -> TimeInterval? {
        guard let pattern = getDayOfWeekPattern(for: zoneId, isWeekday: isWeekday),
              !pattern.durations.isEmpty else {
            return nil
        }
        
        let total = pattern.durations.reduce(0, +)
        return total / Double(pattern.durations.count)
    }
    
    /// Get total number of visits for a zone
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: Number of recorded visits
    public func getVisitCount(for zoneId: UUID) -> Int {
        guard let pattern = getPattern(for: zoneId) else {
            return 0
        }
        return pattern.entryTimes.count
    }
    
    /// Get the most frequent entry time pattern (hour of day)
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: Most common entry hour (0-23), or nil if no data
    public func getMostFrequentEntryHour(for zoneId: UUID) -> Int? {
        guard let pattern = getPattern(for: zoneId),
              !pattern.entryTimes.isEmpty else {
            return nil
        }
        
        var hourCounts: [Int: Int] = [:]
        for entryTime in pattern.entryTimes {
            let hour = calendar.component(.hour, from: entryTime)
            hourCounts[hour, default: 0] += 1
        }
        
        return hourCounts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Clear pending entry (for testing or reset)
    /// - Parameter zoneId: The UUID of the zone
    public func clearPendingEntry(for zoneId: UUID) {
        pendingEntriesLock.lock()
        pendingEntries.removeValue(forKey: zoneId)
        pendingEntriesLock.unlock()
    }
    
    /// Check if there's a pending entry for a zone
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: true if entry was recorded but not yet exited
    public func hasPendingEntry(for zoneId: UUID) -> Bool {
        pendingEntriesLock.lock()
        defer { pendingEntriesLock.unlock() }
        return pendingEntries[zoneId] != nil
    }
}