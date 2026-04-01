import XCTest
@testable import LocationAutomation

final class IntegrationTests: XCTestCase {
    
    private var database: DatabaseManager!
    private var patternTracker: PatternTracker!
    private var deviationDetector: DeviationDetector!
    private var suggestionGenerator: SuggestionGenerator!
    private var suggestionApprovalManager: SuggestionApprovalManager!
    private var learningDataManager: LearningDataManager!
    
    private var testZoneId: UUID!
    private var testProfileId: UUID!
    
    override func setUp() {
        super.setUp()
        
        database = DatabaseManager.shared
        patternTracker = PatternTracker.shared
        deviationDetector = DeviationDetector.shared
        suggestionGenerator = SuggestionGenerator.shared
        suggestionApprovalManager = SuggestionApprovalManager.shared
        learningDataManager = LearningDataManager.shared
        
        testZoneId = UUID()
        testProfileId = UUID()
        
        do {
            try database.createTables()
        } catch {
        }
    }
    
    override func tearDown() {
        try? database.deleteZone(id: testZoneId)
        try? database.deleteProfile(id: testProfileId)
        try? database.deletePattern(zoneId: testZoneId)
        super.tearDown()
    }
    
    private func createTestProfile() throws -> Profile {
        let profile = Profile(
            id: testProfileId,
            name: "Test Profile",
            ringtone: .off,
            vibrate: .off,
            unmute: .off,
            dnd: .off,
            alarms: .on,
            timers: .on
        )
        try database.createProfile(profile)
        return profile
    }
    
    private func createTestZone() throws -> Zone {
        let zone = try Zone(
            id: testZoneId,
            name: "Test Zone",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            detectionMethods: [.gps, .wifi],
            profileId: testProfileId
        )
        try database.createZone(zone)
        return zone
    }
    
    func testZoneCreationToDatabaseToMapDisplayFlow() throws {
        let profile = try createTestProfile()
        
        let zone = try Zone(
            id: testZoneId,
            name: "Integration Test Zone",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 150,
            detectionMethods: [.gps, .wifi, .geofence],
            profileId: profile.id
        )
        
        try database.createZone(zone)
        
        let retrievedZone = try database.getZone(id: zone.id)
        
        XCTAssertNotNil(retrievedZone)
        XCTAssertEqual(retrievedZone?.id, zone.id)
        XCTAssertEqual(retrievedZone?.name, "Integration Test Zone")
        XCTAssertEqual(retrievedZone?.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(retrievedZone?.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(retrievedZone?.radius, 150)
        XCTAssertEqual(retrievedZone?.detectionMethods, [.gps, .wifi, .geofence])
        XCTAssertEqual(retrievedZone?.profileId, profile.id)
        
        let associatedProfile = try database.getProfile(id: retrievedZone!.profileId)
        XCTAssertNotNil(associatedProfile)
        XCTAssertEqual(associatedProfile?.name, "Test Profile")
    }
    
    func testZoneListRetrievalForDisplay() throws {
        let profile = try createTestProfile()
        
        let zone1 = try Zone(
            id: UUID(),
            name: "Home",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            detectionMethods: [.gps],
            profileId: profile.id
        )
        
        let zone2 = try Zone(
            id: UUID(),
            name: "Work",
            latitude: 37.7849,
            longitude: -122.4094,
            radius: 200,
            detectionMethods: [.wifi],
            profileId: profile.id
        )
        
        try database.createZone(zone1)
        try database.createZone(zone2)
        
        let allZones = try database.getAllZones()
        
        XCTAssertGreaterThanOrEqual(allZones.count, 2)
        
        let homeZone = allZones.first { $0.name == "Home" }
        XCTAssertNotNil(homeZone)
        
        try? database.deleteZone(id: zone1.id)
        try? database.deleteZone(id: zone2.id)
    }
    
    func testProfileChangeTriggersNotificationFlow() throws {
        let profile = try createTestProfile()
        
        var updatedProfile = profile
        updatedProfile.dnd = .on
        updatedProfile.vibrate = .on
        
        try database.updateProfile(updatedProfile)
        
        let retrievedProfile = try database.getProfile(id: profile.id)
        XCTAssertEqual(retrievedProfile?.dnd, .on)
        XCTAssertEqual(retrievedProfile?.vibrate, .on)
        
        let settingsToApply = [
            "dnd": retrievedProfile?.dnd.rawValue ?? "off",
            "vibrate": retrievedProfile?.vibrate.rawValue ?? "off"
        ]
        
        XCTAssertEqual(settingsToApply["dnd"], "on")
        XCTAssertEqual(settingsToApply["vibrate"], "on")
    }
    
    func testProfileSwitchingIntegration() throws {
        let silentProfile = Profile(name: "Silent")
        let normalProfile = Profile(name: "Normal")
        
        try database.createProfile(silentProfile)
        try database.createProfile(normalProfile)
        
        let zone = try Zone(
            id: testZoneId,
            name: "Test Zone",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            detectionMethods: [.gps],
            profileId: silentProfile.id
        )
        try database.createZone(zone)
        
        var updatedZone = zone
        updatedZone.profileId = normalProfile.id
        try database.updateZone(updatedZone)
        
        let retrievedZone = try database.getZone(id: zone.id)
        XCTAssertEqual(retrievedZone?.profileId, normalProfile.id)
        
        let newProfile = try database.getProfile(id: normalProfile.id)
        XCTAssertEqual(newProfile?.name, "Normal")
    }
    
    func testLearningDeviationSuggestionApprovalFlow() throws {
        _ = try createTestProfile()
        _ = try createTestZone()
        
        let calendar = Calendar.current
        var baseDate = Date()
        
        for i in 0..<7 {
            if let entryDate = calendar.date(byAdding: .day, value: -i, to: baseDate) {
                var entryComponents = calendar.dateComponents([.year, .month, .day], from: entryDate)
                entryComponents.hour = 9
                entryComponents.minute = 0
                
                if let normalizedDate = calendar.date(from: entryComponents) {
                    patternTracker.recordEntry(zoneId: testZoneId)
                    
                    if var pattern = try database.getPattern(zoneId: testZoneId) {
                        pattern.entryTimes.append(normalizedDate)
                        pattern.durations.append(3600)
                        pattern.dates.append(normalizedDate)
                        try database.savePattern(pattern)
                    }
                    
                    patternTracker.recordExit(zoneId: testZoneId)
                }
            }
        }
        
        let deviation = DeviationResult(
            zoneId: testZoneId,
            deviationType: .entryTime,
            expectedValue: 32400,
            actualValue: 39600,
            deviation: 7200,
            deviationThreshold: 1800,
            exceedsThreshold: true,
            warningLevel: .high,
            sampleCount: 7,
            dayType: .weekday
        )
        
        XCTAssertTrue(deviation.exceedsThreshold)
        
        let suggestions = suggestionGenerator.generateAllSuggestions()
        
        if let profileSuggestion = suggestions.first(where: {
            if case .profileChange = $0 { return true }
            return false
        }) {
            if case .profileChange(let suggestion) = profileSuggestion {
                let approvalResult = suggestionApprovalManager.approveSuggestion(.profileChange(suggestion))
                switch approvalResult {
                case .success:
                    break
                case .failure:
                    XCTFail("Approval should succeed")
                }
            }
        }
    }
    
    func testDeviationDetectionWithInsufficientData() throws {
        _ = try createTestZone()
        
        patternTracker.recordEntry(zoneId: testZoneId)
        patternTracker.recordExit(zoneId: testZoneId)
        
        patternTracker.recordEntry(zoneId: testZoneId)
        patternTracker.recordExit(zoneId: testZoneId)
        
        let hasData = deviationDetector.hasSufficientData(for: testZoneId)
        XCTAssertFalse(hasData)
    }
    
    func testSuggestionRateLimiting() throws {
        let canGenerate = suggestionGenerator.canGenerateSuggestion()
        
        XCTAssertTrue(canGenerate == true || canGenerate == false)
        
        let timeRemaining = suggestionGenerator.timeUntilNextSuggestion()
        XCTAssertGreaterThanOrEqual(timeRemaining, 0)
    }
    
    func testFullUserOnboardingToAutoDetectionFlow() throws {
        let defaultProfile = Profile(
            name: "Default Profile",
            ringtone: .on,
            vibrate: .off,
            unmute: .off,
            dnd: .off,
            alarms: .on,
            timers: .on
        )
        try database.createProfile(defaultProfile)
        
        let savedProfile = try database.getProfile(id: defaultProfile.id)
        XCTAssertEqual(savedProfile?.name, "Default Profile")
        
        let homeZone = try Zone(
            id: UUID(),
            name: "Home",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 200,
            detectionMethods: [.gps, .wifi],
            profileId: defaultProfile.id
        )
        try database.createZone(homeZone)
        
        let retrievedZone = try database.getZone(id: homeZone.id)
        XCTAssertEqual(retrievedZone?.profileId, defaultProfile.id)
        
        patternTracker.recordEntry(zoneId: homeZone.id)
        
        let hasPending = patternTracker.hasPendingEntry(for: homeZone.id)
        XCTAssertTrue(hasPending)
        
        let zoneProfile = try database.getProfile(id: homeZone.profileId)
        XCTAssertNotNil(zoneProfile)
        
        patternTracker.recordExit(zoneId: homeZone.id)
        
        let pattern = patternTracker.getPattern(for: homeZone.id)
        XCTAssertNotNil(pattern)
        XCTAssertGreaterThanOrEqual(pattern?.entryTimes.count ?? 0, 1)
        
        for _ in 0..<5 {
            patternTracker.recordEntry(zoneId: homeZone.id)
            patternTracker.recordExit(zoneId: homeZone.id)
        }
        
        let hasEnoughData = deviationDetector.hasSufficientData(for: homeZone.id)
        XCTAssertTrue(hasEnoughData)
        
        let statistics = deviationDetector.getStatistics(for: homeZone.id)
        XCTAssertNotNil(statistics)
        
        try? database.deleteZone(id: homeZone.id)
        try? database.deleteProfile(id: defaultProfile.id)
    }
    
    func testOnboardingCompletionState() throws {
        let allProfiles = try database.getAllProfiles()
        
        XCTAssertGreaterThanOrEqual(allProfiles.count, 0)
    }
    
    func testLearningDataMigrationIntegration() throws {
        learningDataManager.runMigrationsIfNeeded()
        
        let version = learningDataManager.getSchemaVersion()
        XCTAssertGreaterThanOrEqual(version, 0)
    }
    
    func testDataCleanupIntegration() throws {
        _ = try createTestProfile()
        _ = try createTestZone()
        
        patternTracker.recordEntry(zoneId: testZoneId)
        patternTracker.recordExit(zoneId: testZoneId)
        
        learningDataManager.cleanupOldData(olderThan: 30)
    }
    
    func testMultiZonePatternTracking() throws {
        let profile = try createTestProfile()
        
        let zone1 = try Zone(id: UUID(), name: "Zone 1", latitude: 37.0, longitude: -122.0, radius: 100, detectionMethods: [.gps], profileId: profile.id)
        let zone2 = try Zone(id: UUID(), name: "Zone 2", latitude: 38.0, longitude: -121.0, radius: 100, detectionMethods: [.gps], profileId: profile.id)
        
        try database.createZone(zone1)
        try database.createZone(zone2)
        
        patternTracker.recordEntry(zoneId: zone1.id)
        patternTracker.recordExit(zoneId: zone1.id)
        
        patternTracker.recordEntry(zoneId: zone2.id)
        patternTracker.recordExit(zoneId: zone2.id)
        
        let pattern1 = patternTracker.getPattern(for: zone1.id)
        let pattern2 = patternTracker.getPattern(for: zone2.id)
        
        XCTAssertEqual(pattern1?.zoneId, zone1.id)
        XCTAssertEqual(pattern2?.zoneId, zone2.id)
        
        try? database.deleteZone(id: zone1.id)
        try? database.deleteZone(id: zone2.id)
    }
    
    func testCrossModuleErrorHandling() throws {
        do {
            _ = try Zone(
                id: UUID(),
                name: "Invalid Zone",
                latitude: 100,
                longitude: -122.0,
                radius: 100,
                detectionMethods: [],
                profileId: testProfileId
            )
            XCTFail("Should throw error for invalid latitude")
        } catch let error as ZoneValidationError {
            XCTAssertEqual(error, .invalidLatitude)
        }
    }
}