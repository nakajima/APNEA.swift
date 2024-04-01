//
//  ContentView.swift
//  APNEAExample
//
//  Created by Pat Nakajima on 3/31/24.
//

import APNEAClient
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

struct ContentView: View {
	var client: APNEAClient
	var pushToken: Data?
	var receivedNotifications: [UNNotification] = []

	@State private var isServerAvailable = false
	@State private var hasPermission = false
	@State private var expectingPush: ExpectedPush?

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
					HStack {
						Text("Push Notifications Enabled")
						Spacer()
						Image(systemName: "hand.thumbsup.fill")
							.foregroundStyle(.green)
					}
					HStack {
						if pushToken != nil {
							Text("Push Token Received")
							Spacer()
							Image(systemName: "hand.thumbsup.fill")
								.foregroundStyle(.green)
						} else {
							Text("No Push Token Received")
							Spacer()
							Image(systemName: "xmark.circle.fill")
								.foregroundStyle(.red)
						}
					}
					HStack {
						Text(isServerAvailable ? "Server Available" : "Server Not Found")
						Spacer()
						Image(systemName: isServerAvailable ? "hand.thumbsup.fill" : "xmark.circle.fill")
							.foregroundStyle(isServerAvailable ? .green : .red)
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
						}

						Button("Cancel") {
							withAnimation {
								self.expectingPush = nil
							}
						}
					}
				}
				Section("Send a push") {
					Button("In 5 Seconds") {
						schedulePush(in: 5)
					}
					Button("In 10 Seconds") {
						schedulePush(in: 10)
					}
					Button("In 20 Seconds") {
						schedulePush(in: 20)
					}
				}
				.disabled(expectingPush != nil)

				Section("Received Pushes") {
					if receivedNotifications.isEmpty {
						ContentUnavailableView("Received pushes will appear here.", systemImage: "app.badge")
							.foregroundStyle(.secondary)
					}

					ForEach(receivedNotifications, id: \.request.identifier) { receivedNotification in
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
			} else {
				Text("Push Notifications Not Enabled")
			}
		}
		.onChange(of: receivedNotifications.count) {
			withAnimation {
				expectingPush = nil
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

	@MainActor func refresh() async {
		isServerAvailable = await client.verify()
	}

	func schedulePush(in interval: TimeInterval) {
		let date = Date().addingTimeInterval(interval)

		guard let pushToken else { return }

		do {
			Task {
				try await client.schedule(.init(
					message: .alert(date.formatted()),
					deviceToken: pushToken.map { String(format: "%02x", $0) }.joined(),
					pushType: .alert,
					expiration: .immediately,
					priority: .immediately,
					apnsID: nil,
					topic: Bundle.main.bundleIdentifier!,
					collapseID: nil,
					sendAt: date
				))
			}

			withAnimation {
				expectingPush = ExpectedPush(id: UUID(), date: date)
			}
		} catch {
			print("Error scheduling push: \(error)")
		}
	}
}

#Preview {
	ContentView(client: APNEAClient(url: URL(string: "http://localhost:4567")!))
}
