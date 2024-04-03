//
//  APNS.swift
//
//
//  Created by Pat Nakajima on 4/2/24.
//

import APNS
import Foundation

	let APNS = APNSClient(
		configuration: .init(
			authenticationMethod: .jwt(
				privateKey: App.privateKey,
				keyIdentifier: App.env("KEY_IDENTIFIER"),
				teamIdentifier: App.env("TEAM_IDENTIFIER")
			),
			environment: App.env("KEY_IDENTIFIER").lowercased() == "production" ? .production : .sandbox
		),
		eventLoopGroupProvider: .createNew,
		responseDecoder: JSONDecoder(),
		requestEncoder: JSONEncoder()
	)
