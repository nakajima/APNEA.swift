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
import HummingbirdJobs

struct SchedulerRoute: Route, Sendable {
	typealias RouteResponseGenerator = String

	func handle(request: Request, context: APNEAContext) async throws -> RouteResponseGenerator {
		do {
			let pushNotificationRequestData = try await request.body.collect(upTo: context.maxUploadSize)
			let pushNotificationRequest = try JSONDecoder().decode(PushNotificationRequest.self, from: pushNotificationRequestData)

			if pushNotificationRequest.topic != App.env("TOPIC") {
				return "NOPE"
			}

			try await context.scheduler.schedule(pushNotificationRequest)

		} catch {
			print("ERROR SCHEDULING: \(error)")
		}

		return "OK"
	}
}
