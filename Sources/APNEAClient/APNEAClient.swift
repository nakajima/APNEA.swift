//
//  APNEAClient.swift
//
//
//  Created by Pat Nakajima on 3/31/24.
//

import APNSCore
import APNEACore
import Foundation
import Observation

public struct PushNotificationRequestContainer<Message: APNSMessage> {
	public struct Payload: Encodable, Sendable {
		public init() {}
	}

	public var id: String
	public var deviceToken: String
	public var pushType: APNSPushType
	public var expiration: APNSNotificationExpiration?
	public var priority: APNSPriority?
	public var apnsID: UUID?
	public var topic: String
	public var collapseID: String?
	public var message: APNSMessage
	public var schedule: PushNotificationSchedule

	public init(
		id: String,
		deviceToken: String,
		pushType: APNSPushType,
		message: Message,
		expiration: APNSNotificationExpiration? = nil,
		priority: APNSPriority? = nil,
		apnsID: UUID? = nil,
		topic: String,
		collapseID: String? = nil,
		schedule: PushNotificationSchedule
	) {
		self.id = id
		self.deviceToken = deviceToken
		self.pushType = pushType
		self.expiration = expiration
		self.priority = priority
		self.apnsID = apnsID
		self.topic = topic
		self.collapseID = collapseID
		self.message = message
		self.schedule = schedule
	}

	func toRequest() throws -> PushNotificationRequest {
		PushNotificationRequest(
			id: id,
			message: try JSONEncoder().encode(message),
			deviceToken: deviceToken,
			pushType: pushType,
			expiration: expiration,
			priority: priority,
			apnsID: apnsID,
			topic: topic,
			collapseID: collapseID,
			schedule: schedule
		)
	}
}

@Observable public final class APNEAClient: Sendable {
	public enum Error: Swift.Error {}

	let url: URL
	let encoder = JSONEncoder()

	public init(url: URL) {
		self.url = url
	}

	public func status(id: String) async throws -> ScheduledPushStatus? {
		let url = url.appending(path: "status/\(id)")
		let (data, _) = try await URLSession.shared.data(from: url)

		return try? JSONDecoder().decode(ScheduledPushStatus.self, from: data)
	}

	public func cancel(id: String) async throws {
		let url = url.appending(path: "status/\(id)/cancel")

		var request = URLRequest(url: url)
		request.httpMethod = "POST"

		_ = try await URLSession.shared.data(for: request)
	}

	public func statuses(ids: [String]) async throws -> [String: ScheduledPushStatus] {
		let url = url.appending(path: "statuses")

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = try JSONEncoder().encode(ids)

		let (data, _) = try await URLSession.shared.data(for: request)
		return try JSONDecoder().decode([String: ScheduledPushStatus].self, from: data)
	}

	public func schedule<Message: APNSMessage>(_ container: PushNotificationRequestContainer<Message>) async throws {
		let data = try encoder.encode(container.toRequest())

		let url = url.appending(path: "schedule")
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = data

		_ = try await URLSession.shared.data(for: request)
	}

	public func schedule(_ pushNotificationRequests: [PushNotificationRequest]) async throws {
		let data = try encoder.encode(pushNotificationRequests)

		let url = url.appending(path: "schedule/multiple")
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = data

		_ = try await URLSession.shared.data(for: request)
	}

	public func verify() async -> Bool {
		do {
			let (data, _) = try await URLSession.shared.data(from: url.appendingPathComponent("ping"))
			return String(data: data, encoding: .utf8) == "PONG"
		} catch {
			return false
		}
	}
}
