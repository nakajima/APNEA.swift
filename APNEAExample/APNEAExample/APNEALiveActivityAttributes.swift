//
//  APNEALiveActivityAttributes.swift
//  APNEAExample
//
//  Created by Pat Nakajima on 4/3/24.
//

import ActivityKit
import Foundation

struct APNEALiveActivityAttributes: ActivityAttributes, Codable {
	public struct ContentState: Codable, Hashable {
		// Dynamic stateful properties about your activity go here!
		var emoji: String
	}

	// Fixed non-changing properties about your activity go here!
	var name: String = "Hi"
}
