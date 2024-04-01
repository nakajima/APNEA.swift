//
//  APNEAExampleApp.swift
//  APNEAExample
//
//  Created by Pat Nakajima on 3/31/24.
//

import APNEAClient
import SwiftUI

class AppDelegate: UIResponder, UIApplicationDelegate {
	var pushToken: Binding<Data?>?
	var receivedNotifications: Binding<[UNNotification]>?

	func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		UNUserNotificationCenter.current().delegate = self

		return true
	}
}

extension AppDelegate: UNUserNotificationCenterDelegate {
	func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		if pushToken != nil {
			pushToken!.wrappedValue = deviceToken
			pushToken!.update()
		}
	}

	func userNotificationCenter(
		_: UNUserNotificationCenter,
		willPresent notification: UNNotification,
		withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
	) {
		// Update the app interface directly.
		if receivedNotifications != nil {
			receivedNotifications!.wrappedValue.append(notification)
			receivedNotifications!.update()
		}

		// Show a banner
		completionHandler(.banner)
	}
}

@main
struct APNEAExampleApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

	let client = APNEAClient(url: URL(string: "http://localhost:4567")!)

	@State private var pushToken: Data?
	@State var receivedNotifications: [UNNotification] = []

	var body: some Scene {
		WindowGroup {
			ContentView(client: client, pushToken: pushToken, receivedNotifications: receivedNotifications)
				.onAppear {
					appDelegate.receivedNotifications = $receivedNotifications
					appDelegate.pushToken = $pushToken
				}
		}
	}
}
