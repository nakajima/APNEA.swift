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

			try await context.scheduler.schedule(
				occurrences: 1,
				interval: 0,
				nextPush: pushNotificationRequest.sendAt ?? .distantPast,
				// I couldn't figure out how to turn a byte buffer into a Data. I know.
				payload: JSONEncoder().encode(pushNotificationRequest)
			)

		} catch {
			print("ERROR SCHEDULING: \(error)")
		}

		return "OK"
	}
}
