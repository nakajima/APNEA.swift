//
//  ScheduledPush.swift
//
//
//  Created by Pat Nakajima on 3/31/24.
//

import APNEACore
import APNS
import APNSCore
import Foundation
import Jobsy
import Logging
import MessagePack

struct ScheduledPush: Codable {
	var id: UUID
	var occurrences: Int = 1
	var interval: TimeInterval
	var nextPush: Date
	var payload: Data
	var error: String?
}

// Ummmm this should probably be better
actor PushScheduler {
	var logger = Logger(label: "push-scheduler")

	let scheduler = JobScheduler(redis: .dev(), kinds: [PushNotificationJob.self])

	enum Error: Swift.Error {
		case unsupportedMessage(String)
	}

	init() {}

	func status(id: UUID) async throws -> ScheduledPushStatus? {
		if case let .scheduled(schedule) = try await scheduler.status(jobID: id.uuidString) {
			let remaining: Int
			let interval: TimeInterval

			switch schedule.frequency {
			case .once:
				remaining = 0
				interval = -1
			case let .times(r, i):
				remaining = r
				interval = TimeInterval(i.components.seconds)
			case let .forever(i):
				remaining = -1
				interval = TimeInterval(i.components.seconds)
			}

			return .scheduled(
				.init(
					id: id,
					remainingOccurrences: remaining,
					interval: interval,
					nextPush: schedule.nextPushAt
				)
			)
		} else {
			return nil
		}
	}

	func run() async throws {
		try await Runner(scheduler: scheduler, pollInterval: 1).run()
	}

	func schedule(_ request: PushNotificationRequest) async throws {
		let job = try PushNotificationJob(
			id: request.id.uuidString,
			parameters: .init(payload: JSONEncoder().encode(request))
		)

		let schedule = request.schedule

		let repeats: JobFrequency = if schedule.occurrences == -1 {
			.forever(.seconds(schedule.interval))
		} else if schedule.occurrences == 1 {
			.once
		} else {
			.times(schedule.occurrences, .seconds(schedule.interval))
		}

		try await scheduler.push(
			job,
			performAt: request.schedule.sendAt,
			frequency: repeats
		)
	}
}
