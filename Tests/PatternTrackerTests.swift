import XCTest
@testable import LocationAutomation

final class PatternTrackerTests: XCTestCase {
    
    var tracker: PatternTracker!
    var testZoneId: UUID!
    
    override func setUp() {
        super.setUp()
        tracker = PatternTracker.shared
        testZoneId = UUID()
        
        // Setup database for tests
        do {
            try DatabaseManager.shared.createTables()
        } catch {
            // Database may already exist
        }
    }
    
    override func tearDown() {
        // Clean up test data
        try? DatabaseManager.shared.deletePattern(zoneId: testZoneId)
        super.tearDown()
    }
    
    func testRecordEntryCreatesPattern() {
        let initialCount = tracker.getVisitCount(for: testZoneId)
        
        tracker.recordEntry(zoneId: testZoneId)
        
        let newCount = tracker.getVisitCount(for: testZoneId)
        XCTAssertEqual(newCount, initialCount + 1, "Entry should increment visit count")
    }
    
    func testRecordEntryAndExitCalculatesDuration() {
        let entryTime = Date()
        
        tracker.recordEntry(zoneId: testZoneId)
        
        // Small delay to ensure measurable duration
        Thread.sleep(forTimeInterval: 0.1)
        
        tracker.recordExit(zoneId: testZoneId)
        
        if let avgDuration = tracker.getAverageDuration(for: testZoneId) {
            XCTAssertGreaterThan(avgDuration, 0, "Duration should be positive")
        }
    }
    
    func testPendingEntryTracking() {
        XCTAssertFalse(tracker.hasPendingEntry(for: testZoneId), "Should not have pending entry initially")
        
        tracker.recordEntry(zoneId: testZoneId)
        
        XCTAssertTrue(tracker.hasPendingEntry(for: testZoneId), "Should have pending entry after recordEntry")
        
        tracker.recordExit(zoneId: testZoneId)
        
        XCTAssertFalse(tracker.hasPendingEntry(for: testZoneId), "Should not have pending entry after recordExit")
    }
    
    func testClearPendingEntry() {
        tracker.recordEntry(zoneId: testZoneId)
        
        XCTAssertTrue(tracker.hasPendingEntry(for: testZoneId))
        
        tracker.clearPendingEntry(for: testZoneId)
        
        XCTAssertFalse(tracker.hasPendingEntry(for: testZoneId))
    }
    
    func testGetPatternReturnsPattern() {
        tracker.recordEntry(zoneId: testZoneId)
        
        let pattern = tracker.getPattern(for: testZoneId)
        
        XCTAssertNotNil(pattern, "Pattern should exist after recording entry")
        XCTAssertEqual(pattern?.zoneId, testZoneId)
    }
    
    func testGetVisitCount() {
        let initialCount = tracker.getVisitCount(for: testZoneId)
        
        for _ in 0..<3 {
            tracker.recordEntry(zoneId: testZoneId)
            tracker.clearPendingEntry(for: testZoneId)
        }
        
        let finalCount = tracker.getVisitCount(for: testZoneId)
        XCTAssertEqual(finalCount, initialCount + 3, "Visit count should match number of entries")
    }
    
    func testDayOfWeekPatternFiltering() {
        // Create entries for both weekday and weekend
        let calendar = Calendar.current
        
        // Add weekday entries
        if let nextMonday = calendar.date(byAdding: .day, value: 7, to: Date()) {
            var pattern = Pattern(zoneId: testZoneId)
            pattern.entryTimes.append(nextMonday)
            pattern.durations.append(3600)
            pattern.dates.append(nextMonday)
            try? DatabaseManager.shared.savePattern(pattern)
        }
        
        let weekdayPattern = tracker.getDayOfWeekPattern(for: testZoneId, isWeekday: true)
        let weekendPattern = tracker.getDayOfWeekPattern(for: testZoneId, isWeekday: false)
        
        XCTAssertNotNil(weekdayPattern, "Weekday pattern should exist")
        XCTAssertNotNil(weekendPattern, "Weekend pattern should exist")
    }
    
    func testMostFrequentEntryHour() {
        // Record multiple entries at same hour
        let calendar = Calendar.current
        let baseDate = Date()
        
        var pattern = Pattern(zoneId: testZoneId)
        
        // Add entries at 9 AM
        for i in 0..<3 {
            if let date = calendar.date(byAdding: .hour, value: i * 24, to: baseDate) {
                pattern.entryTimes.append(date)
                pattern.durations.append(1800)
            }
        }
        
        try? DatabaseManager.shared.savePattern(pattern)
        
        if let hour = tracker.getMostFrequentEntryHour(for: testZoneId) {
            XCTAssertEqual(hour, calendar.component(.hour, from: baseDate), "Most frequent hour should be 9 AM")
        }
    }
    
    func testAverageDuration() {
        var pattern = Pattern(zoneId: testZoneId)
        pattern.durations = [100, 200, 300]
        try? DatabaseManager.shared.savePattern(pattern)
        
        if let avg = tracker.getAverageDuration(for: testZoneId) {
            XCTAssertEqual(avg, 200, "Average should be 200")
        }
    }
    
    func testCleanupOldData() {
        let calendar = Calendar.current
        
        // Create old data
        var pattern = Pattern(zoneId: testZoneId)
        if let oldDate = calendar.date(byAdding: .day, value: -100, to: Date()) {
            pattern.entryTimes.append(oldDate)
            pattern.exitTimes.append(oldDate)
            pattern.durations.append(100)
            pattern.dates.append(oldDate)
        }
        
        // Add recent data
        pattern.entryTimes.append(Date())
        pattern.exitTimes.append(Date())
        pattern.durations.append(200)
        pattern.dates.append(Date())
        
        try? DatabaseManager.shared.savePattern(pattern)
        
        tracker.cleanupOldData(olderThan: 30)
        
        let cleanedPattern = tracker.getPattern(for: testZoneId)
        XCTAssertEqual(cleanedPattern?.entryTimes.count, 1, "Old entries should be removed")
    }
}