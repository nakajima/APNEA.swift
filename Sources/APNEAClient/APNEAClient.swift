//
//  APNEAClient.swift
//
//
//  Created by Pat Nakajima on 3/31/24.
//

import APNEACore
import Foundation
import Observation

@Observable public final class APNEAClient {
	public enum Error: Swift.Error {}

	let url: URL
	let encoder = JSONEncoder()

	public init(url: URL) {
		self.url = url
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
