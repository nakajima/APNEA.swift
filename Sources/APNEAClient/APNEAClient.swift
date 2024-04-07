//
//  APNEAClient.swift
//
//
//  Created by Pat Nakajima on 3/31/24.
//

import APNEACore
import Foundation
import Observation

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

	public func schedule(_ pushNotificationRequest: PushNotificationRequest) async throws {
		let data = try encoder.encode(pushNotificationRequest)

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
