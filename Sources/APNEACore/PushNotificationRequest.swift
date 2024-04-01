//
//  PushNotificationRequest.swift
//
//
//  Created by Pat Nakajima on 3/31/24.
//

import APNSCore
import Foundation

public enum Message: Codable, Sendable {
	case background, alert(String)
}

public struct PushNotificationRequest: Codable, Sendable {
	public struct Payload: Encodable, Sendable {
		public init() { }
	}

	public var deviceToken: String
	public var pushType: APNSPushType
	public var expiration: APNSNotificationExpiration?
	public var priority: APNSPriority?
	public var apnsID: UUID?
	public var topic: String
	public var collapseID: String?
	public var message: Message
	public var sendAt: Date?

	enum CodingKeys: String, CodingKey {
		case deviceToken, pushType, expiration, priority, apnsID, topic, collapseID, message, sendAt
	}

	public init(from decoder: any Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		self.deviceToken = try values.decode(String.self, forKey: .deviceToken)

		let pushTypeString = try values.decode(String.self, forKey: .pushType)
		let pushTypeConfiguration = APNSPushType.Configuration(rawValue: pushTypeString)!
		self.pushType = switch pushTypeConfiguration {
		case .alert: .alert
		case .background:	.background
		case .location: .location
		case .voip: .voip
		case .complication:	.complication
		case .fileprovider:	.fileprovider
		case .mdm: .mdm
		case .liveactivity: .liveactivity
		}

		if let expirationInt = try values.decodeIfPresent(Int.self, forKey: .expiration) {
			expiration = APNSNotificationExpiration.timeIntervalSince1970InSeconds(expirationInt)
		} else {
			expiration = APNSNotificationExpiration.none
		}

		if let priorityInt = try values.decodeIfPresent(Int.self, forKey: .priority) {
			priority = priorityInt == 5 ? .consideringDevicePower : .immediately
		}

		apnsID = try values.decodeIfPresent(UUID.self, forKey: .apnsID)
		topic = try values.decode(String.self, forKey: .topic)
		collapseID = try values.decodeIfPresent(String.self, forKey: .collapseID)
		message = try values.decode(Message.self, forKey: .message)
		sendAt = try values.decode(Date.self, forKey: .sendAt)
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(message, forKey: .message)
		try container.encode(deviceToken, forKey: .deviceToken)
		try container.encode(pushType.configuration.rawValue, forKey: .pushType)
		try container.encode(expiration?.expiration, forKey: .expiration)
		try container.encode(priority?.rawValue, forKey: .priority)
		try container.encode(apnsID, forKey: .apnsID)
		try container.encode(topic, forKey: .topic)
		try container.encode(collapseID, forKey: .collapseID)
		try container.encode(sendAt, forKey: .sendAt)
	}

	public init(
		message: Message,
		deviceToken: String,
		pushType: APNSPushType,
		expiration: APNSNotificationExpiration?,
		priority: APNSPriority?,
		apnsID: UUID?,
		topic: String,
		collapseID: String?,
		sendAt: Date? = nil
	) {
		self.deviceToken = deviceToken
		self.pushType = pushType
		self.expiration = expiration
		self.priority = priority
		self.apnsID = apnsID
		self.topic = topic
		self.collapseID = collapseID
		self.message = message
		self.sendAt = sendAt
	}

	public func toAPNS() -> APNSMessage {
		switch message {
		case .background:
			return APNSBackgroundNotification(
				expiration: expiration ?? .immediately,
				topic: topic,
				payload: Payload(),
				apnsID: nil // TODO:
			)
		case let .alert(string):
			return APNSAlertNotification(
				alert: .init(
					title: .raw(string)
				),
				expiration: expiration ?? .immediately,
				priority: priority ?? .immediately,
				topic: topic,
				payload: Payload()
			)
		}
	}
}
