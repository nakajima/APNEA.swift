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

final class App {
	let router = Router()
	let apns: APNSClient<JSONDecoder, JSONEncoder>

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
		self.apns = APNSClient(
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
	}

	func run() async throws {
		router.middlewares.add(LogRequestsMiddleware(.notice))

		router.get("ping") { _, _ -> String in
			"PONG"
		}

		router.post("schedule") { request, context -> String in
			do {
				let pushNotificationRequestData = try await request.body.collect(upTo: context.maxUploadSize)
				let pushNotificationRequest = try JSONDecoder().decode(PushNotificationRequest.self, from: pushNotificationRequestData)

				// Umm use an actual scheduler here
				if let sendAt = pushNotificationRequest.sendAt, sendAt > Date() {
					try! await Task.sleep(for: .seconds(sendAt.timeIntervalSince(Date())))
				}

				func send(message: some APNSMessage) async throws {
					_ = try await self.apns.send(APNSRequest(
						message: message,
						deviceToken: pushNotificationRequest.deviceToken,
						pushType: pushNotificationRequest.pushType,
						expiration: pushNotificationRequest.expiration,
						priority: pushNotificationRequest.priority,
						apnsID: pushNotificationRequest.apnsID,
						topic: pushNotificationRequest.topic,
						collapseID: pushNotificationRequest.collapseID
					))
				}

				switch pushNotificationRequest.toAPNS() {
				case let n as APNSAlertNotification<PushNotificationRequest.Payload>:
					try await send(message: n)
				case let n as APNSBackgroundNotification<PushNotificationRequest.Payload>:
					try await send(message: n)
				default:
					fatalError("Unsupported message type: \(pushNotificationRequest.message)")
				}
			} catch {
				print("ERROR SCHEDULING: \(error)")
			}

			return "OK"
		}

		let application = Application(
			router: router,
			configuration: .init(address: .hostname("127.0.0.1", port: 4567))
		)

		try await application.runService()
	}
}

try await App().run()
