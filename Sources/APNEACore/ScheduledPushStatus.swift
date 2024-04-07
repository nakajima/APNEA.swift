//
//  ScheduledPushStatus.swift
//
//
//  Created by Pat Nakajima on 3/31/24.
//

import Foundation

public enum ScheduledPushStatus: Codable, Identifiable, Equatable {
	public struct Scheduled: Codable, Identifiable, Equatable {
		public var id: String
		public var remainingOccurrences: Int
		public var interval: TimeInterval
		public var nextPush: Date

		public init(id: String, remainingOccurrences: Int, interval: TimeInterval, nextPush: Date) {
			self.id = id
			self.remainingOccurrences = remainingOccurrences
			self.interval = interval
			self.nextPush = nextPush
		}
	}

	case scheduled(Scheduled), finished(String)

	public var nextPushAt: Date? {
		switch self {
		case let .scheduled(scheduled):
			scheduled.nextPush
		case .finished:
			nil
		}
	}

	public var id: String {
		switch self {
		case let .scheduled(scheduled):
			scheduled.id
		case let .finished(uUID):
			uUID
		}
	}
}
