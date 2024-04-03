//
//  PushSchedulerSnapshot.swift
//
//
//  Created by Pat Nakajima on 4/2/24.
//

import Foundation

struct PushSchedulerSnapshot: Codable {
	var schedules: [UUID: ScheduledPush]
	var errored: [ScheduledPush]
	var completedIDs: Set<UUID>

	var description: String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .prettyPrinted
		if let data = try? encoder.encode(self) {
			return "Snapshot loaded:\n\(String(data: data, encoding: .utf8)!)"
		} else {
			return "Snapshot not loaded"
		}
	}
}
