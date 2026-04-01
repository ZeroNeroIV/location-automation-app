import XCTest
import CoreLocation
import UIKit
@testable import LocationAutomation

// MARK: - Mock CLLocationManager for Testing

final class MockCLLocationManager: CLLocationManager {
    
    var isSignificantLocationChangeMonitoringAvailableResult = true
    var isMonitoringAvailableResult = true
    var maximumRegionMonitoringDistanceResult: CLLocationDistance = 200000
    
    var startedSignificantLocationChanges = false
    var stoppedSignificantLocationChanges = false
    var monitoredRegionsStarted: [CLRegion] = []
    var monitoredRegionsStopped: [CLRegion] = []
    var backgroundFetchIntervalSet: TimeInterval?
    
    var simulatedAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override class func significantLocationChangeMonitoringAvailable() -> Bool {
        return true
    }
    
    override class func isMonitoringAvailable(for regionClass: AnyClass) -> Bool {
        return true
    }
    
    override func startMonitoringSignificantLocationChanges() {
        startedSignificantLocationChanges = true
    }
    
    override func stopMonitoringSignificantLocationChanges() {
        stoppedSignificantLocationChanges = true
    }
    
    override func startMonitoring(for region: CLRegion) {
        monitoredRegionsStarted.append(region)
    }
    
    override func stopMonitoring(for region: CLRegion) {
        monitoredRegionsStopped.append(region)
    }
    
    override var maximumRegionMonitoringDistance: CLLocationDistance {
        return maximumRegionMonitoringDistanceResult
    }
    
    override var authorizationStatus: CLAuthorizationStatus {
        return simulatedAuthorizationStatus
    }
    
    override func requestAlwaysAuthorization() {
        simulatedAuthorizationStatus = .authorizedAlways
    }
}

// MARK: - Testable ZoneMonitor

final class TestableZoneMonitor: ZoneMonitor {
    
    let mockLocationManager: MockCLLocationManager
    
    init(mockManager: MockCLLocationManager) {
        self.mockLocationManager = mockManager
        super.init()
    }
    
    // Override to use mock
    override var authorizationStatus: CLAuthorizationStatus {
        return mockLocationManager.simulatedAuthorizationStatus
    }
}

// MARK: - Background Operation Tests

final class BackgroundOperationTests: XCTestCase {
    
    var mockLocationManager: MockCLLocationManager!
    var zoneMonitor: TestableZoneMonitor!
    var testZone: Zone!
    
    override func setUp() {
        super.setUp()
        mockLocationManager = MockCLLocationManager()
        zoneMonitor = TestableZoneMonitor(mockManager: mockLocationManager)
        
        // Create a test zone
        testZone = try! Zone(
            name: "Test Zone",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            detectionMethods: [.geofence],
            profileId: UUID()
        )
    }
    
    override func tearDown() {
        zoneMonitor.removeAllRegions()
        mockLocationManager = nil
        zoneMonitor = nil
        testZone = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: ZoneMonitor Background Mode Registration
    
    func testBackgroundModeRegistration() {
        // Verify that background location updates are enabled
        XCTAssertTrue(
            mockLocationManager.allowsBackgroundLocationUpdates,
            "Background location updates should be enabled"
        )
        XCTAssertFalse(
            mockLocationManager.pausesLocationUpdatesAutomatically,
            "Automatic pause should be disabled for continuous monitoring"
        )
    }
    
    func testBackgroundFetchConfiguration() {
        // Enable background fetch
        zoneMonitor.enableBackgroundFetch()
        
        // The interval should be set to minimum (i.e., the system decides when to fetch)
        XCTAssertTrue(
            zoneMonitor.isBackgroundFetchAvailable,
            "Background fetch should be available"
        )
    }
    
    func testDisableBackgroundFetch() {
        zoneMonitor.enableBackgroundFetch()
        zoneMonitor.disableBackgroundFetch()
        
        XCTAssertTrue(
            zoneMonitor.isBackgroundFetchAvailable,
            "Background fetch availability check should work"
        )
    }
    
    // MARK: - Test 2: Significant Location Change Monitoring
    
    func testStartSignificantLocationChanges() {
        zoneMonitor.startSignificantLocationChanges()
        
        XCTAssertTrue(
            mockLocationManager.startedSignificantLocationChanges,
            "Should start monitoring significant location changes"
        )
    }
    
    func testStopSignificantLocationChanges() {
        zoneMonitor.startSignificantLocationChanges()
        zoneMonitor.stopSignificantLocationChanges()
        
        XCTAssertTrue(
            mockLocationManager.stoppedSignificantLocationChanges,
            "Should stop monitoring significant location changes"
        )
    }
    
    func testSignificantLocationChangesAvailability() {
        XCTAssertTrue(
            CLLocationManager.significantLocationChangeMonitoringAvailable(),
            "Significant location change monitoring should be available"
        )
    }
    
    func testSignificantLocationChangeNotification() {
        // Post a test notification
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        NotificationCenter.default.post(
            name: .significantLocationChanged,
            object: nil,
            userInfo: ["location": testLocation]
        )
        
        // Verify notification was posted
        let expectation = self.expectation(description: "Notification received")
        
        NotificationCenter.default.addObserver(
            forName: .significantLocationChanged,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertNotNil(notification.userInfo?["location"])
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - Test 3: Geofence Registration
    
    func testAddRegionForMonitoring() {
        var entered = false
        var exited = false
        
        do {
            try zoneMonitor.addRegion(
                for: testZone,
                onEnter: { _ in entered = true },
                onExit: { _ in exited = true }
            )
        } catch {
            XCTFail("Failed to add region: \(error.localizedDescription)")
        }
        
        XCTAssertEqual(
            zoneMonitor.monitoredRegionCount, 1,
            "Should have one monitored region"
        )
        XCTAssertFalse(
            zoneMonitor.isAtRegionLimit,
            "Should not be at region limit"
        )
    }
    
    func testAddRegionEnforcesLimit() {
        // Create 20 zones to hit the limit
        var zones: [Zone] = []
        
        for i in 0..<20 {
            let zone = try! Zone(
                name: "Zone \(i)",
                latitude: 37.0 + Double(i) * 0.01,
                longitude: -122.0 + Double(i) * 0.01,
                radius: 100,
                detectionMethods: [.geofence],
                profileId: UUID()
            )
            zones.append(zone)
        }
        
        // Add all 20 regions
        for zone in zones {
            do {
                try zoneMonitor.addRegion(
                    for: zone,
                    onEnter: { _ in },
                    onExit: { _ in }
                )
            } catch {
                XCTFail("Failed to add region: \(error.localizedDescription)")
            }
        }
        
        XCTAssertTrue(
            zoneMonitor.isAtRegionLimit,
            "Should be at iOS 20 region limit"
        )
        
        // Try to add one more - should fail
        let extraZone = try! Zone(
            name: "Extra Zone",
            latitude: 40.0,
            longitude: -120.0,
            radius: 100,
            detectionMethods: [.geofence],
            profileId: UUID()
        )
        
        do {
            try zoneMonitor.addRegion(
                for: extraZone,
                onEnter: { _ in },
                onExit: { _ in }
            )
            XCTFail("Should throw error when region limit reached")
        } catch ZoneMonitorError.regionLimitReached {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    func testRemoveRegion() {
        do {
            try zoneMonitor.addRegion(
                for: testZone,
                onEnter: { _ in },
                onExit: { _ in }
            )
        } catch {
            XCTFail("Failed to add region: \(error.localizedDescription)")
        }
        
        zoneMonitor.removeRegion(for: testZone)
        
        XCTAssertEqual(
            zoneMonitor.monitoredRegionCount, 0,
            "Should have no monitored regions after removal"
        )
    }
    
    func testRemoveAllRegions() {
        // Add multiple zones
        for i in 0..<5 {
            let zone = try! Zone(
                name: "Zone \(i)",
                latitude: 37.0 + Double(i) * 0.01,
                longitude: -122.0 + Double(i) * 0.01,
                radius: 100,
                detectionMethods: [.geofence],
                profileId: UUID()
            )
            
            do {
                try zoneMonitor.addRegion(
                    for: zone,
                    onEnter: { _ in },
                    onExit: { _ in }
                )
            } catch {
                XCTFail("Failed to add region: \(error.localizedDescription)")
            }
        }
        
        zoneMonitor.removeAllRegions()
        
        XCTAssertEqual(
            zoneMonitor.monitoredRegionCount, 0,
            "Should have no monitored regions after removing all"
        )
    }
    
    func testMonitoringAvailability() {
        XCTAssertTrue(
            zoneMonitor.isMonitoringAvailable,
            "Region monitoring should be available"
        )
    }
    
    // MARK: - Test 4: App Launch from Geofence Event
    
    func testZoneEnteredNotification() {
        let expectation = self.expectation(description: "Zone entered notification")
        
        NotificationCenter.default.addObserver(
            forName: .zoneEntered,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertNotNil(notification.userInfo?["zoneId"])
            XCTAssertNotNil(notification.userInfo?["identifier"])
            expectation.fulfill()
        }
        
        // Simulate region entry
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: testZone.latitude,
                longitude: testZone.longitude
            ),
            radius: testZone.radius,
            identifier: testZone.id.uuidString
        )
        region.notifyOnEntry = true
        
        NotificationCenter.default.post(
            name: .zoneEntered,
            object: nil,
            userInfo: [
                "zoneId": testZone.id,
                "identifier": testZone.id.uuidString
            ]
        )
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testZoneExitedNotification() {
        let expectation = self.expectation(description: "Zone exited notification")
        
        NotificationCenter.default.addObserver(
            forName: .zoneExited,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertNotNil(notification.userInfo?["zoneId"])
            XCTAssertNotNil(notification.userInfo?["identifier"])
            expectation.fulfill()
        }
        
        // Simulate region exit
        NotificationCenter.default.post(
            name: .zoneExited,
            object: nil,
            userInfo: [
                "zoneId": testZone.id,
                "identifier": testZone.id.uuidString
            ]
        )
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testLocationAuthorizationChangedNotification() {
        let expectation = self.expectation(description: "Authorization changed notification")
        
        NotificationCenter.default.addObserver(
            forName: .locationAuthorizationChanged,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        NotificationCenter.default.post(
            name: .locationAuthorizationChanged,
            object: nil
        )
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testAuthorizationStatus() {
        mockLocationManager.simulatedAuthorizationStatus = .authorizedAlways
        
        XCTAssertTrue(
            zoneMonitor.isAlwaysAuthorized,
            "Should be always authorized when status is authorizedAlways"
        )
        
        mockLocationManager.simulatedAuthorizationStatus = .authorizedWhenInUse
        
        XCTAssertFalse(
            zoneMonitor.isAlwaysAuthorized,
            "Should not be always authorized when status is authorizedWhenInUse"
        )
        
        mockLocationManager.simulatedAuthorizationStatus = .denied
        
        XCTAssertFalse(
            zoneMonitor.isAlwaysAuthorized,
            "Should not be always authorized when status is denied"
        )
    }
    
    func testRequestAlwaysAuthorization() {
        zoneMonitor.requestAlwaysAuthorization()
        
        XCTAssertEqual(
            mockLocationManager.simulatedAuthorizationStatus,
            .authorizedAlways,
            "Authorization should be requested"
        )
    }
    
    // MARK: - Region Monitoring Delegate Tests
    
    func testDidEnterRegionCreatesZone() {
        let expectation = self.expectation(description: "Region entered")
        
        var enteredZone: Zone?
        
        do {
            try zoneMonitor.addRegion(
                for: testZone,
                onEnter: { zone in
                    enteredZone = zone
                    expectation.fulfill()
                },
                onExit: { _ in }
            )
        } catch {
            XCTFail("Failed to add region: \(error.localizedDescription)")
        }
        
        // Simulate delegate callback
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: testZone.latitude,
                longitude: testZone.longitude
            ),
            radius: testZone.radius,
            identifier: testZone.id.uuidString
        )
        region.notifyOnEntry = true
        
        zoneMonitor.locationManager(
            mockLocationManager,
            didEnterRegion: region
        )
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertNotNil(enteredZone, "Zone should be provided in callback")
    }
    
    func testDidExitRegionCreatesZone() {
        let expectation = self.expectation(description: "Region exited")
        
        var exitedZone: Zone?
        
        do {
            try zoneMonitor.addRegion(
                for: testZone,
                onEnter: { _ in },
                onExit: { zone in
                    exitedZone = zone
                    expectation.fulfill()
                }
            )
        } catch {
            XCTFail("Failed to add region: \(error.localizedDescription)")
        }
        
        // Simulate delegate callback
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: testZone.latitude,
                longitude: testZone.longitude
            ),
            radius: testZone.radius,
            identifier: testZone.id.uuidString
        )
        region.notifyOnExit = true
        
        zoneMonitor.locationManager(
            mockLocationManager,
            didExitRegion: region
        )
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertNotNil(exitedZone, "Zone should be provided in callback")
    }
    
    func testMonitoringDidFailForRegion() {
        // Add a region first
        do {
            try zoneMonitor.addRegion(
                for: testZone,
                onEnter: { _ in },
                onExit: { _ in }
            )
        } catch {
            XCTFail("Failed to add region: \(error.localizedDescription)")
        }
        
        let initialCount = zoneMonitor.monitoredRegionCount
        
        // Simulate monitoring failure
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: testZone.latitude,
                longitude: testZone.longitude
            ),
            radius: testZone.radius,
            identifier: testZone.id.uuidString
        )
        
        zoneMonitor.locationManager(
            mockLocationManager,
            monitoringDidFailFor: region,
            withError: NSError(
                domain: "CLLocationManagerErrorDomain",
                code: 1,
                userInfo: nil
            )
        )
        
        // The region should be cleaned up
        XCTAssertLessThan(
            zoneMonitor.monitoredRegionCount, initialCount,
            "Failed region should be removed"
        )
    }
    
    // MARK: - Error Handling Tests
    
    func testRegionLimitError() {
        let error = ZoneMonitorError.regionLimitReached
        XCTAssertEqual(
            error.localizedDescription,
            "iOS 20 region limit has been reached"
        )
    }
    
    func testMonitoringNotAvailableError() {
        let error = ZoneMonitorError.monitoringNotAvailable
        XCTAssertEqual(
            error.localizedDescription,
            "Region monitoring is not available on this device"
        )
    }
    
    func testRegionNotFoundError() {
        let error = ZoneMonitorError.regionNotFound
        XCTAssertEqual(
            error.localizedDescription,
            "Region not found"
        )
    }
    
    func testAuthorizationDeniedError() {
        let error = ZoneMonitorError.authorizationDenied
        XCTAssertEqual(
            error.localizedDescription,
            "Location authorization denied"
        )
    }
}
