//
//  PushNotificationJob.swift
//
//
//  Created by Pat Nakajima on 4/2/24.
//

import APNEACore
import APNSCore
import Foundation
import Jobsy

struct PushNotificationJob: Job {
	struct Parameters: Codable {
		var payload: Data
	}

	var id: String
	var parameters: Parameters

	func perform() async throws {
		let request = try JSONDecoder().decode(PushNotificationRequest.self, from: parameters.payload)

		func send(message: some APNSMessage) async throws {
			_ = try await APNS.send(APNSRequest(
				message: message,
				deviceToken: request.deviceToken,
				pushType: request.pushType,
				expiration: request.expiration,
				priority: request.priority,
				apnsID: UUID(),
				topic: request.topic,
				collapseID: request.id.uuidString
			))
		}

		switch request.toAPNS() {
		case let n as APNSAlertNotification<PushNotificationRequest.Payload>:
			try await send(message: n)
		case let n as APNSBackgroundNotification<PushNotificationRequest.Payload>:
			try await send(message: n)
		default:
			throw PushScheduler.Error.unsupportedMessage("Unsupported message type: \(request.message)")
		}
	}

	init(id: String, parameters: Parameters) {
		self.id = id
		self.parameters = parameters
	}
}
