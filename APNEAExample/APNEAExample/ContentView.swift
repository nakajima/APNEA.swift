//
//  ContentView.swift
//  APNEAExample
//
//  Created by Pat Nakajima on 3/31/24.
//

import ActivityKit
import APNEAClient
import APNEACore
import APNSCore
import SwiftUI
import UserNotifications
import UserNotificationsUI

struct ExpectedPush {
	var id: String
	var date: Date
}

struct ReceivedPush: Identifiable {
	var id: String
	var receivedAt: Date
}

struct ScheduledPushStatusView: View {
	enum LoadStatus: Equatable {
		case loading, done(ScheduledPushStatus), error(String)
	}

	var client: APNEAClient
	var uuid: String

	@State private var status: LoadStatus = .loading

	var body: some View {
		if case let .done(status) = status {
			VStack(alignment: .leading) {
				Text(status.id)
					.foregroundStyle(.secondary)
					.bold()
					.font(.caption)
				if case let .scheduled(status) = status {
					HStack {
						Text("Interval")
						Spacer()
						Text(status.interval.formatted())
							.foregroundStyle(.secondary)
					}
					HStack {
						Text("Remaining")
						Spacer()
						Text(status.remainingOccurrences.formatted())
							.foregroundStyle(.secondary)
					}
					HStack {
						Text("Next Push")
						Spacer()
						Text(status.nextPush.formatted())
							.foregroundStyle(.secondary)
					}
				} else {
					Text("Completed")
				}
			}
			.font(.subheadline)
			.padding(.vertical)
			.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
		} else if case let .error(string) = status {
			VStack(alignment: .leading) {
				Text("Error")
				Text(string)
			}
		} else {
			ProgressView("Loading…")
				.task {
					while status == .loading {
						let status = await refresh()

						await MainActor.run {
							self.status = status
						}

						try? await Task.sleep(for: .seconds(2))
					}
				}
		}
	}

	@discardableResult func refresh() async -> LoadStatus {
		do {
			if let status = try await client.status(id: uuid) {
				return .done(status)
			} else {
				print("no status")
			}
		} catch {
			return .error(error.localizedDescription)
		}

		return .loading
	}
}

struct ContentView: View {
	var client: APNEAClient
	var pushToken: Data?
	var receivedNotifications: [UNNotification] = []

	enum LiveActivityStatus {
		case unknown, requested(Date), active(Activity<APNEALiveActivityAttributes>?, String), error(String)

		var disableButton: Bool {
			return switch self {
			case let .active(activity, _):
				activity != nil
			default:
				true
			}
		}

		var errorMessage: String? {
			if case let .error(string) = self {
				return string
			} else {
				return nil
			}
		}
	}

	@State private var isServerAvailable = false
	@State private var hasPermission = false
	@State private var expectingPush: ExpectedPush?
	@State private var repeats: Double = 1
	@State private var interval: Double = 5.0
	@State private var knownIDs: [String] = []
	@State private var liveActivityStatus: LiveActivityStatus = .unknown

	@State private var statusIsExpanded = true

	var body: some View {
		List {
			HStack {
				Text("APNEA Client Example")
					.bold()
					.foregroundStyle(.secondary)
				Spacer()
			}
			.listRowBackground(Color.clear)
			if hasPermission {
				Section {
					if pushToken == nil {
						HStack {
							Text("No Push Token Received")
							Spacer()
							Image(systemName: "xmark.circle.fill")
								.foregroundStyle(.red)
						}
					}
					if !isServerAvailable {
						HStack {
							Text("Server Not Available")
							Spacer()
							Image(systemName: "xmark.circle.fill")
								.foregroundStyle(.red)
						}
					}
				}

				Section {
					VStack(alignment: .leading) {
						Text("Interval")
							.font(.subheadline)
						Slider(value: $interval.animation(), in: 0 ... 20, step: 5) {
							Text("Count")
						} minimumValueLabel: {
							Text("\(Int(interval))")
						} maximumValueLabel: {
							Text("20")
						}
						.foregroundStyle(.secondary)
						.font(.caption)
					}
					.disabled(expectingPush != nil)

					VStack(alignment: .leading) {
						Text("Repeats")
							.font(.subheadline)
						Slider(value: $repeats.animation(), in: 1 ... 5, step: 1) {
							Text("Count")
						} minimumValueLabel: {
							Text("\(Int(repeats))")
						} maximumValueLabel: {
							Text("5")
						}
						.foregroundStyle(.secondary)
						.font(.caption)
					}
				}

				Button("Send a push \(repeats == 1 ? "in" : "every") \(Int(interval)) seconds") {
					schedulePush()
				}

				Section {
					Button("Send a live activity push in \(Int(interval)) seconds") {
						scheduleLiveActivityPush()
					}
					.disabled(liveActivityStatus.disableButton)
					.task {
						for await activity in Activity<APNEALiveActivityAttributes>.activityUpdates {
							self.liveActivityStatus = .active(activity, currentActivityToken)
						}
					}
					.task {
						if case .active = liveActivityStatus {
							return
						}

						do {
							try await requestLiveActivityToken()
						} catch {
							self.liveActivityStatus = .error(error.localizedDescription)
						}
					}

					if let activity = currentActivity, activity.activityState == .active {
						HStack {
							Text("Live activity currently \(activity.activityState)")
							Spacer()

							Button("End") {
								Task.detached(priority: .userInitiated) {
									for activity in Activity<APNEALiveActivityAttributes>.activities {
										await activity.end(nil, dismissalPolicy: .immediate)
									}
								}

								withAnimation {
									self.liveActivityStatus = .active(nil, currentActivityToken)
								}
							}
						}
					} else if case let .requested(date) = liveActivityStatus {
						TimelineView(.periodic(from: Date(), by: 1)) { _ in
							Text("Expecting live activity in \(date.formatted(.relative(presentation: .named)))")
						}
					}

					if let errorMessage = liveActivityStatus.errorMessage {
						Text(errorMessage)
							.font(.caption)
					}
				}

				Section("Received Pushes") {
					if receivedNotifications.isEmpty {
						Text("No pushes received yet.")
							.foregroundStyle(.secondary)
					}

					ForEach(Array(receivedNotifications.enumerated()), id: \.0) { _, receivedNotification in
						DisclosureGroup {
							Text(receivedNotification.debugDescription)
								.font(.caption)
								.fontDesign(.monospaced)
								.foregroundStyle(.secondary)
								.listRowInsets(.init(top: 4, leading: 4, bottom: 4, trailing: 4))
						} label: {
							Text(receivedNotification.date.formatted())
						}
					}
				}

				if let expectingPush {
					Section {
						TimelineView(.periodic(from: Date(), by: 1)) { _ in
							HStack {
								Text("Push Expected")
								Spacer()
								Text(expectingPush.date.formatted(.relative(presentation: .named)))
									.foregroundStyle(.secondary)
							}
							.task {
								await refreshExpectedPush()
							}
						}
					}
				}

				if !knownIDs.isEmpty {
					Section {
						DisclosureGroup(isExpanded: $statusIsExpanded) {
							ForEach(knownIDs, id: \.self) { uuid in
								ScheduledPushStatusView(client: client, uuid: uuid)
							}
						} label: {
							Text("Pending Pushes")
						}
					}
					.id(receivedNotifications.count)
				}
			} else {
				HStack {
					Text("Push Notifications Not Enabled")
					Spacer()
					Image(systemName: "xmark.circle.fill")
						.foregroundStyle(.green)
				}
			}
		}
		.listSectionSpacing(.compact)
		.onChange(of: receivedNotifications.count) {
			Task {
				await refreshExpectedPush()
			}
		}
		.refreshable {
			await refresh()
		}
		.task {
			hasPermission = try! await UNUserNotificationCenter.current().requestAuthorization(options: [.provisional, .badge])

			UIApplication.shared.registerForRemoteNotifications()
		}
		.task {
			await refresh()
		}
		.fontDesign(.rounded)
	}

	func refreshExpectedPush() async {
		do {
			let statuses = try await client.statuses(ids: knownIDs)

			for knownID in knownIDs {
				if statuses[knownID] == nil {
					await MainActor.run {
						withAnimation {
							knownIDs.removeAll(where: { $0 == knownID })
						}
					}
				}
			}

			let nextStatus = statuses.values.filter { $0.nextPushAt != nil }.sorted(by: {
				$0.nextPushAt! < $1.nextPushAt!
			}).first

			await MainActor.run {
				withAnimation {
					guard let nextStatus, let date = nextStatus.nextPushAt else {
						self.expectingPush = nil
						return
					}

					self.expectingPush = .init(id: nextStatus.id, date: date)
				}
			}
		} catch {
			print("Error loading statuses \(error)")
		}
	}

	@MainActor func refresh() async {
		isServerAvailable = await client.verify()
	}

	func schedulePush() {
		let date = Date().addingTimeInterval(interval)

		guard let pushToken else { return }

		let id = UUID().uuidString

		Task {
			do {
				try await client.schedule(.init(
					id: id,
					deviceToken: pushToken.map { String(format: "%02x", $0) }.joined(),
					pushType: .alert,
					message: APNSAlertNotification(
						alert: .init(
							title: .raw(Date().formatted()),
							body: .raw(Date().formatted())
						),
						expiration: .immediately,
						priority: .immediately,
						topic: Bundle.main.bundleIdentifier!
					),
					expiration: .immediately,
					priority: .immediately,
					apnsID: nil,
					topic: Bundle.main.bundleIdentifier!,
					collapseID: nil,
					schedule: repeats == 0 ?
						.once(on: date) :
						.init(
							occurrences: Int(repeats),
							interval: interval,
							sendAt: date
						)
				))

				await MainActor.run {
					withAnimation {
						expectingPush = ExpectedPush(id: UUID().uuidString, date: date)
						knownIDs.append(id)
					}
				}
			} catch {
				print("Error scheduling push: \(error)")
			}
		}
	}

	func requestLiveActivityToken() async throws {
		let activity = try Activity.request(
			attributes: APNEALiveActivityAttributes(name: "hi"),
			content: ActivityContent(
				state: APNEALiveActivityAttributes.ContentState(emoji: "⚙️"),
				staleDate: nil,
				relevanceScore: 100
			),
			pushType: .token
		)

		for await update in Activity<APNEALiveActivityAttributes>.pushToStartTokenUpdates {
			liveActivityStatus = .active(nil, update.map { String(format: "%02x", $0) }.joined())

			if activity.activityState != .ended {
				await activity.end(nil)
			}
		}
	}

	var currentActivity: Activity<APNEALiveActivityAttributes>? {
		if case let .active(activity, _) = liveActivityStatus {
			return activity
		} else {
			return nil
		}
	}

	var currentActivityToken: String {
		if case let .active(_, token) = liveActivityStatus {
			token
		} else {
			"NO TOKEN"
		}
	}

	func scheduleLiveActivityPush() {
		let id = UUID().uuidString
		let date = Date().addingTimeInterval(interval)

		guard case let .active(_, token) = liveActivityStatus else {
			return
		}

		Task {
			let liveActivityMessage = APNSStartLiveActivityNotification<APNEALiveActivityAttributes, APNEALiveActivityAttributes.ContentState>(
				expiration: .immediately,
				priority: .immediately,
				appID: Bundle.main.bundleIdentifier!,
				contentState: .init(emoji: "🏎️"),
				timestamp: Int(Date().timeIntervalSince1970),
				dismissalDate: .immediately,
				attributes: .init(name: "Sup"),
				attributesType: "APNEALiveActivityAttributes",
				alert: .init(
					title: .raw("Hi"),
					body: .raw("Hi")
				)
			)

			do {
				try await client.schedule(.init(
					id: id,
					deviceToken: token,
					pushType: .liveactivity,
					message: liveActivityMessage,
					expiration: .immediately,
					priority: .immediately,
					apnsID: nil,
					topic: Bundle.main.bundleIdentifier!,
					collapseID: nil,
					schedule: .once(on: date)
				))

				await MainActor.run {
					withAnimation {
						liveActivityStatus = .requested(date)
					}
				}
			} catch {
				print("Error scheduling push: \(error)")
			}
		}
	}
}

#Preview {
	ContentView(client: APNEAClient(url: URL(string: "http://localhost:4567")!))
}
