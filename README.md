# APNEA.swift

A server that lets your clients send themselves push notifications.

## Run the server

The server uses the following env variables:

#### `REDIS_URL`

A redis url. If you don't set this, the server will crash on start.

```
REDIS_URL="redis://localhost:6379" # Example
```

### `KEY_IDENTIFIER`

The identifier for the key for your push notifications. You can get this from https://developer.apple.com/help/account/manage-keys/get-a-key-identifier.

```
KEY_IDENTIFIER="ABC1234D56" # Example
```

### `TEAM_IDENTIFIER`

The team identifier you registered for the key for.

```
TEAM_IDENTIFIER="A123BC45D6" # Example
```

### `PRIVATE_KEY`

The contents of the .p8 key you got for APNS.

```
PRIVATE_KEY="$(cat ./AuthKey_ABC1234D56.p8)" # Example
```

### `TOPIC`

The [`apns-topic`](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns#Send-a-POST-request-to-APNs) to send to APNS. This is almost always your bundle identifier.

Pushes sent to the server without this topic will be ignored.

```
TOPIC="com.example.apnea" # Example
```

### `PORT`

The port to run the server on. Defaults to 4567.

```
PORT=8080 # Example
```

## Use the client 

Get an `APNEAClient` by passing it the URL of your APNEA server.

```swift
let client = APNEAClient(url: URL(string: "http://localhost:4567")!)
```

Send yourself a push notification:

```swift
try await client.schedule(.init(
  // Every push needs an ID.
  id: UUID(),

  // This is the message content. It's still sort of in flux.

  message: .alert("hello world"),

  // The device token you get from application(_:didRegisterForRemoteNotificationsWithDeviceToken:)
  deviceToken: pushToken.map { String(format: "%02x", $0) }.joined(),

  // APNS Header fields (https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns#Send-a-POST-request-to-APNs)
  pushType: .alert,
  expiration: .immediately,
  priority: .immediately,
  apnsID: nil,
  topic: Bundle.main.bundleIdentifier!,
  collapseID: nil,

  // Send the push in 5 seconds
  schedule: .once(on: Date().advanced(by: 5))
))
```
