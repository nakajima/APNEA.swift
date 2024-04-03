//
//  ContentView.swift
//  APNEAExample
//
//  Created by Pat Nakajima on 3/31/24.
//

import APNEAClient
import APNEACore
import SwiftUI
import UserNotifications
import UserNotificationsUI

struct ExpectedPush {
	var id: UUID
	var date: Date
}

struct ReceivedPush: Identifiable {
	var id: UUID
	var receivedAt: Date
}

struct ScheduledPushStatusView: View {
	enum LoadStatus: Equatable {
		case loading, done(ScheduledPushStatus), error(String)
	}

	var client: APNEAClient
	var uuid: UUID

	@State private var status: LoadStatus = .loading

	var body: some View {
		if case let .done(status) = status {
			VStack(alignment: .leading) {
				Text(status.id.uuidString)
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

	@State private var isServerAvailable = false
	@State private var hasPermission = false
	@State private var expectingPush: ExpectedPush?
	@State private var repeats: Double = 1
	@State private var interval: Double = 5.0
	@State private var knownIDs: [UUID] = []

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
						Text("No Push Token Received")
						Spacer()
						Image(systemName: "xmark.circle.fill")
							.foregroundStyle(.red)
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

				Section("Received Pushes") {
					if receivedNotifications.isEmpty {
						Text("No pushes received yet.")
							.foregroundStyle(.secondary)
					}

					ForEach(Array(receivedNotifications.enumerated()), id: \.0) { (_, receivedNotification) in
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

		let id = UUID()

		Task {
			do {
				try await client.schedule(.init(
					id: id,
					message: .alert(date.formatted()),
					deviceToken: pushToken.map { String(format: "%02x", $0) }.joined(),
					pushType: .alert,
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
						expectingPush = ExpectedPush(id: UUID(), date: date)
						knownIDs.append(id)
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
