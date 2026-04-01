// Tests/ZoneDetectionTests.swift
import XCTest
import CoreLocation
@testable import LocationAutomation

/// Integration tests for end-to-end zone detection workflow
/// Tests: Create zone -> Enter zone -> Profile switch -> Exit zone -> Profile revert
final class ZoneDetectionTests: XCTestCase {

    // MARK: - Properties

    private var locationService: iOSLocationService!
    private var profileService: iOSProfileService!
    private var zoneMonitor: ZoneMonitor!
    private var testZone: Zone!
    private var testProfile: Profile!
    private var profileAppliedCount: Int = 0
    private var profileRevertedCount: Int = 0

    // MARK: - Test Data

    private let testLatitude = 37.7749
    private let testLongitude = -122.4194
    private let testRadius = 100.0
    private let zoneName = "Test Zone"

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Initialize services
        locationService = iOSLocationService()
        profileService = iOSProfileService()
        zoneMonitor = ZoneMonitor.shared

        // Reset counters
        profileAppliedCount = 0
        profileRevertedCount = 0

        // Setup database
        do {
            try DatabaseManager.shared.createTables()
        } catch {
            // Database may already exist
        }

        // Create test profile
        testProfile = Profile(
            name: "Test Profile",
            ringtone: .on,
            vibrate: .on,
            unmute: .on,
            dnd: .on,
            alarms: .on,
            timers: .on
        )

        // Create test zone with associated profile
        do {
            testZone = try Zone(
                name: zoneName,
                latitude: testLatitude,
                longitude: testLongitude,
                radius: testRadius,
                detectionMethods: [.gps, .geofence],
                profileId: testProfile.id
            )
        } catch {
            XCTFail("Failed to create test zone: \(error)")
        }
    }

    override func tearDown() {
        // Clean up: stop monitoring and remove region
        zoneMonitor.removeRegion(for: testZone)

        // Clean up database
        try? DatabaseManager.shared.deleteZone(id: testZone.id)

        super.tearDown()
    }

    // MARK: - Integration Tests

    /// Test 1: Create a zone
    func testCreateZone() {
        // Act: Create zone (already done in setUp)
        
        // Assert: Zone should be valid and have correct properties
        XCTAssertNotNil(testZone, "Zone should be created")
        XCTAssertEqual(testZone.name, zoneName, "Zone name should match")
        XCTAssertEqual(testZone.latitude, testLatitude, "Latitude should match")
        XCTAssertEqual(testZone.longitude, testLongitude, "Longitude should match")
        XCTAssertEqual(testZone.radius, testRadius, "Radius should match")
        XCTAssertTrue(testZone.detectionMethods.contains(.gps), "Should have GPS detection method")
        XCTAssertTrue(testZone.detectionMethods.contains(.geofence), "Should have geofence detection method")
        XCTAssertEqual(testZone.profileId, testProfile.id, "Profile ID should match")
    }

    /// Test 2: Simulate location entering zone and verify profile switch triggers
    func testZoneEntryTriggersProfileSwitch() async throws {
        // Arrange: Prepare expectation
        let entryExpectation = expectation(description: "Zone entry should trigger profile switch")

        // Act: Add region with entry callback
        try zoneMonitor.addRegion(
            for: testZone,
            onEnter: { [weak self] zone in
                guard let self = self else { return }
                
                self.profileAppliedCount += 1
                
                // Verify zone properties
                XCTAssertEqual(zone.id, self.testZone.id, "Zone ID should match on entry")
                
                // Apply profile
                Task {
                    try? await self.profileService.apply(profile: self.testProfile)
                    entryExpectation.expectationDescription = "Profile applied"
                }
            },
            onExit: { _ in }
        )

        // Simulate entering the region
        simulateRegionEntry(zoneId: testZone.id)

        // Wait for callback with timeout
        await fulfillment(of: [entryExpectation], timeout: 2.0)

        // Assert: Profile should have been applied
        XCTAssertEqual(profileAppliedCount, 1, "Profile switch should trigger on zone entry")
    }

    /// Test 3: Simulate location exiting zone and verify profile reverts
    func testZoneExitTriggersProfileRevert() async throws {
        // Arrange: Setup entry callback first
        let exitExpectation = expectation(description: "Zone exit should trigger profile revert")

        var entryApplied = false

        try zoneMonitor.addRegion(
            for: testZone,
            onEnter: { [weak self] zone in
                guard let self = self else { return }
                
                self.profileAppliedCount += 1
                entryApplied = true
                
                Task {
                    try? await self.profileService.apply(profile: self.testProfile)
                }
            },
            onExit: { [weak self] zone in
                guard let self = self else { return }
                
                self.profileRevertedCount += 1
                
                // Verify zone properties on exit
                XCTAssertEqual(zone.id, self.testZone.id, "Zone ID should match on exit")
                
                // Reset to default profile
                Task {
                    try? await self.profileService.resetToDefault()
                    exitExpectation.expectationDescription = "Profile reverted"
                }
            }
        )

        // Simulate entry then exit
        simulateRegionEntry(zoneId: testZone.id)
        
        // Small delay to ensure entry processed
        Thread.sleep(forTimeInterval: 0.1)
        
        simulateRegionExit(zoneId: testZone.id)

        // Wait for callback with timeout
        await fulfillment(of: [exitExpectation], timeout: 2.0)

        // Assert: Both entry and exit should have been triggered
        XCTAssertEqual(profileAppliedCount, 1, "Profile should be applied on entry")
        XCTAssertEqual(profileRevertedCount, 1, "Profile should revert on exit")
    }

    /// Test 4: Complete end-to-end zone detection workflow
    func testEndToEndZoneDetectionWorkflow() async throws {
        // Arrange
        let workflowExpectation = expectation(description: "Complete workflow")
        workflowExpectation.expectedFulfillmentCount = 2

        var currentProfile: Profile?

        try zoneMonitor.addRegion(
            for: testZone,
            onEnter: { [weak self] zone in
                guard let self = self else { return }
                
                self.profileAppliedCount += 1
                
                Task {
                    try await self.profileService.apply(profile: self.testProfile)
                    
                    // Verify profile was applied
                    let profile = try await self.profileService.getCurrentProfile()
                    currentProfile = profile
                    
                    workflowExpectation.fulfill()
                }
            },
            onExit: { [weak self] zone in
                guard let self = self else { return }
                
                self.profileRevertedCount += 1
                
                Task {
                    try await self.profileService.resetToDefault()
                    
                    // Verify profile was reverted
                    currentProfile = try await self.profileService.getCurrentProfile()
                    
                    workflowExpectation.fulfill()
                }
            }
        )

        // Act: Simulate complete workflow
        
        // Step 1: Enter zone
        simulateRegionEntry(zoneId: testZone.id)
        
        // Step 2: Wait for entry processing
        Thread.sleep(forTimeInterval: 0.2)
        
        // Step 3: Exit zone
        simulateRegionExit(zoneId: testZone.id)

        // Assert: Wait for all callbacks
        await fulfillment(of: [workflowExpectation], timeout: 5.0)

        // Verify workflow completed
        XCTAssertEqual(profileAppliedCount, 1, "Profile should be applied exactly once")
        XCTAssertEqual(profileRevertedCount, 1, "Profile should revert exactly once")
    }

    /// Test 5: Verify multiple zone detection with different profiles
    func testMultipleZonesWithDifferentProfiles() async throws {
        // Arrange: Create two zones with different profiles
        let profile1 = Profile(name: "Work Profile", ringtone: .off, vibrate: .on, unmute: .off, dnd: .on, alarms: .on, timers: .on)
        let profile2 = Profile(name: "Home Profile", ringtone: .on, vibrate: .off, unmute: .on, dnd: .off, alarms: .on, timers: .on)

        let zone1 = try Zone(name: "Work Zone", latitude: 37.7749, longitude: -122.4194, radius: 100, profileId: profile1.id)
        let zone2 = try Zone(name: "Home Zone", latitude: 37.7849, longitude: -122.4094, radius: 150, profileId: profile2.id)

        var activeZone: UUID?

        // Add first zone
        try zoneMonitor.addRegion(
            for: zone1,
            onEnter: { zone in
                activeZone = zone.id
            },
            onExit: { _ in
                activeZone = nil
            }
        )

        // Add second zone (may exceed iOS 20 limit but test for correctness)
        try zoneMonitor.addRegion(
            for: zone2,
            onEnter: { zone in
                activeZone = zone.id
            },
            onExit: { _ in
                activeZone = nil
            }
        )

        // Act: Simulate entering first zone
        simulateRegionEntry(zoneId: zone1.id)

        // Assert
        XCTAssertEqual(activeZone, zone1.id, "First zone should be active")

        // Clean up
        zoneMonitor.removeRegion(for: zone1)
        zoneMonitor.removeRegion(for: zone2)
    }

    // MARK: - Helper Methods

    /// Simulates region entry by posting the appropriate notification
    private func simulateRegionEntry(zoneId: UUID) {
        // Post the entry notification that ZoneMonitor listens for
        NotificationCenter.default.post(
            name: .zoneEntered,
            object: nil,
            userInfo: ["zoneId": zoneId, "identifier": zoneId.uuidString]
        )

        // Also simulate via location service notification
        NotificationCenter.default.post(
            name: .locationZoneEntered,
            object: nil,
            userInfo: ["region": zoneId.uuidString]
        )
    }

    /// Simulates region exit by posting the appropriate notification
    private func simulateRegionExit(zoneId: UUID) {
        // Post the exit notification that ZoneMonitor listens for
        NotificationCenter.default.post(
            name: .zoneExited,
            object: nil,
            userInfo: ["zoneId": zoneId, "identifier": zoneId.uuidString]
        )

        // Also simulate via location service notification
        NotificationCenter.default.post(
            name: .locationZoneExited,
            object: nil,
            userInfo: ["region": zoneId.uuidString]
        )
    }
}

// MARK: - Additional Edge Case Tests

extension ZoneDetectionTests {

    /// Test: Zone creation with invalid coordinates should fail
    func testZoneCreationFailsWithInvalidCoordinates() {
        // Invalid latitude
        XCTAssertThrowsError(try Zone(
            name: "Invalid",
            latitude: 91.0,
            longitude: 0,
            radius: 100,
            profileId: UUID()
        )) { error in
            XCTAssertTrue(error is ZoneValidationError)
        }

        // Invalid longitude
        XCTAssertThrowsError(try Zone(
            name: "Invalid",
            latitude: 0,
            longitude: 181.0,
            radius: 100,
            profileId: UUID()
        )) { error in
            XCTAssertTrue(error is ZoneValidationError)
        }

        // Invalid radius
        XCTAssertThrowsError(try Zone(
            name: "Invalid",
            latitude: 0,
            longitude: 0,
            radius: 0,
            profileId: UUID()
        )) { error in
            XCTAssertTrue(error is ZoneValidationError)
        }
    }

    /// Test: Profile service correctly applies all settings
    func testProfileServiceAppliesAllSettings() async throws {
        // Arrange
        let testProfile = Profile(
            name: "Full Settings Profile",
            ringtone: .on,
            vibrate: .on,
            unmute: .on,
            dnd: .on,
            alarms: .on,
            timers: .on
        )

        // Act
        try await profileService.apply(profile: testProfile)

        // Assert: Should not throw any errors
        // Note: Some settings may not be controllable on iOS but shouldn't error
    }

    /// Test: Profile service can reset to default
    func testProfileServiceCanResetToDefault() async throws {
        // Arrange: Apply a profile first
        let testProfile = Profile(name: "Test", ringtone: .off, vibrate: .off, unmute: .off, dnd: .off, alarms: .off, timers: .off)
        try await profileService.apply(profile: testProfile)

        // Act: Reset to default
        try await profileService.resetToDefault()

        // Assert: Should not throw
    }

    /// Test: Location service authorization check
    func testLocationServiceAuthorizationCheck() {
        // Can check authorization status without throwing
        let _ = locationService.isAuthorized()

        // Detection method should be GPS for iOS
        XCTAssertEqual(locationService.detectionMethod, .gps)
    }

    /// Test: Zone monitor region limit detection
    func testZoneMonitorRegionLimit() {
        // Check initial state
        let initialCount = zoneMonitor.monitoredRegionCount
        XCTAssertLessThan(initialCount, zoneMonitor.maxMonitoredRegions, "Should start below limit")

        // Check limit property
        let atLimit = zoneMonitor.isAtRegionLimit
        XCTAssertFalse(atLimit, "Should not be at limit initially")
    }
}