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
import Logging
import MessagePack

struct ScheduledPush: Codable {
	var id = UUID()
	var occurrences: Int = 1
	var interval: TimeInterval
	var nextPush: Date
	var payload: Data
	var error: String?
}

// Ummmm this should probably be better
actor PushScheduler {
	var schedules: [UUID: ScheduledPush] = [:]
	var errored: [ScheduledPush] = []
	var apns: APNSClient<JSONDecoder, JSONEncoder>
	var logger = Logger(label: "push-scheduler")
	var saveURL = URL(string: "file://" + FileManager.default.currentDirectoryPath + "/schedule.db")

	enum Error: Swift.Error {
		case unsupportedMessage(String)
	}

	init(apns: APNSClient<JSONDecoder, JSONEncoder>) {
		self.apns = apns

		do {
			if let saveURL, FileManager.default.fileExists(atPath: saveURL.path) {
				let data = try Data(contentsOf: saveURL)
				let schedules = try MessagePackDecoder().decode([UUID: ScheduledPush].self, from: data)
				self.schedules = schedules
			}
		} catch {
			logger.error("Error loading push scheduler from disk: \(error)")
		}
	}

	func run() async {
		for (id, schedule) in schedules where schedule.error == nil {
			if schedule.nextPush < Date() {
				await handle(id: id, schedule: schedule)
			}
		}

		do {
			if let saveURL {
				let data = try MessagePackEncoder().encode(schedules)
				try data.write(to: saveURL)
			}
		} catch {
			logger.info("Error writing push scheduler to disk: \(error)")
		}
	}

	func schedule(occurrences: Int, interval: TimeInterval, nextPush: Date, payload: Data) async {
		logger.info("scheduling \(nextPush.formatted())")

		let schedule = ScheduledPush(
			occurrences: occurrences,
			interval: interval,
			nextPush: nextPush,
			payload: payload
		)

		await handle(id: schedule.id, schedule: schedule)
	}

	func deliver(request: PushNotificationRequest) async throws {
		func send(message: some APNSMessage) async throws {
			_ = try await apns.send(APNSRequest(
				message: message,
				deviceToken: request.deviceToken,
				pushType: request.pushType,
				expiration: request.expiration,
				priority: request.priority,
				apnsID: request.apnsID,
				topic: request.topic,
				collapseID: request.collapseID
			))
		}

		switch request.toAPNS() {
		case let n as APNSAlertNotification<PushNotificationRequest.Payload>:
			try await send(message: n)
		case let n as APNSBackgroundNotification<PushNotificationRequest.Payload>:
			try await send(message: n)
		default:
			throw Error.unsupportedMessage("Unsupported message type: \(request.message)")
		}
	}

	func handle(id: UUID, schedule: ScheduledPush) async {
		var schedule = schedule

		do {
			if schedule.nextPush < Date() {
				logger.info("schedule next push is in the past, delivering")
				let pushNotificationRequest = try JSONDecoder().decode(PushNotificationRequest.self, from: schedule.payload)

				try await deliver(request: pushNotificationRequest)

				schedule.nextPush = Date().addingTimeInterval(schedule.interval)
				schedule.occurrences -= 1
			}
		} catch {
			schedules[id] = nil
			schedule.error = error.localizedDescription
			errored.append(schedule)
			return
		}

		if schedule.occurrences == 0 {
			schedules[id] = nil
		} else {
			schedules[id] = schedule
		}
	}
}
