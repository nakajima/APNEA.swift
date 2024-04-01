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
	var id: UUID
	var occurrences: Int = 1
	var interval: TimeInterval
	var nextPush: Date
	var payload: Data
	var error: String?
}

struct PushSchedulerSnapshot: Codable {
	var schedules: [UUID: ScheduledPush]
	var errored: [ScheduledPush]
	var completedIDs: Set<UUID>

	var description: String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .prettyPrinted
		if let data = try? encoder.encode(self) {
			return "Snapshot loaded:\n\(String(data: data, encoding: .utf8)!)"
		} else {
			return "Snapshot not loaded"
		}
	}
}

// Ummmm this should probably be better
actor PushScheduler {
	var schedules: [UUID: ScheduledPush] = [:]
	var errored: [ScheduledPush] = []
	var completedIDs: Set<UUID> = []
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
				let snapshot = try MessagePackDecoder().decode(PushSchedulerSnapshot.self, from: data)
				self.schedules = snapshot.schedules
				self.errored = snapshot.errored
				self.completedIDs = snapshot.completedIDs
				logger.info("Snapshot loaded:\n\(snapshot.description)")
			}
		} catch {
			logger.error("Error loading push scheduler from disk: \(error)")
		}
	}

	var snapshot: PushSchedulerSnapshot {
		PushSchedulerSnapshot(
			schedules: schedules,
			errored: errored,
			completedIDs: completedIDs
		)
	}

	func status(id: UUID) -> ScheduledPushStatus? {
		if let schedule = schedules[id] {
			return .scheduled(
				.init(
					id: id,
					remainingOccurrences: schedule.occurrences,
					interval: schedule.interval,
					nextPush: schedule.nextPush
				)
			)
		} else if completedIDs.contains(id) {
			return .finished(id)
		} else {
			return nil
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
				let data = try MessagePackEncoder().encode(snapshot)
				try data.write(to: saveURL)
			}
		} catch {
			logger.info("Error writing push scheduler to disk: \(error)")
		}
	}

	func schedule(_ request: PushNotificationRequest) async throws {
		let schedule = try ScheduledPush(
			id: request.id,
			occurrences: request.schedule.occurrences,
			interval: request.schedule.interval,
			nextPush: request.schedule.sendAt,
			payload: JSONEncoder().encode(request)
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
			completedIDs.insert(id)
		} else {
			schedules[id] = schedule
		}
	}
}
