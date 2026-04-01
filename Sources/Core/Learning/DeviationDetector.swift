// Core/Learning/DeviationDetector.swift
import Foundation

/// DeviationDetector analyzes pattern data to detect anomalies in zone visits.
/// Uses statistical analysis (mean, standard deviation) to identify deviations
/// beyond the configured threshold (default 30 minutes).
public final class DeviationDetector {
    
    // MARK: - Configuration
    
    /// Threshold for deviation detection in seconds (default: 30 minutes = 1800 seconds)
    public static let defaultDeviationThreshold: TimeInterval = 1800
    
    /// Minimum number of visits required before making predictions
    public static let minimumDataThreshold: Int = 5
    
    // MARK: - Singleton
    
    public static let shared = DeviationDetector()
    
    // MARK: - Properties
    
    private let patternTracker = PatternTracker.shared
    private let logger = Logger.shared
    private let calendar = Calendar.current
    
    /// Configurable deviation threshold in seconds
    public var deviationThreshold: TimeInterval = DeviationDetector.defaultDeviationThreshold
    
    /// Minimum visits required for analysis
    public var minimumVisits: Int = DeviationDetector.minimumDataThreshold
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Statistical Calculations
    
    /// Calculate mean of an array of values
    /// - Parameter values: Array of TimeInterval values
    /// - Returns: Mean value, or nil if array is empty
    public func calculateMean(_ values: [TimeInterval]) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let total = values.reduce(0, +)
        return total / Double(values.count)
    }
    
    /// Calculate standard deviation of an array of values
    /// - Parameters:
    ///   - values: Array of TimeInterval values
    ///   - mean: Pre-calculated mean (optional, will be calculated if not provided)
    /// - Returns: Standard deviation, or nil if insufficient data
    public func calculateStandardDeviation(_ values: [TimeInterval], mean: TimeInterval? = nil) -> TimeInterval? {
        guard values.count >= 2 else { return nil }
        
        let calculatedMean = mean ?? calculateMean(values)
        guard let avg = calculatedMean else { return nil }
        
        let squaredDiffs = values.map { pow($0 - avg, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
    
    // MARK: - Entry Time Analysis
    
    /// Convert a Date to seconds from midnight
    /// - Parameter date: The date to convert
    /// - Returns: Seconds elapsed since midnight (0-86399)
    public func secondsFromMidnight(for date: Date) -> TimeInterval {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hours = TimeInterval(components.hour ?? 0) * 3600
        let minutes = TimeInterval(components.minute ?? 0) * 60
        let seconds = TimeInterval(components.second ?? 0)
        return hours + minutes + seconds
    }
    
    /// Calculate mean entry time (as seconds from midnight)
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: Mean entry time in seconds from midnight, or nil if insufficient data
    public func getMeanEntryTime(for zoneId: UUID) -> TimeInterval? {
        guard let pattern = patternTracker.getPattern(for: zoneId),
              pattern.entryTimes.count >= minimumVisits else {
            return nil
        }
        
        let entrySeconds = pattern.entryTimes.map { secondsFromMidnight(for: $0) }
        return calculateMean(entrySeconds)
    }
    
    /// Calculate standard deviation of entry times (as seconds from midnight)
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: Standard deviation in seconds, or nil if insufficient data
    public func getEntryTimeStdDev(for zoneId: UUID) -> TimeInterval? {
        guard let pattern = patternTracker.getPattern(for: zoneId),
              pattern.entryTimes.count >= minimumVisits else {
            return nil
        }
        
        let entrySeconds = pattern.entryTimes.map { secondsFromMidnight(for: $0) }
        let mean = calculateMean(entrySeconds)
        return calculateStandardDeviation(entrySeconds, mean: mean)
    }
    
    // MARK: - Duration Analysis
    
    /// Calculate mean duration for a zone
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: Mean duration in seconds, or nil if insufficient data
    public func getMeanDuration(for zoneId: UUID) -> TimeInterval? {
        guard let pattern = patternTracker.getPattern(for: zoneId),
              pattern.durations.count >= minimumVisits else {
            return nil
        }
        
        return calculateMean(pattern.durations)
    }
    
    /// Calculate standard deviation of durations for a zone
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: Standard deviation in seconds, or nil if insufficient data
    public func getDurationStdDev(for zoneId: UUID) -> TimeInterval? {
        guard let pattern = patternTracker.getPattern(for: zoneId),
              pattern.durations.count >= minimumVisits else {
            return nil
        }
        
        let mean = calculateMean(pattern.durations)
        return calculateStandardDeviation(pattern.durations, mean: mean)
    }
    
    // MARK: - Day of Week Analysis
    
    /// Get mean entry time for weekday or weekend
    /// - Parameters:
    ///   - zoneId: The UUID of the zone
    ///   - isWeekday: true for weekday (Mon-Fri), false for weekend (Sat-Sun)
    /// - Returns: Mean entry time in seconds from midnight, or nil if insufficient data
    public func getMeanEntryTime(for zoneId: UUID, isWeekday: Bool) -> TimeInterval? {
        guard let pattern = patternTracker.getDayOfWeekPattern(for: zoneId, isWeekday: isWeekday),
              pattern.entryTimes.count >= minimumVisits else {
            return nil
        }
        
        let entrySeconds = pattern.entryTimes.map { secondsFromMidnight(for: $0) }
        return calculateMean(entrySeconds)
    }
    
    /// Get entry time standard deviation for weekday or weekend
    /// - Parameters:
    ///   - zoneId: The UUID of the zone
    ///   - isWeekday: true for weekday (Mon-Fri), false for weekend (Sat-Sun)
    /// - Returns: Standard deviation in seconds, or nil if insufficient data
    public func getEntryTimeStdDev(for zoneId: UUID, isWeekday: Bool) -> TimeInterval? {
        guard let pattern = patternTracker.getDayOfWeekPattern(for: zoneId, isWeekday: isWeekday),
              pattern.entryTimes.count >= minimumVisits else {
            return nil
        }
        
        let entrySeconds = pattern.entryTimes.map { secondsFromMidnight(for: $0) }
        let mean = calculateMean(entrySeconds)
        return calculateStandardDeviation(entrySeconds, mean: mean)
    }
    
    /// Get mean duration for weekday or weekend
    /// - Parameters:
    ///   - zoneId: The UUID of the zone
    ///   - isWeekday: true for weekday (Mon-Fri), false for weekend (Sat-Sun)
    /// - Returns: Mean duration in seconds, or nil if insufficient data
    public func getMeanDuration(for zoneId: UUID, isWeekday: Bool) -> TimeInterval? {
        guard let pattern = patternTracker.getDayOfWeekPattern(for: zoneId, isWeekday: isWeekday),
              pattern.durations.count >= minimumVisits else {
            return nil
        }
        
        return calculateMean(pattern.durations)
    }
    
    /// Get duration standard deviation for weekday or weekend
    /// - Parameters:
    ///   - zoneId: The UUID of the zone
    ///   - isWeekday: true for weekday (Mon-Fri), false for weekend (Sat-Sun)
    /// - Returns: Standard deviation in seconds, or nil if insufficient data
    public func getDurationStdDev(for zoneId: UUID, isWeekday: Bool) -> TimeInterval? {
        guard let pattern = patternTracker.getDayOfWeekPattern(for: zoneId, isWeekday: isWeekday),
              pattern.durations.count >= minimumVisits else {
            return nil
        }
        
        let mean = calculateMean(pattern.durations)
        return calculateStandardDeviation(pattern.durations, mean: mean)
    }
    
    // MARK: - Deviation Detection
    
    /// Check if current entry time deviates from expected pattern
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: DeviationResult with details, or nil if insufficient data
    public func detectEntryTimeDeviation(for zoneId: UUID) -> DeviationResult? {
        guard let pattern = patternTracker.getPattern(for: zoneId),
              pattern.entryTimes.count >= minimumVisits else {
            logger.debug("Insufficient data for deviation detection on zone \(zoneId.uuidString)")
            return nil
        }
        
        // Get current day type
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let isWeekday = weekday >= 2 && weekday <= 6
        
        // Get mean and stddev for appropriate day type
        let mean = isWeekday 
            ? getMeanEntryTime(for: zoneId, isWeekday: true)
            : getMeanEntryTime(for: zoneId, isWeekday: false)
        
        let stdDev = isWeekday
            ? getEntryTimeStdDev(for: zoneId, isWeekday: true)
            : getEntryTimeStdDev(for: zoneId, isWeekday: false)
        
        guard let avg = mean, let sd = stdDev else {
            return nil
        }
        
        let currentSeconds = secondsFromMidnight(for: now)
        let deviation = abs(currentSeconds - avg)
        
        let exceedsThreshold = deviation > deviationThreshold
        let warningLevel: WarningLevel = deviation > deviationThreshold * 1.5 ? .high 
            : deviation > deviationThreshold ? .medium 
            : .normal
        
        logger.info("Entry time deviation for zone \(zoneId.uuidString): \(deviation)s (threshold: \(deviationThreshold)s)")
        
        return DeviationResult(
            zoneId: zoneId,
            deviationType: .entryTime,
            expectedValue: avg,
            actualValue: currentSeconds,
            deviation: deviation,
            deviationThreshold: deviationThreshold,
            exceedsThreshold: exceedsThreshold,
            warningLevel: warningLevel,
            sampleCount: pattern.entryTimes.count,
            dayType: isWeekday ? .weekday : .weekend
        )
    }
    
    /// Check if current duration deviates from expected pattern
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: DeviationResult with details, or nil if insufficient data
    public func detectDurationDeviation(for zoneId: UUID) -> DeviationResult? {
        guard let pattern = patternTracker.getPattern(for: zoneId),
              pattern.durations.count >= minimumVisits else {
            logger.debug("Insufficient duration data for deviation detection on zone \(zoneId.uuidString)")
            return nil
        }
        
        // Get current day type
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let isWeekday = weekday >= 2 && weekday <= 6
        
        // Get mean and stddev for appropriate day type
        let mean = isWeekday 
            ? getMeanDuration(for: zoneId, isWeekday: true)
            : getMeanDuration(for: zoneId, isWeekday: false)
        
        let stdDev = isWeekday
            ? getDurationStdDev(for: zoneId, isWeekday: true)
            : getDurationStdDev(for: zoneId, isWeekday: false)
        
        guard let avg = mean, let sd = stdDev else {
            return nil
        }
        
        // Calculate current duration from pending entry if exists
        guard let pendingEntry = getCurrentDuration(for: zoneId) else {
            return nil
        }
        
        let deviation = abs(pendingEntry - avg)
        
        let exceedsThreshold = deviation > deviationThreshold
        let warningLevel: WarningLevel = deviation > deviationThreshold * 1.5 ? .high 
            : deviation > deviationThreshold ? .medium 
            : .normal
        
        logger.info("Duration deviation for zone \(zoneId.uuidString): \(deviation)s (threshold: \(deviationThreshold)s)")
        
        return DeviationResult(
            zoneId: zoneId,
            deviationType: .duration,
            expectedValue: avg,
            actualValue: pendingEntry,
            deviation: deviation,
            deviationThreshold: deviationThreshold,
            exceedsThreshold: exceedsThreshold,
            warningLevel: warningLevel,
            sampleCount: pattern.durations.count,
            dayType: isWeekday ? .weekday : .weekend
        )
    }
    
    /// Get current duration for an active zone entry
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: Current duration in seconds, or nil if no active entry
    private func getCurrentDuration(for zoneId: UUID) -> TimeInterval? {
        // Check pending entries for current duration
        guard patternTracker.hasPendingEntry(for: zoneId) else {
            return nil
        }
        
        // This requires tracking entry time - for now return nil
        // In production, you'd query pendingEntries from PatternTracker
        return nil
    }
    
    /// Check both entry time and duration deviations
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: Array of DeviationResult (may be empty if no deviations or insufficient data)
    public func detectAllDeviations(for zoneId: UUID) -> [DeviationResult] {
        var results: [DeviationResult] = []
        
        if let entryResult = detectEntryTimeDeviation(for: zoneId) {
            results.append(entryResult)
        }
        
        if let durationResult = detectDurationDeviation(for: zoneId) {
            results.append(durationResult)
        }
        
        return results
    }
    
    /// Get comprehensive statistics for a zone
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: PatternStatistics, or nil if insufficient data
    public func getStatistics(for zoneId: UUID) -> PatternStatistics? {
        guard let pattern = patternTracker.getPattern(for: zoneId),
              pattern.entryTimes.count >= minimumVisits else {
            return nil
        }
        
        let weekday = calendar.component(.weekday, from: Date())
        let isWeekday = weekday >= 2 && weekday <= 6
        
        return PatternStatistics(
            zoneId: zoneId,
            totalVisits: pattern.entryTimes.count,
            weekdayStats: isWeekday ? calculateStatistics(for: zoneId, isWeekday: true) : nil,
            weekendStats: !isWeekday ? calculateStatistics(for: zoneId, isWeekday: false) : nil,
            overallEntryMean: getMeanEntryTime(for: zoneId),
            overallEntryStdDev: getEntryTimeStdDev(for: zoneId),
            overallDurationMean: getMeanDuration(for: zoneId),
            overallDurationStdDev: getDurationStdDev(for: zoneId)
        )
    }
    
    /// Calculate statistics for a specific day type
    private func calculateStatistics(for zoneId: UUID, isWeekday: Bool) -> DayTypeStatistics? {
        guard let pattern = patternTracker.getDayOfWeekPattern(for: zoneId, isWeekday: isWeekday),
              pattern.entryTimes.count >= minimumVisits else {
            return nil
        }
        
        return DayTypeStatistics(
            isWeekday: isWeekday,
            visitCount: pattern.entryTimes.count,
            meanEntryTime: getMeanEntryTime(for: zoneId, isWeekday: isWeekday),
            entryTimeStdDev: getEntryTimeStdDev(for: zoneId, isWeekday: isWeekday),
            meanDuration: getMeanDuration(for: zoneId, isWeekday: isWeekday),
            durationStdDev: getDurationStdDev(for: zoneId, isWeekday: isWeekday)
        )
    }
    
    /// Check if sufficient data exists for analysis
    /// - Parameter zoneId: The UUID of the zone
    /// - Returns: true if enough data for deviation detection
    public func hasSufficientData(for zoneId: UUID) -> Bool {
        guard let pattern = patternTracker.getPattern(for: zoneId) else {
            return false
        }
        return pattern.entryTimes.count >= minimumVisits
    }
    
    /// Get minimum visits threshold
    /// - Returns: Minimum number of visits required
    public func getMinimumVisits() -> Int {
        return minimumVisits
    }
}

// MARK: - Supporting Types

public enum DeviationType: String, Codable {
    case entryTime
    case duration
}

public enum DayType: String, Codable {
    case weekday
    case weekend
}

public enum WarningLevel: String, Codable {
    case normal
    case medium
    case high
}

/// Result of a deviation detection analysis
public struct DeviationResult {
    public let zoneId: UUID
    public let deviationType: DeviationType
    public let expectedValue: TimeInterval
    public let actualValue: TimeInterval
    public let deviation: TimeInterval
    public let deviationThreshold: TimeInterval
    public let exceedsThreshold: Bool
    public let warningLevel: WarningLevel
    public let sampleCount: Int
    public let dayType: DayType
    
    public init(
        zoneId: UUID,
        deviationType: DeviationType,
        expectedValue: TimeInterval,
        actualValue: TimeInterval,
        deviation: TimeInterval,
        deviationThreshold: TimeInterval,
        exceedsThreshold: Bool,
        warningLevel: WarningLevel,
        sampleCount: Int,
        dayType: DayType
    ) {
        self.zoneId = zoneId
        self.deviationType = deviationType
        self.expectedValue = expectedValue
        self.actualValue = actualValue
        self.deviation = deviation
        self.deviationThreshold = deviationThreshold
        self.exceedsThreshold = exceedsThreshold
        self.warningLevel = warningLevel
        self.sampleCount = sampleCount
        self.dayType = dayType
    }
    
    /// Human-readable description of the deviation
    public var description: String {
        let typeLabel = deviationType == .entryTime ? "entry time" : "duration"
        let deviationMinutes = deviation / 60
        let thresholdMinutes = deviationThreshold / 60
        
        if exceedsThreshold {
            return "⚠️ \(typeLabel) deviation: \(String(format: "%.1f", deviationMinutes))min (threshold: \(String(format: "%.1f", thresholdMinutes))min)"
        } else {
            return "✅ \(typeLabel) within normal range: \(String(format: "%.1f", deviationMinutes))min"
        }
    }
}

/// Statistics for a specific day type (weekday or weekend)
public struct DayTypeStatistics {
    public let isWeekday: Bool
    public let visitCount: Int
    public let meanEntryTime: TimeInterval?
    public let entryTimeStdDev: TimeInterval?
    public let meanDuration: TimeInterval?
    public let durationStdDev: TimeInterval?
}

/// Comprehensive pattern statistics for a zone
public struct PatternStatistics {
    public let zoneId: UUID
    public let totalVisits: Int
    public let weekdayStats: DayTypeStatistics?
    public let weekendStats: DayTypeStatistics?
    public let overallEntryMean: TimeInterval?
    public let overallEntryStdDev: TimeInterval?
    public let overallDurationMean: TimeInterval?
    public let overallDurationStdDev: TimeInterval?
}