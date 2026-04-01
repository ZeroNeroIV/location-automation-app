// Core/Models/Pattern.swift
import Foundation

public struct Pattern: Codable, Validatable {
    public let zoneId: UUID
    public var entryTimes: [Date]
    public var exitTimes: [Date]
    public var durations: [TimeInterval]
    public var dates: [Date]
    
    public init(
        zoneId: UUID,
        entryTimes: [Date] = [],
        exitTimes: [Date] = [],
        durations: [TimeInterval] = [],
        dates: [Date] = []
    ) {
        self.zoneId = zoneId
        self.entryTimes = entryTimes
        self.exitTimes = exitTimes
        self.durations = durations
        self.dates = dates
    }
}

extension Pattern {
    public func validate() throws {
        guard !entryTimes.isEmpty || !exitTimes.isEmpty || !dates.isEmpty else {
            throw PatternValidationError.emptyPattern
        }
    }
}

public enum PatternValidationError: Error, LocalizedError {
    case emptyPattern
    
    public var errorDescription: String? {
        switch self {
        case .emptyPattern:
            return "Pattern must have at least one time or date constraint"
        }
    }
}