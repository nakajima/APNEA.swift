//
//  Route+cancel.swift
//
//
//  Created by Pat Nakajima on 3/31/24.
//

import APNEACore
import APNSCore
import Foundation
import Hummingbird

struct CancelRoute: Route, Sendable {
	func handle(request _: HummingbirdCore.Request, context: APNEAContext) async throws -> String {
		if let id = context.parameters.get("id") {
			try await context.scheduler.cancel(jobID: id)
			return "OK"
		} else {
			return "OK"
		}
	}
}
