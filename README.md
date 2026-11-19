# PocketPet

PocketPet is a SwiftUI virtual pet for Apple Watch with a companion iPhone app. It is currently an MVP.

- Adopt and care for a pet on Apple Watch.
- Earn pet XP from daily steps with optional HealthKit access.
- Check on your pet from the iPhone app, an iPhone widget, or an Apple Watch complication.
- Sync pet state between the watch and iPhone using WatchConnectivity.

## Run locally

Open `PocketPet.xcodeproj` in Xcode 26.2 or later. Select `PocketPet` for iPhone or `PocketPet Watch App` for Apple Watch, then run on a simulator with iOS 26.2 or watchOS 26.2 or later.

To run on physical devices, configure signing and bundle identifiers for your Apple Developer team. Update the App Group in the app and extension entitlements and in the shared code so the apps and their widgets use the matching group. Keep HealthKit enabled for the watch app to read steps.
