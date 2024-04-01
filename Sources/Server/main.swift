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
@preconcurrency import Hummingbird
import NIOCore

struct ContextProvider: RouterMiddleware {
	let scheduler: PushScheduler

	func handle(_ request: Request, context: APNEAContext, next: (Request, APNEAContext) async throws -> Response) async throws -> Response {
		context.scheduler = scheduler
		return try await next(request, context)
	}
}

final class App {
	let apns: APNSClient<JSONDecoder, JSONEncoder>
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
		let apns = APNSClient(
			configuration: .init(
				authenticationMethod: .jwt(
					privateKey: App.privateKey,
					keyIdentifier: App.env("KEY_IDENTIFIER"),
					teamIdentifier: App.env("TEAM_IDENTIFIER")
				),
				environment: .sandbox
			),
			eventLoopGroupProvider: .createNew,
			responseDecoder: JSONDecoder(),
			requestEncoder: JSONEncoder()
		)

		self.apns = apns
		self.scheduler = PushScheduler(apns: apns)
		self.schedulerTask = Task.detached {
			while true {
				await self.scheduler.run()
				try? await Task.sleep(for: .seconds(1))
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

		let application = Application(
			router: router,
			configuration: .init(address: .hostname("127.0.0.1", port: 4567))
		)

		try await application.runService()
	}
}

try await App().run()
