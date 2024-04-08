//
//  PushNotificationJob.swift
//
//
//  Created by Pat Nakajima on 4/2/24.
//

import APNEACore
import APNSCore
import Foundation
import Jobsy
import NIOCore
import NIOHTTP1
import Logging

struct PushNotificationJob: Job {
	struct Parameters: Codable {
		var payload: Data
	}

	var id: String
	var parameters: Parameters
	var logger = Logger(label: "PushNotificationJob")

	func headers(for request: PushNotificationRequest) async throws -> HTTPHeaders {
		var headers = APNS.defaultRequestHeaders

		// Push type
		headers.add(name: "apns-push-type", value: request.pushType.configuration.rawValue)

		// APNS ID
		if let apnsID = request.apnsID {
			headers.add(name: "apns-id", value: apnsID.uuidString.lowercased())
		}

		// Expiration
		if let expiration = request.expiration?.expiration {
			headers.add(name: "apns-expiration", value: String(expiration))
		}

		// Priority
		if let priority = request.priority?.rawValue {
			headers.add(name: "apns-priority", value: String(priority))
		}

		// Topic
		headers.add(name: "apns-topic", value: request.topic)

		// Collapse ID
		if let collapseID = request.collapseID {
			headers.add(name: "apns-collapse-id", value: collapseID)
		}

		// Authorization token
		if let authenticationTokenManager = APNS.authenticationTokenManager {
			let token = try await authenticationTokenManager.nextValidToken
			headers.add(name: "authorization", value: token)
		}

		return headers
	}

	func perform() async throws {
		let request = try JSONDecoder().decode(PushNotificationRequest.self, from: parameters.payload)
		let logger = self.logger ?? Logger(label: "Jobsy")

		logger.debug("sending \(String(data: parameters.payload, encoding: .utf8))")

		let headers = try await headers(for: request)

		do {
			let response = try await APNS.send(byteBuffer: ByteBuffer(bytes: request.message), headers: headers, deviceToken: request.deviceToken)
			logger.info("response: \(response)")
		} catch {
			logger.info("error: \(error)")
		}
	}

	init(id: String, parameters: Parameters) {
		self.id = id
		self.parameters = parameters
	}
}
