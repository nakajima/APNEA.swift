//
//  main.swift
//
//
//  Created by Pat Nakajima on 3/31/24.
//

import APNEACore
import APNS
import APNSCore
import Crypto
import Foundation
import Hummingbird
import NIOCore

struct ContextProvider: RouterMiddleware {
	let scheduler: PushScheduler

	func handle(_ request: Request, context: APNEAContext, next: (Request, APNEAContext) async throws -> Response) async throws -> Response {
		context.scheduler = scheduler
		return try await next(request, context)
	}
}

final class App {
	let scheduler: PushScheduler
	var schedulerTask: Task<Void, Never>?

	static var privateKey: P256.Signing.PrivateKey = {
		do {
			return try P256.Signing.PrivateKey(
				pemRepresentation: env("PRIVATE_KEY")
			)
		} catch {
			fatalError("Error loading private key: \(error)")
		}
	}()

	static func env<T>(_ key: String, default defaultValue: String = "", cast: (String) -> T = { val in val }) -> T {
		cast(ProcessInfo.processInfo.environment[key] ?? defaultValue)
	}

	init() {
		self.scheduler = PushScheduler()
		self.schedulerTask = Task.detached {
			await self.scheduler.run()
		}
	}

	func run() async throws {
		let router = Router(context: APNEAContext.self)

		router.middlewares.add(LogRequestsMiddleware(.notice))
		router.middlewares.add(ContextProvider(scheduler: scheduler))

		router.get("ping") { _, _ -> String in
			"PONG"
		}

		router.post("schedule") { request, context -> String in
			try await SchedulerRoute().handle(request: request, context: context)
		}

		router.post("schedule/multiple") { request, context -> String in
			try await SchedulerRoute().handleMultiple(request: request, context: context)
		}

		router.get("status/:id") { request, context -> String in
			try await StatusRoute().handle(request: request, context: context)
		}

		router.post("statuses") { request, context -> String in
			try await StatusRoute().handleMultiple(request: request, context: context)
		}

		router.post("status/:id/cancel") { request, context -> String in
			try await StatusRoute().handle(request: request, context: context)
		}

		let application = Application(
			router: router,
			configuration: .init(
				address: .hostname(
					"localhost",
					port: App.env("PORT", default: "4567") { port in Int(port)! }
				)
			)
		)

		try await application.runService()
	}
}

try await App().run()
