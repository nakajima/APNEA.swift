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

	static func env(_ key: String) -> String {
		ProcessInfo.processInfo.environment[key] ?? ""
	}

	init() {
		self.scheduler = PushScheduler()
		self.schedulerTask = Task.detached {
			do {
				try await self.scheduler.run()
			} catch {
				fatalError("did not run scheduler: \(error)")
			}
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

		router.get("status/:id") { request, context -> String in
			try await StatusRoute().handle(request: request, context: context)
		}

		let application = Application(
			router: router,
			configuration: .init(address: .hostname("127.0.0.1", port: 4567))
		)

		try await application.runService()
	}
}

try await App().run()
