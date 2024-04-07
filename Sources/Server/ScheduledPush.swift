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
import RediStack

struct ScheduledPush: Codable, Sendable {
	var id: String
	var occurrences: Int = 1
	var interval: TimeInterval
	var nextPush: Date
	var payload: Data
	var error: String?
}

// Ummmm this should probably be better
actor PushScheduler {
	var logger: Logger = Logger(label: "PushScheduler")
	let scheduler: JobScheduler

	enum Error: Swift.Error {
		case unsupportedMessage(String)
	}

	init() {
		self.scheduler = JobScheduler(redis: .url(App.env("REDIS_URL")), kinds: [PushNotificationJob.self], queue: App.env("QUEUE", default: "default"), logger: logger)
	}

	func cancel(jobID: String) async throws {
		try await scheduler.cancel(jobID: jobID)
	}

	func statuses(ids: [String]) async -> [String: ScheduledPushStatus] {
		await withTaskGroup(of: (ScheduledPushStatus?).self) { group in
			for id in ids {
				group.addTask {
					do {
						return try await self.status(id: id)
					} catch {
						return nil
					}
				}
			}

			var result: [String: ScheduledPushStatus] = [:]

			for await status in group {
				guard let status else { continue }
				result[status.id] = status
			}

			return result
		}
	}

	func status(id: String) async throws -> ScheduledPushStatus? {
		if case let .scheduled(schedule) = try await scheduler.status(jobID: id) {
			let remaining: Int
			let interval: TimeInterval

			switch schedule.frequency {
			case .once:
				remaining = 0
				interval = -2
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

	func run() async {
		await Runner(pollInterval: 1).run(
			connection: .url(App.env("REDIS_URL")),
			for: [PushNotificationJob.self],
			queue: App.env("QUEUE", default: "default"),
			logger: logger
		)
	}

	func schedule(_ request: PushNotificationRequest) async throws {
		let job = try PushNotificationJob(
			id: request.id,
			parameters: .init(payload: JSONEncoder().encode(request))
		)

		let schedule = request.schedule

		let repeats: JobFrequency = if schedule.occurrences == -1 {
			.forever(.seconds(schedule.interval))
		} else if schedule.occurrences == JobScheduler.onceRemaining {
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
