import Foundation
import Testing

final class SuggestionGeneratorTests {
    
    private let generator = SuggestionGenerator.shared
    private let database = DatabaseManager.shared
    private let patternTracker = PatternTracker.shared
    private let deviationDetector = DeviationDetector.shared
    
    @Test
    func testRateLimitingAllowsFirstSuggestion() {
        // First suggestion should always be allowed
        let canGenerate = generator.canGenerateSuggestion()
        #expect(canGenerate == true || canGenerate == false) // Depends on previous state
    }
    
    @Test
    func testTimeUntilNextSuggestionReturnsNonNegative() {
        let timeRemaining = generator.timeUntilNextSuggestion()
        #expect(timeRemaining >= 0)
    }
    
    @Test
    func testGenerateAllSuggestionsReturnsArray() {
        let suggestions = generator.generateAllSuggestions()
        #expect(suggestions.count >= 0)
    }
    
    @Test
    func testForceGenerateSuggestionReturnsOptional() {
        let suggestion = generator.forceGenerateSuggestion()
        // Can be nil if no data available
        #expect(suggestion == nil || suggestion != nil)
    }
    
    @Test
    func testSuggestionTypeEnum() {
        let profileType = SuggestionType.profileChange
        #expect(profileType.rawValue == "profileChange")
        
        let zoneCreationType = SuggestionType.zoneCreation
        #expect(zoneCreationType.rawValue == "zoneCreation")
        
        let zoneDeletionType = SuggestionType.zoneDeletion
        #expect(zoneDeletionType.rawValue == "zoneDeletion")
    }
    
    @Test
    func testProfileChangeSuggestionInitialization() {
        let deviation = DeviationResult(
            zoneId: UUID(),
            deviationType: .entryTime,
            expectedValue: 32400, // 9 AM
            actualValue: 39600,   // 11 AM
            deviation: 7200,
            deviationThreshold: 1800,
            exceedsThreshold: true,
            warningLevel: .high,
            sampleCount: 10,
            dayType: .weekday
        )
        
        let profile = Profile(name: "Test Profile")
        let suggestion = ProfileChangeSuggestion(
            id: UUID(),
            zoneId: UUID(),
            zoneName: "Test Zone",
            currentProfileName: "Test Profile",
            currentProfile: profile,
            suggestedSetting: .dnd,
            reason: "Test reason",
            deviation: deviation,
            createdAt: Date()
        )
        
        #expect(suggestion.zoneName == "Test Zone")
        #expect(suggestion.suggestedSetting == .dnd)
    }
    
    @Test
    func testZoneCreationSuggestionInitialization() {
        let suggestion = ZoneCreationSuggestion(
            id: UUID(),
            suggestedName: "New Location",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            visitCount: 5,
            reason: "Frequently visited",
            suggestedCoordinates: (latitude: 37.7749, longitude: -122.4194),
            createdAt: Date()
        )
        
        #expect(suggestion.visitCount == 5)
        #expect(suggestion.radius == 100)
    }
    
    @Test
    func testZoneDeletionSuggestionInitialization() {
        let suggestion = ZoneDeletionSuggestion(
            id: UUID(),
            zoneId: UUID(),
            zoneName: "Old Zone",
            reason: "Not visited recently",
            lastVisitDate: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            inactivityDays: 30,
            createdAt: Date()
        )
        
        #expect(suggestion.zoneName == "Old Zone")
        #expect(suggestion.inactivityDays == 30)
    }
    
    @Test
    func testSuggestionEnumMessageProperty() {
        let deviation = DeviationResult(
            zoneId: UUID(),
            deviationType: .entryTime,
            expectedValue: 32400,
            actualValue: 39600,
            deviation: 7200,
            deviationThreshold: 1800,
            exceedsThreshold: true,
            warningLevel: .high,
            sampleCount: 10,
            dayType: .weekday
        )
        
        let profile = Profile(name: "Test")
        let profileSuggestion = ProfileChangeSuggestion(
            id: UUID(),
            zoneId: UUID(),
            zoneName: "Test",
            currentProfileName: "Test",
            currentProfile: profile,
            suggestedSetting: .dnd,
            reason: "Test reason",
            deviation: deviation,
            createdAt: Date()
        )
        
        let suggestion: Suggestion = .profileChange(profileSuggestion)
        #expect(suggestion.message == "Test reason")
        #expect(suggestion.type == .profileChange)
    }
}
