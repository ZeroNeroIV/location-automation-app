import XCTest
@testable import LocationAutomation

final class DeviationDetectorTests: XCTestCase {
    
    var detector: DeviationDetector!
    var testZoneId: UUID!
    
    override func setUp() {
        super.setUp()
        detector = DeviationDetector.shared
        testZoneId = UUID()
        
        do {
            try DatabaseManager.shared.createTables()
        } catch {
            // Database may already exist
        }
        
        // Clean up any existing test data
        try? DatabaseManager.shared.deletePattern(zoneId: testZoneId)
    }
    
    override func tearDown() {
        try? DatabaseManager.shared.deletePattern(zoneId: testZoneId)
        super.tearDown()
    }
    
    // MARK: - Statistical Calculation Tests
    
    func testCalculateMean() {
        let values: [TimeInterval] = [100, 200, 300, 400, 500]
        
        let mean = detector.calculateMean(values)
        
        XCTAssertNotNil(mean)
        XCTAssertEqual(mean!, 300, "Mean of 100,200,300,400,500 should be 300")
    }
    
    func testCalculateMeanEmptyArray() {
        let values: [TimeInterval] = []
        
        let mean = detector.calculateMean(values)
        
        XCTAssertNil(mean, "Mean of empty array should be nil")
    }
    
    func testCalculateStandardDeviation() {
        let values: [TimeInterval] = [100, 200, 300, 400, 500]
        
        let mean = detector.calculateMean(values)
        let stdDev = detector.calculateStandardDeviation(values, mean: mean)
        
        XCTAssertNotNil(stdDev)
        // Standard deviation should be ~158.11 for this dataset
        XCTAssertGreaterThan(stdDev!, 150)
        XCTAssertLessThan(stdDev!, 170)
    }
    
    func testCalculateStandardDeviationInsufficientData() {
        let values: [TimeInterval] = [100]
        
        let stdDev = detector.calculateStandardDeviation(values)
        
        XCTAssertNil(stdDev, "StdDev should be nil for single value")
    }
    
    func testCalculateStandardDeviationTwoValues() {
        let values: [TimeInterval] = [100, 200]
        
        let stdDev = detector.calculateStandardDeviation(values)
        
        XCTAssertNotNil(stdDev, "StdDev should work with exactly 2 values")
    }
    
    // MARK: - Entry Time Analysis Tests
    
    func testSecondsFromMidnight() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 9
        components.minute = 30
        components.second = 15
        
        guard let date = calendar.date(from: components) else {
            XCTFail("Failed to create test date")
            return
        }
        
        let seconds = detector.secondsFromMidnight(for: date)
        
        XCTAssertEqual(seconds, 9 * 3600 + 30 * 60 + 15, "Should calculate seconds from midnight correctly")
    }
    
    func testSecondsFromMidnightMidnight() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        guard let date = calendar.date(from: components) else {
            XCTFail("Failed to create test date")
            return
        }
        
        let seconds = detector.secondsFromMidnight(for: date)
        
        XCTAssertEqual(seconds, 0, "Midnight should be 0 seconds")
    }
    
    func testSecondsFromMidnightEndOfDay() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        guard let date = calendar.date(from: components) else {
            XCTFail("Failed to create test date")
            return
        }
        
        let seconds = detector.secondsFromMidnight(for: date)
        
        XCTAssertEqual(seconds, 23 * 3600 + 59 * 60 + 59, "End of day should be 86399 seconds")
    }
    
    func testGetMeanEntryTimeInsufficientData() {
        // Add only 2 entries (less than minimum 5)
        var pattern = Pattern(zoneId: testZoneId)
        pattern.entryTimes = [Date(), Date()]
        try? DatabaseManager.shared.savePattern(pattern)
        
        let mean = detector.getMeanEntryTime(for: testZoneId)
        
        XCTAssertNil(mean, "Should return nil when insufficient data")
    }
    
    func testGetMeanEntryTimeWithSufficientData() {
        // Add 5+ entries
        var pattern = Pattern(zoneId: testZoneId)
        let calendar = Calendar.current
        
        for i in 0..<5 {
            var components = DateComponents()
            components.hour = 9
            components.minute = 0
            if let date = calendar.date(byAdding: .minute, value: i * 10, to: Date()) {
                pattern.entryTimes.append(date)
            }
        }
        
        try? DatabaseManager.shared.savePattern(pattern)
        
        let mean = detector.getMeanEntryTime(for: testZoneId)
        
        XCTAssertNotNil(mean, "Should return mean when sufficient data")
    }
    
    // MARK: - Duration Analysis Tests
    
    func testGetMeanDurationInsufficientData() {
        var pattern = Pattern(zoneId: testZoneId)
        pattern.durations = [100, 200]
        try? DatabaseManager.shared.savePattern(pattern)
        
        let mean = detector.getMeanDuration(for: testZoneId)
        
        XCTAssertNil(mean, "Should return nil when insufficient duration data")
    }
    
    func testGetMeanDurationWithSufficientData() {
        var pattern = Pattern(zoneId: testZoneId)
        pattern.durations = [100, 200, 300, 400, 500]
        try? DatabaseManager.shared.savePattern(pattern)
        
        let mean = detector.getMeanDuration(for: testZoneId)
        
        XCTAssertEqual(mean, 300, "Mean duration should be 300")
    }
    
    func testGetDurationStdDev() {
        var pattern = Pattern(zoneId: testZoneId)
        pattern.durations = [100, 200, 300, 400, 500]
        try? DatabaseManager.shared.savePattern(pattern)
        
        let stdDev = detector.getDurationStdDev(for: testZoneId)
        
        XCTAssertNotNil(stdDev, "Should calculate std dev")
    }
    
    // MARK: - Day of Week Analysis Tests
    
    func testWeekdayVsWeekendFiltering() {
        var pattern = Pattern(zoneId: testZoneId)
        let calendar = Calendar.current
        
        // Add weekday entries (Monday = 2)
        if let wednesday = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) {
            // Get next Wednesday
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            components.weekday = 4 // Wednesday
            if let wed = calendar.date(from: components) {
                pattern.entryTimes.append(wed)
                pattern.durations.append(3600)
            }
        }
        
        // Add weekend entries
        if let sunday = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) {
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            components.weekday = 1 // Sunday
            if let sun = calendar.date(from: components) {
                pattern.entryTimes.append(sun)
                pattern.durations.append(7200)
            }
        }
        
        try? DatabaseManager.shared.savePattern(pattern)
        
        // Test weekday filtering
        let weekdayMean = detector.getMeanEntryTime(for: testZoneId, isWeekday: true)
        
        // Test weekend filtering
        let weekendMean = detector.getMeanEntryTime(for: testZoneId, isWeekday: false)
        
        XCTAssertNotNil(weekdayMean, "Weekday mean should exist")
        XCTAssertNotNil(weekendMean, "Weekend mean should exist")
    }
    
    // MARK: - Deviation Detection Tests
    
    func testDetectEntryTimeDeviationInsufficientData() {
        var pattern = Pattern(zoneId: testZoneId)
        pattern.entryTimes = [Date(), Date()]
        try? DatabaseManager.shared.savePattern(pattern)
        
        let result = detector.detectEntryTimeDeviation(for: testZoneId)
        
        XCTAssertNil(result, "Should return nil with insufficient data")
    }
    
    func testDetectAllDeviationsReturnsEmptyForInsufficientData() {
        var pattern = Pattern(zoneId: testZoneId)
        pattern.entryTimes = [Date()]
        pattern.durations = [100]
        try? DatabaseManager.shared.savePattern(pattern)
        
        let results = detector.detectAllDeviations(for: testZoneId)
        
        XCTAssertTrue(results.isEmpty, "Should return empty array with insufficient data")
    }
    
    func testHasSufficientData() {
        var pattern = Pattern(zoneId: testZoneId)
        pattern.entryTimes = [Date(), Date(), Date(), Date(), Date()]
        try? DatabaseManager.shared.savePattern(pattern)
        
        let hasData = detector.hasSufficientData(for: testZoneId)
        
        XCTAssertTrue(hasData, "Should have sufficient data with 5 entries")
    }
    
    func testHasSufficientDataFalse() {
        var pattern = Pattern(zoneId: testZoneId)
        pattern.entryTimes = [Date(), Date()]
        try? DatabaseManager.shared.savePattern(pattern)
        
        let hasData = detector.hasSufficientData(for: testZoneId)
        
        XCTAssertFalse(hasData, "Should not have sufficient data with only 2 entries")
    }
    
    func testGetMinimumVisits() {
        let minVisits = detector.getMinimumVisits()
        
        XCTAssertEqual(minVisits, 5, "Minimum visits should be 5")
    }
    
    func testDefaultDeviationThreshold() {
        let threshold = DeviationDetector.defaultDeviationThreshold
        
        XCTAssertEqual(threshold, 1800, "Default threshold should be 30 minutes")
    }
    
    // MARK: - Statistics Tests
    
    func testGetStatisticsInsufficientData() {
        var pattern = Pattern(zoneId: testZoneId)
        pattern.entryTimes = [Date()]
        try? DatabaseManager.shared.savePattern(pattern)
        
        let stats = detector.getStatistics(for: testZoneId)
        
        XCTAssertNil(stats, "Should return nil with insufficient data")
    }
    
    func testGetStatisticsWithSufficientData() {
        var pattern = Pattern(zoneId: testZoneId)
        let calendar = Calendar.current
        
        for i in 0..<5 {
            var components = DateComponents()
            components.hour = 9
            components.minute = i * 10
            if let date = calendar.date(from: components) {
                pattern.entryTimes.append(date)
                pattern.durations.append(3600 + Double(i * 100))
            }
        }
        
        try? DatabaseManager.shared.savePattern(pattern)
        
        let stats = detector.getStatistics(for: testZoneId)
        
        XCTAssertNotNil(stats, "Should return statistics")
        XCTAssertEqual(stats?.totalVisits, 5, "Should have 5 visits")
        XCTAssertNotNil(stats?.overallEntryMean, "Should have entry mean")
        XCTAssertNotNil(stats?.overallDurationMean, "Should have duration mean")
    }
    
    // MARK: - Configuration Tests
    
    func testCustomDeviationThreshold() {
        let customThreshold: TimeInterval = 900 // 15 minutes
        
        detector.deviationThreshold = customThreshold
        
        XCTAssertEqual(detector.deviationThreshold, customThreshold, "Should allow custom threshold")
    }
    
    func testCustomMinimumVisits() {
        let customMinimum = 3
        
        detector.minimumVisits = customMinimum
        
        XCTAssertEqual(detector.minimumVisits, customMinimum, "Should allow custom minimum")
    }
    
    // MARK: - Edge Cases
    
    func testMeanOfSingleValue() {
        let values: [TimeInterval] = [500]
        
        let mean = detector.calculateMean(values)
        
        XCTAssertEqual(mean, 500, "Mean of single value should be that value")
    }
    
    func testStdDevOfIdenticalValues() {
        let values: [TimeInterval] = [300, 300, 300, 300, 300]
        
        let stdDev = detector.calculateStandardDeviation(values)
        
        XCTAssertEqual(stdDev, 0, "StdDev of identical values should be 0")
    }
    
    func testMultipleDayTypesInSamePattern() {
        var pattern = Pattern(zoneId: testZoneId)
        
        // Create a mixed pattern with both weekday and weekend entries
        // This tests that filtering works correctly
        let calendar = Calendar.current
        
        // Create weekday-like dates (using timestamp manipulation)
        let baseTime = Date().timeIntervalSince1970
        for i in 0..<3 {
            let weekdayTime = baseTime + Double(i * 86400 * 7) // Every 7 days to ensure same weekday
            let date = Date(timeIntervalSince1970: weekdayTime)
            pattern.entryTimes.append(date)
            pattern.durations.append(3600)
        }
        
        try? DatabaseManager.shared.savePattern(pattern)
        
        let weekdayPattern = PatternTracker.shared.getDayOfWeekPattern(for: testZoneId, isWeekday: true)
        
        XCTAssertNotNil(weekdayPattern, "Should filter by weekday")
    }
}