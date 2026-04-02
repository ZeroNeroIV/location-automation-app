// Core/Storage/DatabaseManager.swift
import Foundation
import SQLite

/// DatabaseManager handles all SQLite database operations for Zone, Profile, and Pattern persistence.
/// Cross-platform compatible (iOS + Android/Linux).
public final class DatabaseManager: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = DatabaseManager()
    
    // MARK: - Database Connection
    
    private var db: Connection?
    
    // MARK: - Table Definitions
    
    // Zones table
    private let zones = Table("zones")
    private let zoneId = Expression<String>("id")
    private let zoneName = Expression<String>("name")
    private let zoneLatitude = Expression<Double>("latitude")
    private let zoneLongitude = Expression<Double>("longitude")
    private let zoneRadius = Expression<Double>("radius")
    private let zoneDetectionMethods = Expression<String>("detection_methods")
    private let zoneProfileId = Expression<String>("profile_id")
    
    // Profiles table
    private let profiles = Table("profiles")
    private let profileId = Expression<String>("id")
    private let profileName = Expression<String>("name")
    private let profileRingtone = Expression<String>("ringtone")
    private let profileVibrate = Expression<String>("vibrate")
    private let profileUnmute = Expression<String>("unmute")
    private let profileDnd = Expression<String>("dnd")
    private let profileAlarms = Expression<String>("alarms")
    private let profileTimers = Expression<String>("timers")
    
    // Patterns table
    private let patterns = Table("patterns")
    private let patternZoneId = Expression<String>("zone_id")
    private let patternEntryTimes = Expression<String>("entry_times")
    private let patternExitTimes = Expression<String>("exit_times")
    private let patternDurations = Expression<String>("durations")
    private let patternDates = Expression<String>("dates")
    
    // MARK: - Error Types
    
    public enum DatabaseError: Error, LocalizedError {
        case connectionFailed
        case tableCreationFailed
        case notFound
        case encodingFailed
        case decodingFailed
        case storageFull
        case invalidData
        
        public var errorDescription: String? {
            switch self {
            case .connectionFailed:
                return "Failed to connect to database"
            case .tableCreationFailed:
                return "Failed to create database tables"
            case .notFound:
                return "Record not found"
            case .encodingFailed:
                return "Failed to encode data"
            case .decodingFailed:
                return "Failed to decode data"
            case .storageFull:
                return "Storage is full - please free up space"
            case .invalidData:
                return "Invalid data in database"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {}

    private let storageWarningThreshold: Double = 0.9
    private let maxDatabaseSizeMB: Double = 100.0
    public var onStorageWarning: ((String) -> Void)?

    public func checkStorageAvailability() -> Bool {
        guard let db = db else { return true }
        do {
            let pageCount = try db.scalar("PRAGMA page_count") as? Int64 ?? 0
            let pageSize = try db.scalar("PRAGMA page_size") as? Int64 ?? 4096
            let dbSizeMB = Double(pageCount * pageSize) / (1024 * 1024)
            if dbSizeMB > maxDatabaseSizeMB {
                onStorageWarning?("Database size (\(Int(dbSizeMB))MB) approaching limit")
                return false
            }
        } catch {
            return true
        }
        return true
    }

    public func getDatabaseSizeMB() -> Double {
        guard let db = db else { return 0 }
        do {
            let pageCount = try db.scalar("PRAGMA page_count") as? Int64 ?? 0
            let pageSize = try db.scalar("PRAGMA page_size") as? Int64 ?? 4096
            return Double(pageCount * pageSize) / (1024 * 1024)
        } catch {
            return 0
        }
    }

    public func cleanupOldData(keepRecentDays: Int = 30) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }
        let cutoffTime = Date().addingTimeInterval(-Double(keepRecentDays * 24 * 60 * 60)).timeIntervalSince1970
        try db.run(decisions.filter(decisionTimestamp < cutoffTime).delete())
    }

    public func getStorageStats() -> (decisionCount: Int, databaseSizeMB: Double) {
        guard let db = db else { return (0, 0) }
        let count = (try? db.scalar(decisions.count)) ?? 0
        return (Int(count), getDatabaseSizeMB())
    }
    
    // MARK: - Database Setup
    
    /// Initialize the database connection and create tables
    public func createTables() throws {
        let fileManager = FileManager.default
        
        // Determine database path based on platform
        #if os(iOS)
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = documentsPath.appendingPathComponent("location_automation.sqlite3").path
        #else
        // Linux/Android - use current directory or app data
        let dbPath = "location_automation.sqlite3"
        #endif
        
        do {
            db = try Connection(dbPath)
            try createTablesInternal()
        } catch {
            throw DatabaseError.connectionFailed
        }
    }
    
    private func createTablesInternal() throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        do {
            // Create zones table
            try db.run(zones.create(ifNotExists: true) { t in
                t.column(zoneId, primaryKey: true)
                t.column(zoneName)
                t.column(zoneLatitude)
                t.column(zoneLongitude)
                t.column(zoneRadius)
                t.column(zoneDetectionMethods)
                t.column(zoneProfileId)
            })
            
            // Create profiles table
            try db.run(profiles.create(ifNotExists: true) { t in
                t.column(profileId, primaryKey: true)
                t.column(profileName)
                t.column(profileRingtone)
                t.column(profileVibrate)
                t.column(profileUnmute)
                t.column(profileDnd)
                t.column(profileAlarms)
                t.column(profileTimers)
            })
            
            // Create patterns table
            try db.run(patterns.create(ifNotExists: true) { t in
                t.column(patternZoneId, primaryKey: true)
                t.column(patternEntryTimes)
                t.column(patternExitTimes)
                t.column(patternDurations)
                t.column(patternDates)
            })
        } catch {
            throw DatabaseError.tableCreationFailed
        }
    }
    
    // MARK: - Zone CRUD
    
    /// Create a new zone
    public func createZone(_ zone: Zone) throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let detectionMethodsJson = try JSONEncoder().encode(zone.detectionMethods)
        let detectionMethodsString = String(data: detectionMethodsJson, encoding: .utf8) ?? "[]"
        
        let insert = zones.insert(
            zoneId <- zone.id.uuidString,
            zoneName <- zone.name,
            zoneLatitude <- zone.latitude,
            zoneLongitude <- zone.longitude,
            zoneRadius <- zone.radius,
            zoneDetectionMethods <- detectionMethodsString,
            zoneProfileId <- zone.profileId.uuidString
        )
        
        try db.run(insert)
    }
    
    /// Get a zone by ID
    public func getZone(id: UUID) throws -> Zone? {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let query = zones.filter(zoneId == id.uuidString)
        
        guard let row = try db.pluck(query) else {
            return nil
        }
        
        return try rowToZone(row)
    }
    
    /// Get all zones
    public func getAllZones() throws -> [Zone] {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        var result: [Zone] = []
        
        for row in try db.prepare(zones) {
            if let zone = try? rowToZone(row) {
                result.append(zone)
            }
        }
        
        return result
    }
    
    /// Update an existing zone
    public func updateZone(_ zone: Zone) throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let detectionMethodsJson = try JSONEncoder().encode(zone.detectionMethods)
        let detectionMethodsString = String(data: detectionMethodsJson, encoding: .utf8) ?? "[]"
        
        let zoneToUpdate = zones.filter(zoneId == zone.id.uuidString)
        try db.run(zoneToUpdate.update(
            zoneName <- zone.name,
            zoneLatitude <- zone.latitude,
            zoneLongitude <- zone.longitude,
            zoneRadius <- zone.radius,
            zoneDetectionMethods <- detectionMethodsString,
            zoneProfileId <- zone.profileId.uuidString
        ))
    }
    
    /// Delete a zone by ID
    public func deleteZone(id: UUID) throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let zoneToDelete = zones.filter(zoneId == id.uuidString)
        try db.run(zoneToDelete.delete())
    }
    
    private func rowToZone(_ row: Row) throws -> Zone {
        let id = UUID(uuidString: row[zoneId])!
        let name: String = row[zoneName]
        let latitude: Double = row[zoneLatitude]
        let longitude: Double = row[zoneLongitude]
        let radius: Double = row[zoneRadius]
        let detectionMethodsString: String? = row[zoneDetectionMethods]
        let profileIdUuid = UUID(uuidString: row[zoneProfileId])!
        
        var detectionMethods: [DetectionMethod] = []
        if let dmStr = detectionMethodsString, let data = dmStr.data(using: String.Encoding.utf8) {
            detectionMethods = (try? JSONDecoder().decode([DetectionMethod].self, from: data)) ?? []
        }
        
        return try Zone(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            detectionMethods: detectionMethods,
            profileId: profileIdUuid
        )
    }
    
    // MARK: - Profile CRUD
    
    /// Create a new profile
    public func createProfile(_ profile: Profile) throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let insert = profiles.insert(
            profileId <- profile.id.uuidString,
            profileName <- profile.name,
            profileRingtone <- profile.ringtone.rawValue,
            profileVibrate <- profile.vibrate.rawValue,
            profileUnmute <- profile.unmute.rawValue,
            profileDnd <- profile.dnd.rawValue,
            profileAlarms <- profile.alarms.rawValue,
            profileTimers <- profile.timers.rawValue
        )
        
        try db.run(insert)
    }
    
    /// Get a profile by ID
    public func getProfile(id: UUID) throws -> Profile? {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let query = profiles.filter(profileId == id.uuidString)
        
        guard let row = try db.pluck(query) else {
            return nil
        }
        
        return rowToProfile(row)
    }
    
    /// Get all profiles
    public func getAllProfiles() throws -> [Profile] {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        var result: [Profile] = []
        
        for row in try db.prepare(profiles) {
            let profile = rowToProfile(row)
            result.append(profile)
        }
        
        return result
    }
    
    /// Update an existing profile
    public func updateProfile(_ profile: Profile) throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let profileToUpdate = profiles.filter(profileId == profile.id.uuidString)
        try db.run(profileToUpdate.update(
            profileName <- profile.name,
            profileRingtone <- profile.ringtone.rawValue,
            profileVibrate <- profile.vibrate.rawValue,
            profileUnmute <- profile.unmute.rawValue,
            profileDnd <- profile.dnd.rawValue,
            profileAlarms <- profile.alarms.rawValue,
            profileTimers <- profile.timers.rawValue
        ))
    }
    
    /// Delete a profile by ID
    public func deleteProfile(id: UUID) throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let profileToDelete = profiles.filter(profileId == id.uuidString)
        try db.run(profileToDelete.delete())
    }
    
    private func rowToProfile(_ row: Row) -> Profile {
        return Profile(
            id: UUID(uuidString: row[profileId])!,
            name: row[profileName],
            ringtone: ProfileSetting(rawValue: row[profileRingtone]) ?? .off,
            vibrate: ProfileSetting(rawValue: row[profileVibrate]) ?? .off,
            unmute: ProfileSetting(rawValue: row[profileUnmute]) ?? .off,
            dnd: ProfileSetting(rawValue: row[profileDnd]) ?? .off,
            alarms: ProfileSetting(rawValue: row[profileAlarms]) ?? .on,
            timers: ProfileSetting(rawValue: row[profileTimers]) ?? .on
        )
    }
    
    // MARK: - Pattern Persistence
    
    /// Save or update a pattern for a zone
    public func savePattern(_ pattern: Pattern) throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let entryTimesJson = try JSONEncoder().encode(pattern.entryTimes)
        let exitTimesJson = try JSONEncoder().encode(pattern.exitTimes)
        let durationsJson = try JSONEncoder().encode(pattern.durations)
        let datesJson = try JSONEncoder().encode(pattern.dates)
        
        let entryTimesString = String(data: entryTimesJson, encoding: .utf8) ?? "[]"
        let exitTimesString = String(data: exitTimesJson, encoding: .utf8) ?? "[]"
        let durationsString = String(data: durationsJson, encoding: .utf8) ?? "[]"
        let datesString = String(data: datesJson, encoding: .utf8) ?? "[]"
        
        // Use upsert (INSERT OR REPLACE) for save/update behavior
        let insert = patterns.insert(or: .replace,
            patternZoneId <- pattern.zoneId.uuidString,
            patternEntryTimes <- entryTimesString,
            patternExitTimes <- exitTimesString,
            patternDurations <- durationsString,
            patternDates <- datesString
        )
        
        try db.run(insert)
    }
    
    /// Get a pattern for a specific zone
    public func getPattern(zoneId: UUID) throws -> Pattern? {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let query = patterns.filter(patternZoneId == zoneId.uuidString)
        
        guard let row = try db.pluck(query) else {
            return nil
        }
        
        return try rowToPattern(row)
    }
    
    /// Get all patterns for a specific zone
    public func getPatternsForZone(zoneId: UUID) throws -> [Pattern] {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let query = patterns.filter(patternZoneId == zoneId.uuidString)
        
        var result: [Pattern] = []
        
        for row in try db.prepare(query) {
            if let pattern = try? rowToPattern(row) {
                result.append(pattern)
            }
        }
        
        return result
    }
    
    /// Delete a pattern for a zone
    public func deletePattern(zoneId: UUID) throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let patternToDelete = patterns.filter(patternZoneId == zoneId.uuidString)
        try db.run(patternToDelete.delete())
    }
    
    private func rowToPattern(_ row: Row) throws -> Pattern {
        let zoneIdUuid = UUID(uuidString: row[patternZoneId])!
        
        var entryTimes: [Date] = []
        var exitTimes: [Date] = []
        var durations: [TimeInterval] = []
        var dates: [Date] = []
        
        if let entryStr: String = row[patternEntryTimes] {
            if let data = entryStr.data(using: String.Encoding.utf8) {
                entryTimes = (try? JSONDecoder().decode([Date].self, from: data)) ?? []
            }
        }
        if let exitStr: String = row[patternExitTimes] {
            if let data = exitStr.data(using: String.Encoding.utf8) {
                exitTimes = (try? JSONDecoder().decode([Date].self, from: data)) ?? []
            }
        }
        if let durationStr: String = row[patternDurations] {
            if let data = durationStr.data(using: String.Encoding.utf8) {
                durations = (try? JSONDecoder().decode([TimeInterval].self, from: data)) ?? []
            }
        }
        if let datesStr: String = row[patternDates] {
            if let data = datesStr.data(using: String.Encoding.utf8) {
                dates = (try? JSONDecoder().decode([Date].self, from: data)) ?? []
            }
        }
        
        return Pattern(
            zoneId: zoneIdUuid,
            entryTimes: entryTimes,
            exitTimes: exitTimes,
            durations: durations,
            dates: dates
        )
    }
    
    // MARK: - Decision History
    
    private let decisions = Table("suggestion_decisions")
    private let decisionId = Expression<String>("id")
    private let decisionSuggestionId = Expression<String>("suggestion_id")
    private let decisionSuggestionType = Expression<String>("suggestion_type")
    private let decisionType = Expression<String>("decision_type")
    private let decisionTimestamp = Expression<Double>("timestamp")
    private let decisionMessage = Expression<String>("suggestion_message")
    
    public func createDecisionHistoryTableIfNeeded() throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let createSQL = """
            CREATE TABLE IF NOT EXISTS suggestion_decisions (
                id TEXT PRIMARY KEY,
                suggestion_id TEXT NOT NULL,
                suggestion_type TEXT NOT NULL,
                decision_type TEXT NOT NULL,
                timestamp REAL NOT NULL,
                suggestion_message TEXT NOT NULL
            )
            """
        try db.execute(createSQL)
    }
    
    public func saveDecision(_ decision: SuggestionDecision) throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let insert = decisions.insert(
            decisionId <- decision.id.uuidString,
            decisionSuggestionId <- decision.suggestionId.uuidString,
            decisionSuggestionType <- decision.suggestionType.rawValue,
            decisionType <- decision.decision.rawValue,
            decisionTimestamp <- decision.timestamp.timeIntervalSince1970,
            decisionMessage <- decision.suggestionMessage
        )
        
        try db.run(insert)
    }
    
    public func getAllDecisions() throws -> [SuggestionDecision] {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        var result: [SuggestionDecision] = []
        
        let query = decisions.order(decisionTimestamp.desc)
        
        for row in try db.prepare(query) {
            if let decision = try? rowToDecision(row) {
                result.append(decision)
            }
        }
        
        return result
    }
    
    public func getRecentDecisions(days: Int) throws -> [SuggestionDecision] {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        let cutoffTime = Date().addingTimeInterval(-Double(days * 24 * 60 * 60)).timeIntervalSince1970
        
        var result: [SuggestionDecision] = []
        
        let query = decisions
            .filter(decisionTimestamp >= cutoffTime)
            .order(decisionTimestamp.desc)
        
        for row in try db.prepare(query) {
            if let decision = try? rowToDecision(row) {
                result.append(decision)
            }
        }
        
        return result
    }
    
    public func getDecisions(for type: SuggestionType) throws -> [SuggestionDecision] {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        var result: [SuggestionDecision] = []
        
        let query = decisions
            .filter(decisionSuggestionType == type.rawValue)
            .order(decisionTimestamp.desc)
        
        for row in try db.prepare(query) {
            if let decision = try? rowToDecision(row) {
                result.append(decision)
            }
        }
        
        return result
    }
    
    public func clearAllDecisions() throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed
        }
        
        try db.run(decisions.delete())
    }
    
    private func rowToDecision(_ row: Row) throws -> SuggestionDecision {
        guard let idStr: String = row[decisionId],
              let id = UUID(uuidString: idStr),
              let suggestionIdStr: String = row[decisionSuggestionId],
              let suggestionId = UUID(uuidString: suggestionIdStr),
              let suggestionTypeStr: String = row[decisionSuggestionType],
              let suggestionType = SuggestionType(rawValue: suggestionTypeStr),
              let decisionStr: String = row[decisionType],
              let decision = DecisionType(rawValue: decisionStr),
              let message: String = row[decisionMessage] else {
            throw DatabaseError.invalidData
        }
        
        let timestamp = Date(timeIntervalSince1970: row[decisionTimestamp])
        
        return SuggestionDecision(
            id: id,
            suggestionId: suggestionId,
            suggestionType: suggestionType,
            decision: decision,
            timestamp: timestamp,
            suggestionMessage: message
        )
    }
}
