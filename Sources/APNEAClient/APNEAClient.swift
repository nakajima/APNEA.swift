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

	public func status(id: UUID) async throws -> ScheduledPushStatus? {
		let url = url.appending(path: "status/\(id.uuidString)")
		let (data, _) = try await URLSession.shared.data(from: url)
		print("STATUS \(String(data: data, encoding: .utf8)!)")

		return try JSONDecoder().decode(ScheduledPushStatus.self, from: data)
	}

	public func statuses(ids: [UUID]) async throws -> [UUID: ScheduledPushStatus] {
		return try await withThrowingTaskGroup(of: ScheduledPushStatus?.self) { group in
			for id in ids {
				group.addTask {
					try? await self.status(id: id)
				}
			}

			var result: [UUID: ScheduledPushStatus] = [:]

			for try await status in group {
				if let status {
					result[status.id] = status
				}
			}

			return result
		}
	}

	public func schedule(_ pushNotificationRequest: PushNotificationRequest) async throws {
		let data = try encoder.encode(pushNotificationRequest)

		let url = url.appending(path: "schedule")
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
