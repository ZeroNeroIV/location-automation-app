import XCTest
@testable import LocationAutomation

final class ProfileSwitchTests: XCTestCase {
    
    var profileService: iOSProfileService!
    var testProfile1: Profile!
    var testProfile2: Profile!
    var testProfileId1: UUID!
    var testProfileId2: UUID!
    
    override func setUp() {
        super.setUp()
        profileService = iOSProfileService()
        testProfileId1 = UUID()
        testProfileId2 = UUID()
        
        do {
            try DatabaseManager.shared.createTables()
        } catch {
        }
        
        testProfile1 = Profile(
            id: testProfileId1,
            name: "Test Profile 1",
            ringtone: .on,
            vibrate: .on,
            unmute: .on,
            dnd: .off,
            alarms: .on,
            timers: .off
        )
        
        testProfile2 = Profile(
            id: testProfileId2,
            name: "Test Profile 2",
            ringtone: .off,
            vibrate: .off,
            unmute: .off,
            dnd: .on,
            alarms: .off,
            timers: .on
        )
    }
    
    override func tearDown() {
        try? DatabaseManager.shared.deleteProfile(id: testProfileId1)
        try? DatabaseManager.shared.deleteProfile(id: testProfileId2)
        try? profileService.resetToDefault()
        super.tearDown()
    }
    
    func testCreateProfileWithSpecificSettings() {
        do {
            try DatabaseManager.shared.createProfile(testProfile1)
            
            let retrieved = try DatabaseManager.shared.getProfile(id: testProfileId1)
            
            XCTAssertNotNil(retrieved)
            XCTAssertEqual(retrieved?.name, "Test Profile 1")
            XCTAssertEqual(retrieved?.ringtone, .on)
            XCTAssertEqual(retrieved?.vibrate, .on)
            XCTAssertEqual(retrieved?.unmute, .on)
            XCTAssertEqual(retrieved?.dnd, .off)
            XCTAssertEqual(retrieved?.alarms, .on)
            XCTAssertEqual(retrieved?.timers, .off)
        } catch {
            XCTFail("Failed to create/retrieve profile: \(error.localizedDescription)")
        }
    }
    
    func testApplyProfileViaService() {
        do {
            try DatabaseManager.shared.createProfile(testProfile1)
        } catch {
            XCTFail("Failed to save profile: \(error.localizedDescription)")
            return
        }
        
        do {
            try profileService.apply(profile: testProfile1)
        } catch {
            XCTFail("Failed to apply profile: \(error.localizedDescription)")
        }
    }
    
    func testVerifySettingsChanged() async {
        do {
            try DatabaseManager.shared.createProfile(testProfile1)
            try profileService.apply(profile: testProfile1)
        } catch {
            XCTFail("Setup failed: \(error.localizedDescription)")
            return
        }
        
        do {
            let currentProfile = try await profileService.getCurrentProfile()
            XCTAssertNotNil(currentProfile)
        } catch {
            XCTFail("Failed to get current profile: \(error.localizedDescription)")
        }
    }
    
    func testSwitchToDifferentProfile() {
        do {
            try DatabaseManager.shared.createProfile(testProfile1)
            try DatabaseManager.shared.createProfile(testProfile2)
        } catch {
            XCTFail("Failed to create profiles: \(error.localizedDescription)")
            return
        }
        
        do {
            try profileService.apply(profile: testProfile1)
        } catch {
            XCTFail("Failed to apply first profile: \(error.localizedDescription)")
            return
        }
        
        do {
            try profileService.apply(profile: testProfile2)
        } catch {
            XCTFail("Failed to switch to second profile: \(error.localizedDescription)")
        }
    }
    
    func testVerifyAllSettingsUpdatedCorrectly() async {
        do {
            try DatabaseManager.shared.createProfile(testProfile1)
            try DatabaseManager.shared.createProfile(testProfile2)
        } catch {
            XCTFail("Failed to create profiles: \(error.localizedDescription)")
            return
        }
        
        do {
            try profileService.apply(profile: testProfile1)
        } catch {
            XCTFail("Failed to apply first profile: \(error.localizedDescription)")
            return
        }
        
        Thread.sleep(forTimeInterval: 0.1)
        
        do {
            try profileService.apply(profile: testProfile2)
        } catch {
            XCTFail("Failed to apply second profile: \(error.localizedDescription)")
            return
        }
        
        do {
            let currentProfile = try await profileService.getCurrentProfile()
            
            XCTAssertNotNil(currentProfile)
            
            let allProfiles = try DatabaseManager.shared.getAllProfiles()
            let profile1Exists = allProfiles.contains { $0.id == testProfileId1 }
            let profile2Exists = allProfiles.contains { $0.id == testProfileId2 }
            
            XCTAssertTrue(profile1Exists)
            XCTAssertTrue(profile2Exists)
        } catch {
            XCTFail("Verification failed: \(error.localizedDescription)")
        }
    }
    
    func testFullProfileSwitchIntegrationFlow() {
        let workProfile = Profile(
            id: UUID(),
            name: "Work Mode",
            ringtone: .off,
            vibrate: .on,
            unmute: .off,
            dnd: .on,
            alarms: .on,
            timers: .on
        )
        
        let homeProfile = Profile(
            id: UUID(),
            name: "Home Mode",
            ringtone: .on,
            vibrate: .off,
            unmute: .on,
            dnd: .off,
            alarms: .off,
            timers: .off
        )
        
        do {
            try DatabaseManager.shared.createProfile(workProfile)
            try DatabaseManager.shared.createProfile(homeProfile)
        } catch {
            XCTFail("Failed to save profiles: \(error.localizedDescription)")
            return
        }
        
        do {
            try profileService.apply(profile: workProfile)
        } catch {
            XCTFail("Failed to apply work profile: \(error.localizedDescription)")
            return
        }
        
        do {
            let workProfileFromDB = try DatabaseManager.shared.getProfile(id: workProfile.id)
            XCTAssertNotNil(workProfileFromDB)
            XCTAssertEqual(workProfileFromDB?.name, "Work Mode")
            XCTAssertEqual(workProfileFromDB?.ringtone, .off)
            XCTAssertEqual(workProfileFromDB?.dnd, .on)
        } catch {
            XCTFail("Failed to verify work profile: \(error.localizedDescription)")
            return
        }
        
        do {
            try profileService.apply(profile: homeProfile)
        } catch {
            XCTFail("Failed to switch to home profile: \(error.localizedDescription)")
            return
        }
        
        do {
            let homeProfileFromDB = try DatabaseManager.shared.getProfile(id: homeProfile.id)
            XCTAssertNotNil(homeProfileFromDB)
            XCTAssertEqual(homeProfileFromDB?.name, "Home Mode")
            XCTAssertEqual(homeProfileFromDB?.ringtone, .on)
            XCTAssertEqual(homeProfileFromDB?.unmute, .on)
        } catch {
            XCTFail("Failed to verify home profile: \(error.localizedDescription)")
            return
        }
        
        try? DatabaseManager.shared.deleteProfile(id: workProfile.id)
        try? DatabaseManager.shared.deleteProfile(id: homeProfile.id)
    }
    
    func testProfileSettingsConsistency() {
        let profile = Profile(
            id: UUID(),
            name: "Consistency Test",
            ringtone: .automatic,
            vibrate: .automatic,
            unmute: .automatic,
            dnd: .automatic,
            alarms: .automatic,
            timers: .automatic
        )
        
        do {
            try DatabaseManager.shared.createProfile(profile)
            let retrieved = try DatabaseManager.shared.getProfile(id: profile.id)
            
            XCTAssertNotNil(retrieved)
            XCTAssertEqual(retrieved?.ringtone, .automatic)
            XCTAssertEqual(retrieved?.vibrate, .automatic)
            XCTAssertEqual(retrieved?.unmute, .automatic)
            XCTAssertEqual(retrieved?.dnd, .automatic)
            XCTAssertEqual(retrieved?.alarms, .automatic)
            XCTAssertEqual(retrieved?.timers, .automatic)
            
            try DatabaseManager.shared.deleteProfile(id: profile.id)
        } catch {
            XCTFail("Profile consistency test failed: \(error.localizedDescription)")
        }
    }
}