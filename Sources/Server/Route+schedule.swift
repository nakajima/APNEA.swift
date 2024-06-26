//
//  Route+schedule.swift
//
//
//  Created by Pat Nakajima on 3/31/24.
//

import APNEACore
import APNSCore
import Foundation
import Hummingbird

struct SchedulerRoute: Route, Sendable {
	func handle(request: HummingbirdCore.Request, context: APNEAContext) async throws -> String {
		do {
			let pushNotificationRequestData = try await request.body.collect(upTo: context.maxUploadSize)
			let pushNotificationRequest = try JSONDecoder().decode(PushNotificationRequest.self, from: pushNotificationRequestData)

			if !pushNotificationRequest.topic.starts(with: App.env("TOPIC")) {
				return "NOPE"
			}

			try await context.scheduler.schedule(pushNotificationRequest)

		} catch {
			print("ERROR SCHEDULING: \(error)")
		}

		return "OK"
	}

	func handleMultiple(request: HummingbirdCore.Request, context: APNEAContext) async throws -> String {
		let requests = try await JSONDecoder().decode([PushNotificationRequest].self, from: request.body.collect(upTo: context.maxUploadSize))

		for request in requests {
			guard request.topic.starts(with: App.env("TOPIC")) else {
				continue
			}

			do {
				try await context.scheduler.schedule(request)
			} catch {
				context.logger.error("error scheduling \(request.id): \(error)")
			}
		}

		return "OK"
	}
}
