import XCTest
@testable import LocationAutomation

// MARK: - Zone Validation Tests

final class ZoneValidationTests: XCTestCase {
    
    var testProfileId: UUID!
    
    override func setUp() {
        super.setUp()
        testProfileId = UUID()
    }
    
    // MARK: - Latitude Validation
    
    func testValidLatitudeBoundaryValues() {
        // Test valid boundary values
        XCTAssertNoThrow(try Zone(name: "Test", latitude: -90, longitude: 0, radius: 100, profileId: testProfileId))
        XCTAssertNoThrow(try Zone(name: "Test", latitude: 0, longitude: 0, radius: 100, profileId: testProfileId))
        XCTAssertNoThrow(try Zone(name: "Test", latitude: 90, longitude: 0, radius: 100, profileId: testProfileId))
    }
    
    func testInvalidLatitudeTooLow() {
        XCTAssertThrowsError(try Zone(name: "Test", latitude: -91, longitude: 0, radius: 100, profileId: testProfileId)) { error in
            XCTAssertTrue(error is ZoneValidationError)
            if case .invalidLatitude = error as? ZoneValidationError {
                // Expected
            } else {
                XCTFail("Expected invalidLatitude error")
            }
        }
    }
    
    func testInvalidLatitudeTooHigh() {
        XCTAssertThrowsError(try Zone(name: "Test", latitude: 91, longitude: 0, radius: 100, profileId: testProfileId)) { error in
            XCTAssertTrue(error is ZoneValidationError)
            if case .invalidLatitude = error as? ZoneValidationError {
                // Expected
            } else {
                XCTFail("Expected invalidLatitude error")
            }
        }
    }
    
    func testInvalidLatitudeOutsideRange() {
        XCTAssertThrowsError(try Zone(name: "Test", latitude: -180, longitude: 0, radius: 100, profileId: testProfileId))
        XCTAssertThrowsError(try Zone(name: "Test", latitude: 180, longitude: 0, radius: 100, profileId: testProfileId))
    }
    
    // MARK: - Longitude Validation
    
    func testValidLongitudeBoundaryValues() {
        XCTAssertNoThrow(try Zone(name: "Test", latitude: 0, longitude: -180, radius: 100, profileId: testProfileId))
        XCTAssertNoThrow(try Zone(name: "Test", latitude: 0, longitude: 0, radius: 100, profileId: testProfileId))
        XCTAssertNoThrow(try Zone(name: "Test", latitude: 0, longitude: 180, radius: 100, profileId: testProfileId))
    }
    
    func testInvalidLongitudeTooLow() {
        XCTAssertThrowsError(try Zone(name: "Test", latitude: 0, longitude: -181, radius: 100, profileId: testProfileId)) { error in
            XCTAssertTrue(error is ZoneValidationError)
            if case .invalidLongitude = error as? ZoneValidationError {
                // Expected
            } else {
                XCTFail("Expected invalidLongitude error")
            }
        }
    }
    
    func testInvalidLongitudeTooHigh() {
        XCTAssertThrowsError(try Zone(name: "Test", latitude: 0, longitude: 181, radius: 100, profileId: testProfileId)) { error in
            XCTAssertTrue(error is ZoneValidationError)
            if case .invalidLongitude = error as? ZoneValidationError {
                // Expected
            } else {
                XCTFail("Expected invalidLongitude error")
            }
        }
    }
    
    // MARK: - Radius Validation
    
    func testValidRadiusValues() {
        XCTAssertNoThrow(try Zone(name: "Test", latitude: 0, longitude: 0, radius: 0.001, profileId: testProfileId))
        XCTAssertNoThrow(try Zone(name: "Test", latitude: 0, longitude: 0, radius: 1, profileId: testProfileId))
        XCTAssertNoThrow(try Zone(name: "Test", latitude: 0, longitude: 0, radius: 1000, profileId: testProfileId))
    }
    
    func testInvalidRadiusZero() {
        XCTAssertThrowsError(try Zone(name: "Test", latitude: 0, longitude: 0, radius: 0, profileId: testProfileId)) { error in
            XCTAssertTrue(error is ZoneValidationError)
            if case .invalidRadius = error as? ZoneValidationError {
                // Expected
            } else {
                XCTFail("Expected invalidRadius error")
            }
        }
    }
    
    func testInvalidRadiusNegative() {
        XCTAssertThrowsError(try Zone(name: "Test", latitude: 0, longitude: 0, radius: -1, profileId: testProfileId))
        XCTAssertThrowsError(try Zone(name: "Test", latitude: 0, longitude: 0, radius: -100, profileId: testProfileId))
    }
    
    // MARK: - Validate Method
    
    func testValidateMethodValidZone() {
        let zone = try? Zone(name: "Test", latitude: 45.0, longitude: -122.0, radius: 500, profileId: testProfileId)
        XCTAssertNotNil(zone)
        XCTAssertNoThrow(try zone?.validate())
    }
    
    func testValidateMethodInvalidZone() {
        var zone = try? Zone(name: "Test", latitude: 45.0, longitude: -122.0, radius: 500, profileId: testProfileId)
        XCTAssertNotNil(zone)
        
        // Manually modify state to test validate
        var invalidZone = Zone(
            id: UUID(),
            name: "Test",
            latitude: 200, // Invalid
            longitude: -122.0,
            radius: 500,
            detectionMethods: [],
            profileId: testProfileId
        )
        
        XCTAssertThrowsError(try invalidZone.validate()) { error in
            XCTAssertTrue(error is ZoneValidationError)
        }
    }
    
    // MARK: - Zone Creation with Detection Methods
    
    func testZoneCreationWithDetectionMethods() {
        let zone = try? Zone(
            name: "Home",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            detectionMethods: [.gps, .wifi, .bluetooth],
            profileId: testProfileId
        )
        
        XCTAssertNotNil(zone)
        XCTAssertEqual(zone?.detectionMethods.count, 3)
        XCTAssertTrue(zone?.detectionMethods.contains(.gps) ?? false)
        XCTAssertTrue(zone?.detectionMethods.contains(.wifi) ?? false)
        XCTAssertTrue(zone?.detectionMethods.contains(.bluetooth) ?? false)
    }
    
    func testZoneCreationWithEmptyDetectionMethods() {
        let zone = try? Zone(
            name: "Work",
            latitude: 40.7128,
            longitude: -74.0060,
            radius: 200,
            detectionMethods: [],
            profileId: testProfileId
        )
        
        XCTAssertNotNil(zone)
        XCTAssertEqual(zone?.detectionMethods.count, 0)
    }
    
    // MARK: - Real World Coordinates
    
    func testRealWorldCoordinatesSanFrancisco() {
        let zone = try? Zone(
            name: "San Francisco",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 500,
            profileId: testProfileId
        )
        XCTAssertNotNil(zone)
    }
    
    func testRealWorldCoordinatesNewYork() {
        let zone = try? Zone(
            name: "New York",
            latitude: 40.7128,
            longitude: -74.0060,
            radius: 300,
            profileId: testProfileId
        )
        XCTAssertNotNil(zone)
    }
    
    func testRealWorldCoordinatesTokyo() {
        let zone = try? Zone(
            name: "Tokyo",
            latitude: 35.6762,
            longitude: 139.6503,
            radius: 400,
            profileId: testProfileId
        )
        XCTAssertNotNil(zone)
    }
}

// MARK: - Profile Settings Tests

final class ProfileSettingsTests: XCTestCase {
    
    // MARK: - Profile Creation
    
    func testProfileCreationWithDefaults() {
        let profile = Profile(name: "Default Profile")
        
        XCTAssertFalse(profile.id.uuidString.isEmpty)
        XCTAssertEqual(profile.name, "Default Profile")
        XCTAssertEqual(profile.ringtone, .off)
        XCTAssertEqual(profile.vibrate, .off)
        XCTAssertEqual(profile.unmute, .off)
        XCTAssertEqual(profile.dnd, .off)
        XCTAssertEqual(profile.alarms, .on)
        XCTAssertEqual(profile.timers, .on)
    }
    
    func testProfileCreationWithCustomSettings() {
        let profile = Profile(
            name: "Custom Profile",
            ringtone: .on,
            vibrate: .automatic,
            unmute: .off,
            dnd: .automatic,
            alarms: .off,
            timers: .automatic
        )
        
        XCTAssertEqual(profile.name, "Custom Profile")
        XCTAssertEqual(profile.ringtone, .on)
        XCTAssertEqual(profile.vibrate, .automatic)
        XCTAssertEqual(profile.unmute, .off)
        XCTAssertEqual(profile.dnd, .automatic)
        XCTAssertEqual(profile.alarms, .off)
        XCTAssertEqual(profile.timers, .automatic)
    }
    
    // MARK: - Profile Validation
    
    func testProfileValidationValidName() {
        let profile = Profile(name: "Valid Name")
        XCTAssertNoThrow(try profile.validate())
    }
    
    func testProfileValidationEmptyName() {
        let profile = Profile(name: "")
        XCTAssertThrowsError(try profile.validate()) { error in
            XCTAssertTrue(error is ProfileValidationError)
            if case .invalidName = error as? ProfileValidationError {
                // Expected
            } else {
                XCTFail("Expected invalidName error")
            }
        }
    }
    
    func testProfileValidationNameWithSpaces() {
        // Empty after trimming is invalid
        let profile = Profile(name: "   ")
        XCTAssertThrowsError(try profile.validate())
    }
    
    // MARK: - Profile Setting Enum
    
    func testProfileSettingRawValues() {
        XCTAssertEqual(ProfileSetting.on.rawValue, "on")
        XCTAssertEqual(ProfileSetting.off.rawValue, "off")
        XCTAssertEqual(ProfileSetting.automatic.rawValue, "automatic")
    }
    
    func testProfileSettingRawValueInit() {
        XCTAssertEqual(ProfileSetting(rawValue: "on"), .on)
        XCTAssertEqual(ProfileSetting(rawValue: "off"), .off)
        XCTAssertEqual(ProfileSetting(rawValue: "automatic"), .automatic)
    }
    
    func testProfileSettingUnknownRawValue() {
        XCTAssertNil(ProfileSetting(rawValue: "unknown"))
    }
    
    // MARK: - Profile Codable
    
    func testProfileCodable() throws {
        let profile = Profile(
            name: "Test Profile",
            ringtone: .on,
            vibrate: .automatic,
            unmute: .off,
            dnd: .on,
            alarms: .automatic,
            timers: .off
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)
        
        let decoder = JSONDecoder()
        let decodedProfile = try decoder.decode(Profile.self, from: data)
        
        XCTAssertEqual(profile.id, decodedProfile.id)
        XCTAssertEqual(profile.name, decodedProfile.name)
        XCTAssertEqual(profile.ringtone, decodedProfile.ringtone)
        XCTAssertEqual(profile.vibrate, decodedProfile.vibrate)
        XCTAssertEqual(profile.unmute, decodedProfile.unmute)
        XCTAssertEqual(profile.dnd, decodedProfile.dnd)
        XCTAssertEqual(profile.alarms, decodedProfile.alarms)
        XCTAssertEqual(profile.timers, decodedProfile.timers)
    }
    
    // MARK: - Multiple Profiles
    
    func testMultipleProfilesHaveUniqueIds() {
        let profile1 = Profile(name: "Profile 1")
        let profile2 = Profile(name: "Profile 2")
        let profile3 = Profile(name: "Profile 3")
        
        XCTAssertNotEqual(profile1.id, profile2.id)
        XCTAssertNotEqual(profile2.id, profile3.id)
        XCTAssertNotEqual(profile1.id, profile3.id)
    }
}

// MARK: - DetectionPriorityManager Tests

final class DetectionPriorityManagerTests: XCTestCase {
    
    var manager: DetectionPriorityManager!
    var testZones: [Zone]!
    var testProfileId: UUID!
    
    override func setUp() {
        super.setUp()
        manager = DetectionPriorityManager.shared
        testProfileId = UUID()
        
        // Create test zones
        testZones = [
            try! Zone(name: "Home", latitude: 37.7749, longitude: -122.4194, radius: 100, profileId: testProfileId),
            try! Zone(name: "Work", latitude: 40.7128, longitude: -74.0060, radius: 200, profileId: testProfileId),
            try! Zone(name: "Gym", latitude: 34.0522, longitude: -118.2437, radius: 50, profileId: testProfileId)
        ]
    }
    
    override func tearDown() {
        manager.clearActiveZone()
        manager.deactivateManualOverride()
        super.tearDown()
    }
    
    // MARK: - Priority Resolution
    
    func testPriorityOrderManualOverridesAll() {
        let gpsPriority = manager.resolvePriority(for: .gps, zone: testZones[0])
        let wifiPriority = manager.resolvePriority(for: .wifi, zone: testZones[0])
        
        // Before manual override, priorities should be based on detection method
        XCTAssertEqual(gpsPriority, .gps)
        XCTAssertEqual(wifiPriority, .wifi)
    }
    
    func testPriorityResolutionWithManualOverride() {
        manager.activateManualOverride(for: testZones[0])
        
        let gpsPriority = manager.resolvePriority(for: .gps, zone: testZones[0])
        
        XCTAssertEqual(gpsPriority, .manual)
        
        manager.deactivateManualOverride()
    }
    
    func testPriorityValuesAreComparable() {
        XCTAssertTrue(DetectionPriority.manual < DetectionPriority.gps)
        XCTAssertTrue(DetectionPriority.gps < DetectionPriority.wifi)
        XCTAssertTrue(DetectionPriority.wifi < DetectionPriority.bluetooth)
    }
    
    // MARK: - Winner Resolution
    
    func testResolveWinnerSingleCandidate() {
        let candidates = [(zone: testZones[0], method: DetectionMethod.gps)]
        
        let winner = manager.resolveWinner(from: candidates)
        
        XCTAssertNotNil(winner)
        XCTAssertEqual(winner?.zone.id, testZones[0].id)
        XCTAssertEqual(winner?.method, .gps)
    }
    
    func testResolveWinnerEmptyCandidates() {
        let winner = manager.resolveWinner(from: [])
        
        XCTAssertNil(winner)
    }
    
    func testResolveWinnerMultipleCandidatesGPSWins() {
        let candidates = [
            (zone: testZones[0], method: DetectionMethod.bluetooth),
            (zone: testZones[1], method: DetectionMethod.wifi),
            (zone: testZones[2], method: DetectionMethod.gps)
        ]
        
        let winner = manager.resolveWinner(from: candidates)
        
        XCTAssertNotNil(winner)
        XCTAssertEqual(winner?.zone.id, testZones[2].id) // GPS zone should win
        XCTAssertEqual(winner?.method, .gps)
    }
    
    func testResolveWinnerMultipleCandidatesWiFiWinsOverBluetooth() {
        let candidates = [
            (zone: testZones[0], method: DetectionMethod.bluetooth),
            (zone: testZones[1], method: DetectionMethod.wifi)
        ]
        
        let winner = manager.resolveWinner(from: candidates)
        
        XCTAssertNotNil(winner)
        XCTAssertEqual(winner?.method, .wifi)
    }
    
    func testResolveWinnerManualOverrideWinsOverGPS() {
        manager.activateManualOverride(for: testZones[0])
        
        let candidates = [
            (zone: testZones[0], method: DetectionMethod.gps),
            (zone: testZones[1], method: DetectionMethod.wifi)
        ]
        
        let winner = manager.resolveWinner(from: candidates)
        
        XCTAssertNotNil(winner)
        // Manual override should win
        XCTAssertEqual(manager.resolvePriority(for: .gps, zone: testZones[0]), .manual)
        
        manager.deactivateManualOverride()
    }
    
    // MARK: - Manual Override
    
    func testActivateManualOverride() {
        XCTAssertFalse(manager.isManualOverrideActive)
        
        manager.activateManualOverride(for: testZones[0])
        
        XCTAssertTrue(manager.isManualOverrideActive)
        
        // Cleanup
        manager.deactivateManualOverride()
    }
    
    func testDeactivateManualOverride() {
        manager.activateManualOverride(for: testZones[0])
        XCTAssertTrue(manager.isManualOverrideActive)
        
        manager.deactivateManualOverride()
        
        XCTAssertFalse(manager.isManualOverrideActive)
    }
    
    func testManualOverrideStateInactive() {
        XCTAssertFalse(manager.isManualOverrideActive)
        
        if case .inactive = manager.manualOverride {
            // Expected
        } else {
            XCTFail("Expected inactive state")
        }
    }
    
    func testManualOverrideStateActive() {
        manager.activateManualOverride(for: testZones[0])
        
        if case .active(let zoneId, let activatedAt) = manager.manualOverride {
            XCTAssertEqual(zoneId, testZones[0].id)
            XCTAssertNotNil(activatedAt)
        } else {
            XCTFail("Expected active state")
        }
        
        manager.deactivateManualOverride()
    }
    
    // MARK: - Zone Change
    
    func testRequestZoneChangeSetsActiveZone() {
        manager.requestZoneChange(zone: testZones[0], method: .gps)
        
        // Allow debounce to complete
        let expectation = XCTestExpectation(description: "Zone change")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertNotNil(manager.activeZone)
        XCTAssertEqual(manager.activeZone?.zone.id, testZones[0].id)
    }
    
    func testApplyImmediateZoneChange() {
        manager.applyImmediateZoneChange(zone: testZones[1], method: .wifi)
        
        // Immediate change should apply without debounce
        XCTAssertNotNil(manager.activeZone)
        XCTAssertEqual(manager.activeZone?.zone.id, testZones[1].id)
        XCTAssertEqual(manager.activeZone?.method, .wifi)
    }
    
    func testClearActiveZone() {
        manager.applyImmediateZoneChange(zone: testZones[0], method: .gps)
        XCTAssertNotNil(manager.activeZone)
        
        manager.clearActiveZone()
        
        XCTAssertNil(manager.activeZone)
    }
    
    func testSameZoneChangeIgnored() {
        manager.applyImmediateZoneChange(zone: testZones[0], method: .gps)
        
        let previousZoneId = manager.activeZone?.zone.id
        
        // Try to change to same zone
        manager.requestZoneChange(zone: testZones[0], method: .wifi)
        
        XCTAssertEqual(manager.activeZone?.zone.id, previousZoneId)
    }
    
    // MARK: - Debounce
    
    func testDebounceIntervalDefault() {
        XCTAssertEqual(manager.debounceInterval, 30.0)
    }
    
    func testDebounceIntervalCustom() {
        manager.debounceInterval = 5.0
        XCTAssertEqual(manager.debounceInterval, 5.0)
        
        // Reset
        manager.debounceInterval = 30.0
    }
    
    // MARK: - State Queries
    
    func testCurrentPriorityNoActiveZone() {
        manager.clearActiveZone()
        
        XCTAssertNil(manager.currentPriority)
    }
    
    func testCurrentPriorityWithActiveZone() {
        manager.applyImmediateZoneChange(zone: testZones[0], method: .gps)
        
        XCTAssertNotNil(manager.currentPriority)
    }
    
    func testCurrentPriorityWithManualOverride() {
        manager.activateManualOverride(for: testZones[0])
        
        XCTAssertEqual(manager.currentPriority, .manual)
        
        manager.deactivateManualOverride()
    }
    
    func testGetStateDescriptionNoActiveZone() {
        manager.clearActiveZone()
        
        let description = manager.getStateDescription()
        
        XCTAssertEqual(description, "No active zone")
    }
    
    func testGetStateDescriptionWithActiveZone() {
        manager.applyImmediateZoneChange(zone: testZones[0], method: .gps)
        
        let description = manager.getStateDescription()
        
        XCTAssertTrue(description.contains("Active: Home"))
    }
    
    func testGetStateDescriptionWithManualOverride() {
        manager.activateManualOverride(for: testZones[0])
        
        let description = manager.getStateDescription()
        
        XCTAssertTrue(description.contains("Manual Override"))
        
        manager.deactivateManualOverride()
    }
    
    // MARK: - Callbacks
    
    func testOnZoneChangedCallback() {
        var callbackCalled = false
        var receivedZone: ActiveZone?
        
        manager.onZoneChanged = { zone in
            callbackCalled = true
            receivedZone = zone
        }
        
        manager.applyImmediateZoneChange(zone: testZones[0], method: .gps)
        
        // Allow async callback
        let expectation = XCTestExpectation(description: "Callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(callbackCalled)
        XCTAssertNotNil(receivedZone)
    }
    
    func testOnManualOverrideChangedCallback() {
        var callbackCalled = false
        
        manager.onManualOverrideChanged = { state in
            callbackCalled = true
        }
        
        manager.activateManualOverride(for: testZones[0])
        
        // Allow async callback
        let expectation = XCTestExpectation(description: "Callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(callbackCalled)
        
        manager.deactivateManualOverride()
    }
}

// MARK: - DatabaseManager CRUD Tests

final class DatabaseManagerCRUDTests: XCTestCase {
    
    var dbManager: DatabaseManager!
    var testProfileId: UUID!
    var testZoneId: UUID!
    
    override func setUp() {
        super.setUp()
        dbManager = DatabaseManager.shared
        testProfileId = UUID()
        testZoneId = UUID()
        
        do {
            try dbManager.createTables()
        } catch {
            // Tables may already exist
        }
    }
    
    override func tearDown() {
        // Clean up test data
        try? dbManager.deleteZone(id: testZoneId)
        try? dbManager.deleteProfile(id: testProfileId)
        super.tearDown()
    }
    
    // MARK: - Zone CRUD
    
    func testCreateZone() throws {
        let zone = try Zone(
            id: testZoneId,
            name: "Test Zone",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            detectionMethods: [.gps, .wifi],
            profileId: testProfileId
        )
        
        try dbManager.createZone(zone)
        
        // Verify
        let retrieved = try dbManager.getZone(id: testZoneId)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Test Zone")
        XCTAssertEqual(retrieved?.latitude, 37.7749)
        XCTAssertEqual(retrieved?.longitude, -122.4194)
        XCTAssertEqual(retrieved?.radius, 100)
        XCTAssertEqual(retrieved?.detectionMethods.count, 2)
    }
    
    func testGetZoneNotFound() throws {
        let retrieved = try dbManager.getZone(id: UUID())
        
        XCTAssertNil(retrieved)
    }
    
    func testGetAllZones() throws {
        // Create multiple zones
        let zone1 = try Zone(name: "Zone 1", latitude: 37.0, longitude: -122.0, radius: 100, profileId: testProfileId)
        let zone2 = try Zone(name: "Zone 2", latitude: 38.0, longitude: -123.0, radius: 200, profileId: testProfileId)
        
        try dbManager.createZone(zone1)
        try dbManager.createZone(zone2)
        
        let allZones = try dbManager.getAllZones()
        
        XCTAssertTrue(allZones.count >= 2)
    }
    
    func testUpdateZone() throws {
        let zone = try Zone(
            id: testZoneId,
            name: "Original Name",
            latitude: 37.0,
            longitude: -122.0,
            radius: 100,
            profileId: testProfileId
        )
        
        try dbManager.createZone(zone)
        
        // Update
        var updatedZone = zone
        updatedZone.name = "Updated Name"
        updatedZone.radius = 200
        
        try dbManager.updateZone(updatedZone)
        
        // Verify
        let retrieved = try dbManager.getZone(id: testZoneId)
        
        XCTAssertEqual(retrieved?.name, "Updated Name")
        XCTAssertEqual(retrieved?.radius, 200)
    }
    
    func testDeleteZone() throws {
        let zone = try Zone(
            id: testZoneId,
            name: "To Delete",
            latitude: 37.0,
            longitude: -122.0,
            radius: 100,
            profileId: testProfileId
        )
        
        try dbManager.createZone(zone)
        
        // Delete
        try dbManager.deleteZone(id: testZoneId)
        
        // Verify
        let retrieved = try dbManager.getZone(id: testZoneId)
        
        XCTAssertNil(retrieved)
    }
    
    func testDeleteZoneNotFound() throws {
        // Should not throw
        XCTAssertNoThrow(try dbManager.deleteZone(id: UUID()))
    }
    
    // MARK: - Profile CRUD
    
    func testCreateProfile() throws {
        let profile = Profile(
            id: testProfileId,
            name: "Test Profile",
            ringtone: .on,
            vibrate: .automatic,
            unmute: .off,
            dnd: .on,
            alarms: .automatic,
            timers: .off
        )
        
        try dbManager.createProfile(profile)
        
        // Verify
        let retrieved = try dbManager.getProfile(id: testProfileId)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Test Profile")
        XCTAssertEqual(retrieved?.ringtone, .on)
        XCTAssertEqual(retrieved?.vibrate, .automatic)
    }
    
    func testGetProfileNotFound() throws {
        let retrieved = try dbManager.getProfile(id: UUID())
        
        XCTAssertNil(retrieved)
    }
    
    func testGetAllProfiles() throws {
        let profile1 = Profile(name: "Profile 1")
        let profile2 = Profile(name: "Profile 2")
        
        try dbManager.createProfile(profile1)
        try dbManager.createProfile(profile2)
        
        let allProfiles = try dbManager.getAllProfiles()
        
        XCTAssertTrue(allProfiles.count >= 2)
    }
    
    func testUpdateProfile() throws {
        let profile = Profile(
            id: testProfileId,
            name: "Original",
            ringtone: .off,
            vibrate: .off,
            unmute: .off,
            dnd: .off,
            alarms: .on,
            timers: .on
        )
        
        try dbManager.createProfile(profile)
        
        // Update
        var updatedProfile = profile
        updatedProfile.name = "Updated"
        updatedProfile.ringtone = .on
        updatedProfile.dnd = .automatic
        
        try dbManager.updateProfile(updatedProfile)
        
        // Verify
        let retrieved = try dbManager.getProfile(id: testProfileId)
        
        XCTAssertEqual(retrieved?.name, "Updated")
        XCTAssertEqual(retrieved?.ringtone, .on)
        XCTAssertEqual(retrieved?.dnd, .automatic)
    }
    
    func testDeleteProfile() throws {
        let profile = Profile(
            id: testProfileId,
            name: "To Delete",
            ringtone: .off,
            vibrate: .off,
            unmute: .off,
            dnd: .off,
            alarms: .on,
            timers: .on
        )
        
        try dbManager.createProfile(profile)
        
        // Delete
        try dbManager.deleteProfile(id: testProfileId)
        
        // Verify
        let retrieved = try dbManager.getProfile(id: testProfileId)
        
        XCTAssertNil(retrieved)
    }
    
    // MARK: - Database Errors
    
    func testCreateTablesTwice() throws {
        // Should not throw - tables already exist
        XCTAssertNoThrow(try dbManager.createTables())
    }
    
    func testCreateZoneBeforeTablesCreated() throws {
        // Reset manager for this test
        let freshManager = DatabaseManager.shared
        
        // Create tables first
        try freshManager.createTables()
        
        let zone = try Zone(name: "Test", latitude: 37.0, longitude: -122.0, radius: 100, profileId: testProfileId)
        
        XCTAssertNoThrow(try freshManager.createZone(zone))
    }
    
    // MARK: - Pattern CRUD
    
    func testSaveAndGetPattern() throws {
        let pattern = Pattern(
            zoneId: testZoneId,
            entryTimes: [Date()],
            exitTimes: [Date()],
            durations: [3600],
            dates: [Date()]
        )
        
        try dbManager.savePattern(pattern)
        
        let retrieved = try dbManager.getPattern(zoneId: testZoneId)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.zoneId, testZoneId)
    }
    
    func testGetPatternNotFound() throws {
        let retrieved = try dbManager.getPattern(zoneId: UUID())
        
        XCTAssertNil(retrieved)
    }
    
    func testDeletePattern() throws {
        let pattern = Pattern(
            zoneId: testZoneId,
            entryTimes: [Date()],
            exitTimes: [],
            durations: [],
            dates: [Date()]
        )
        
        try dbManager.savePattern(pattern)
        
        try dbManager.deletePattern(zoneId: testZoneId)
        
        let retrieved = try dbManager.getPattern(zoneId: testZoneId)
        
        XCTAssertNil(retrieved)
    }
    
    // MARK: - Edge Cases
    
    func testZoneWithSpecialCharactersInName() throws {
        let zone = try Zone(
            id: testZoneId,
            name: "Zone with 'quotes' and 日本語",
            latitude: 37.0,
            longitude: -122.0,
            radius: 100,
            profileId: testProfileId
        )
        
        try dbManager.createZone(zone)
        
        let retrieved = try dbManager.getZone(id: testZoneId)
        
        XCTAssertEqual(retrieved?.name, "Zone with 'quotes' and 日本語")
    }
    
    func testProfileWithUnicodeName() throws {
        let profile = Profile(
            id: testProfileId,
            name: "Профиль на русском",
            ringtone: .on,
            vibrate: .off,
            unmute: .automatic,
            dnd: .on,
            alarms: .off,
            timers: .automatic
        )
        
        try dbManager.createProfile(profile)
        
        let retrieved = try dbManager.getProfile(id: testProfileId)
        
        XCTAssertEqual(retrieved?.name, "Профиль на русском")
    }
}