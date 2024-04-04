//
//  Route+status.swift
//
//
//  Created by Pat Nakajima on 3/31/24.
//

import APNEACore
import APNSCore
import Foundation
import Hummingbird

struct StatusRoute: Route, Sendable {
	func handle(request _: HummingbirdCore.Request, context: APNEAContext) async throws -> String {
		if let id = context.parameters.get("id"),
		   let uuid = UUID(uuidString: id),
		   let status = try await context.scheduler.status(id: uuid)
		{
			return try String(data: JSONEncoder().encode(status), encoding: .utf8) ?? "{}"
		} else {
			return "{}"
		}
	}
}
