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

public struct PushNotificationSchedule: Sendable, Codable {
	public var occurrences: Int
	public var interval: TimeInterval
	public var sendAt: Date

	public static let immediate = PushNotificationSchedule(occurrences: 1, interval: 0, sendAt: .distantPast)
	public static func once(on date: Date) -> PushNotificationSchedule {
		PushNotificationSchedule(occurrences: 1, interval: 0, sendAt: date)
	}

	public init(occurrences: Int, interval: TimeInterval, sendAt: Date) {
		self.occurrences = occurrences
		self.interval = interval
		self.sendAt = sendAt
	}
}

public struct PushNotificationRequest: Codable, Sendable {
	public struct Payload: Encodable, Sendable {
		public init() {}
	}

	public var id: UUID
	public var deviceToken: String
	public var pushType: APNSPushType
	public var expiration: APNSNotificationExpiration?
	public var priority: APNSPriority?
	public var apnsID: UUID?
	public var topic: String
	public var collapseID: String?
	public var message: Message
	public var schedule: PushNotificationSchedule

	enum CodingKeys: String, CodingKey {
		case id, deviceToken, pushType, expiration, priority, apnsID, topic, collapseID, message, schedule
	}

	public init(from decoder: any Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		self.id = try values.decode(UUID.self, forKey: .id)
		self.deviceToken = try values.decode(String.self, forKey: .deviceToken)

		let pushTypeString = try values.decode(String.self, forKey: .pushType)
		let pushTypeConfiguration = APNSPushType.Configuration(rawValue: pushTypeString)!
		self.pushType = switch pushTypeConfiguration {
		case .alert: .alert
		case .background: .background
		case .location: .location
		case .voip: .voip
		case .complication: .complication
		case .fileprovider: .fileprovider
		case .mdm: .mdm
		case .liveactivity: .liveactivity
		}

		if let expirationInt = try values.decodeIfPresent(Int.self, forKey: .expiration) {
			self.expiration = APNSNotificationExpiration.timeIntervalSince1970InSeconds(expirationInt)
		} else {
			self.expiration = APNSNotificationExpiration.none
		}

		if let priorityInt = try values.decodeIfPresent(Int.self, forKey: .priority) {
			self.priority = priorityInt == 5 ? .consideringDevicePower : .immediately
		}

		self.apnsID = try values.decodeIfPresent(UUID.self, forKey: .apnsID)
		self.topic = try values.decode(String.self, forKey: .topic)
		self.collapseID = try values.decodeIfPresent(String.self, forKey: .collapseID)
		self.message = try values.decode(Message.self, forKey: .message)
		self.schedule = try values.decode(PushNotificationSchedule.self, forKey: .schedule)
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(id, forKey: .id)
		try container.encode(message, forKey: .message)
		try container.encode(deviceToken, forKey: .deviceToken)
		try container.encode(pushType.configuration.rawValue, forKey: .pushType)
		try container.encode(expiration?.expiration, forKey: .expiration)
		try container.encode(priority?.rawValue, forKey: .priority)
		try container.encode(apnsID, forKey: .apnsID)
		try container.encode(topic, forKey: .topic)
		try container.encode(collapseID, forKey: .collapseID)
		try container.encode(schedule, forKey: .schedule)
	}

	public init(
		id: UUID,
		message: Message,
		deviceToken: String,
		pushType: APNSPushType,
		expiration: APNSNotificationExpiration?,
		priority: APNSPriority?,
		apnsID: UUID?,
		topic: String,
		collapseID: String?,
		schedule: PushNotificationSchedule
	) {
		self.id = id
		self.deviceToken = deviceToken
		self.pushType = pushType
		self.expiration = expiration
		self.priority = priority
		self.apnsID = apnsID
		self.topic = topic
		self.collapseID = collapseID
		self.message = message
		self.schedule = schedule
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
