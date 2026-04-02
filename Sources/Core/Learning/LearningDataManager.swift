// Core/Learning/LearningDataManager.swift
import Foundation

/// LearningDataManager handles data migration, cleanup, and backup for learning data.
/// Provides version-based migrations and scheduled maintenance operations.
public final class LearningDataManager: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = LearningDataManager()
    
    // MARK: - Properties
    
    private let database = DatabaseManager.shared
    private let logger = Logger.shared
    private let fileManager = FileManager.default
    private let calendar = Calendar.current
    
    /// Current schema version for migrations
    private let currentSchemaVersion: Int = 1
    
    /// Key for storing schema version in UserDefaults
    private let schemaVersionKey = "learning_schema_version"
    
    /// Default cleanup threshold (90 days)
    private let defaultCleanupThreshold = 90
    
    /// Timer for scheduled cleanup
    private var cleanupTimer: Timer?
    
    /// Cleanup interval (24 hours)
    private let cleanupInterval: TimeInterval = 24 * 60 * 60
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Schema Migration
    
    /// Get current schema version
    public func getSchemaVersion() -> Int {
        return UserDefaults.standard.integer(forKey: schemaVersionKey)
    }
    
    /// Set schema version
    private func setSchemaVersion(_ version: Int) {
        UserDefaults.standard.set(version, forKey: schemaVersionKey)
    }
    
    /// Run migrations if needed
    public func runMigrationsIfNeeded() {
        let storedVersion = getSchemaVersion()
        
        if storedVersion < currentSchemaVersion {
            logger.info("Running migrations from version \(storedVersion) to \(currentSchemaVersion)")
            migrate(from: storedVersion, to: currentSchemaVersion)
        } else if storedVersion == 0 {
            // First time setup - set initial version
            setSchemaVersion(currentSchemaVersion)
            logger.info("Initialized learning data schema at version \(currentSchemaVersion)")
        }
    }
    
    /// Perform migration from one version to another
    private func migrate(from oldVersion: Int, to newVersion: Int) {
        var currentVersion = oldVersion
        
        // Migration steps
        while currentVersion < newVersion {
            switch currentVersion {
            case 0:
                // Initial version - nothing to migrate
                currentVersion = 1
                logger.info("Migration to v1 completed")
            // Add future migrations here
            // case 1:
            //     // Migrate to v2
            //     currentVersion = 2
            default:
                currentVersion += 1
            }
        }
        
        setSchemaVersion(newVersion)
        logger.info("All migrations completed. Schema version: \(newVersion)")
    }
    
    /// Reset schema version (for testing or fresh install)
    public func resetSchemaVersion() {
        setSchemaVersion(0)
        logger.info("Schema version reset to 0")
    }
    
    // MARK: - Data Cleanup
    
    /// Clean up learning data older than specified days
    /// - Parameter days: Remove data older than this many days (default 90)
    public func cleanupOldData(olderThan days: Int? = nil) {
        let threshold = days ?? defaultCleanupThreshold
        
        // Use existing PatternTracker cleanup method
        PatternTracker.shared.cleanupOldData(olderThan: threshold)
        
        // Also cleanup decision history
        cleanupDecisionHistory(olderThan: threshold)
        
        logger.info("Cleanup completed for data older than \(threshold) days")
    }
    
    /// Clean up decision history older than specified days
    private func cleanupDecisionHistory(olderThan days: Int) {
        do {
            try database.clearAllDecisions()
            logger.info("Decision history cleared")
        } catch {
            logger.error("Failed to cleanup decision history: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Scheduled Cleanup
    
    /// Start scheduled cleanup timer
    public func startScheduledCleanup() {
        stopScheduledCleanup()
        
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            self?.cleanupOldData()
        }
        
        logger.info("Scheduled cleanup started (interval: \(Int(cleanupInterval)) seconds)")
    }
    
    /// Stop scheduled cleanup timer
    public func stopScheduledCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        logger.info("Scheduled cleanup stopped")
    }
    
    /// Check if scheduled cleanup is running
    public var isScheduledCleanupRunning: Bool {
        return cleanupTimer != nil
    }
    
    // MARK: - Backup
    
    /// Backup learning data to specified directory
    /// - Parameter destinationPath: Optional custom path, defaults to timestamped file
    /// - Returns: Path to backup file, or nil if failed
    @discardableResult
    public func backupLearningData(to destinationPath: String? = nil) -> String? {
        let backupDir = getBackupDirectory()
        
        // Create backup directory if needed
        if !fileManager.fileExists(atPath: backupDir) {
            do {
                try fileManager.createDirectory(atPath: backupDir, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create backup directory: \(error.localizedDescription)")
                return nil
            }
        }
        
        // Determine backup filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "learning_backup_\(timestamp).sqlite3"
        
        let backupPath = destinationPath ?? (backupDir + "/" + filename)
        
        // Get database path
        let dbPath = getDatabasePath()
        
        do {
            // Copy database file
            if fileManager.fileExists(atPath: backupPath) {
                try fileManager.removeItem(atPath: backupPath)
            }
            try fileManager.copyItem(atPath: dbPath, toPath: backupPath)
            
            logger.info("Learning data backed up to: \(backupPath)")
            
            // Cleanup old backups (keep last 5)
            cleanupOldBackups(keepCount: 5)
            
            return backupPath
        } catch {
            logger.error("Failed to backup learning data: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Restore learning data from backup
    /// - Parameter backupPath: Path to backup file
    /// - Returns: true if successful
    @discardableResult
    public func restoreLearningData(from backupPath: String) -> Bool {
        let dbPath = getDatabasePath()
        
        do {
            // Verify backup file exists
            guard fileManager.fileExists(atPath: backupPath) else {
                logger.error("Backup file not found: \(backupPath)")
                return false
            }
            
            // Create backup of current data before restoring
            let preRestoreBackup = dbPath + ".pre_restore"
            if fileManager.fileExists(atPath: dbPath) {
                if fileManager.fileExists(atPath: preRestoreBackup) {
                    try fileManager.removeItem(atPath: preRestoreBackup)
                }
                try fileManager.copyItem(atPath: dbPath, toPath: preRestoreBackup)
            }
            
            // Restore from backup
            if fileManager.fileExists(atPath: dbPath) {
                try fileManager.removeItem(atPath: dbPath)
            }
            try fileManager.copyItem(atPath: backupPath, toPath: dbPath)
            
            logger.info("Learning data restored from: \(backupPath)")
            return true
        } catch {
            logger.error("Failed to restore learning data: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Get list of available backups
    public func getAvailableBackups() -> [BackupInfo] {
        let backupDir = getBackupDirectory()
        
        guard fileManager.fileExists(atPath: backupDir) else {
            return []
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: backupDir)
            let backupFiles = files.filter { $0.hasPrefix("learning_backup_") && $0.hasSuffix(".sqlite3") }
            
            return backupFiles.map { filename in
                let fullPath = backupDir + "/" + filename
                let attributes = try? fileManager.attributesOfItem(atPath: fullPath)
                let modificationDate = attributes?[.modificationDate] as? Date ?? Date()
                let fileSize = attributes?[.size] as? Int64 ?? 0
                
                return BackupInfo(
                    filename: filename,
                    path: fullPath,
                    createdDate: modificationDate,
                    sizeBytes: fileSize
                )
            }.sorted { $0.createdDate > $1.createdDate }
        } catch {
            logger.error("Failed to list backups: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Delete a specific backup
    /// - Parameter backupPath: Path to backup file
    /// - Returns: true if successful
    @discardableResult
    public func deleteBackup(at backupPath: String) -> Bool {
        do {
            try fileManager.removeItem(atPath: backupPath)
            logger.info("Deleted backup: \(backupPath)")
            return true
        } catch {
            logger.error("Failed to delete backup: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Private Helpers
    
    private func getBackupDirectory() -> String {
        #if os(iOS)
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!.path
        return documentsPath + "/Backups"
        #else
        return "backups"
        #endif
    }
    
    private func getDatabasePath() -> String {
        #if os(iOS)
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("location_automation.sqlite3").path
        #else
        return "location_automation.sqlite3"
        #endif
    }
    
    private func cleanupOldBackups(keepCount: Int) {
        let backups = getAvailableBackups()
        
        if backups.count > keepCount {
            let toDelete = backups.suffix(from: keepCount)
            for backup in toDelete {
                deleteBackup(at: backup.path)
            }
        }
    }
}

// MARK: - Backup Info

public struct BackupInfo {
    public let filename: String
    public let path: String
    public let createdDate: Date
    public let sizeBytes: Int64
    
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }
}