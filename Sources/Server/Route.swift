//
//  Route.swift
//
//
//  Created by Pat Nakajima on 3/31/24.
//

import Foundation
import Hummingbird

protocol Route: Sendable {
	@Sendable func handle(request: Request, context: APNEAContext) async throws -> String
}
