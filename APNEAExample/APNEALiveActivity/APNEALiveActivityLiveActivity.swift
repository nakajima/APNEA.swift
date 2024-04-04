//
//  APNEALiveActivityLiveActivity.swift
//  APNEALiveActivity
//
//  Created by Pat Nakajima on 4/4/24.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct APNEALiveActivityLiveActivity: Widget {
	var body: some WidgetConfiguration {
		ActivityConfiguration(for: APNEALiveActivityAttributes.self) { context in
			// Lock screen/banner UI goes here
			VStack {
				Text("Hello \(context.state.emoji)")
			}
			.activityBackgroundTint(Color.cyan)
			.activitySystemActionForegroundColor(Color.black)

		} dynamicIsland: { context in
			DynamicIsland {
				// Expanded UI goes here.  Compose the expanded UI through
				// various regions, like leading/trailing/center/bottom
				DynamicIslandExpandedRegion(.leading) {
					Text("Leading")
				}
				DynamicIslandExpandedRegion(.trailing) {
					Text("Trailing")
				}
				DynamicIslandExpandedRegion(.bottom) {
					Text("Bottom \(context.state.emoji)")
					// more content
				}
			} compactLeading: {
				Text("L")
			} compactTrailing: {
				Text("T \(context.state.emoji)")
			} minimal: {
				Text(context.state.emoji)
			}
			.widgetURL(URL(string: "http://www.apple.com"))
			.keylineTint(Color.red)
		}
	}
}

private extension APNEALiveActivityAttributes {
	static var preview: APNEALiveActivityAttributes {
		APNEALiveActivityAttributes(name: "World")
	}
}

private extension APNEALiveActivityAttributes.ContentState {
	static var smiley: APNEALiveActivityAttributes.ContentState {
		APNEALiveActivityAttributes.ContentState(emoji: "😀")
	}

	static var starEyes: APNEALiveActivityAttributes.ContentState {
		APNEALiveActivityAttributes.ContentState(emoji: "🤩")
	}
}

#Preview("Notification", as: .content, using: APNEALiveActivityAttributes.preview) {
	APNEALiveActivityLiveActivity()
} contentStates: {
	APNEALiveActivityAttributes.ContentState.smiley
	APNEALiveActivityAttributes.ContentState.starEyes
}
