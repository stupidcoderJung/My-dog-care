# My Dog Care (SwiftUI + Clerk)

My Dog Care is a SwiftUI starter application that showcases how to build a small dog-care companion with Clerk authentication. It includes a loading screen, an authenticated main dashboard, and a configurable settings screen.

## Project layout

```
MyDogCare/
├── MyDogCareApp.swift            // Entry point for the SwiftUI app
├── Services/
│   └── ClerkAuthService.swift    // Authentication flow wrapper around Clerk
├── Views/
│   ├── AuthenticationView.swift  // Welcome + sign-in button
│   ├── ClerkHostedAuthView.swift // Bridge to Clerk's hosted UI
│   ├── ErrorStateView.swift      // Friendly retry UI
│   ├── LoadingView.swift         // Progress indicator while loading
│   ├── MainTabView.swift         // Tab container for Home & Settings
│   ├── MainView.swift            // Primary dashboard experience
│   └── SettingsView.swift        // Preferences & sign-out
└── Resources/
    └── ClerkConfig.plist         // Store your Clerk publishable key
```

The project is distributed as a Swift Package for portability. You can open it from Xcode 15+ and embed it inside an iOS app target, or you can use the sources directly when scaffolding a new iOS application.

## Getting started

1. **Install dependencies**
   - In Xcode, add `https://github.com/clerkinc/clerk-ios` as a Swift Package dependency (included in `Package.swift`).
   - Replace the placeholder value in `MyDogCare/Resources/ClerkConfig.plist` with your Clerk publishable key.

2. **Embed the module in an app**
   - Create a new SwiftUI app in Xcode, then drag the `MyDogCare` folder into the project.
   - Alternatively, use this package as the core target and create a simple wrapper app target that depends on it.

3. **Configure URL schemes**
   - Follow the [Clerk iOS guide](https://clerk.com/docs) to configure redirect URLs, callback URLs, and push notification handling if needed.

4. **Run the app**
   - Build and run on iOS 15 or later. The app starts on a loading screen, transitions to Clerk sign-in when no session is available, and finally displays the dashboard with access to settings once the user signs in.

## Notes

- Network access for Swift Package resolution is required the first time you fetch the Clerk SDK. In sandboxed environments you may need to pre-download dependencies.
- The sample UI is intentionally simple but well-structured so you can extend it with dog profiles, reminders, and analytics.
- `ClerkAuthService` wraps the Clerk SDK to handle configuration, session refresh, and sign-out logic. Adjust the integration points to match any updates in the Clerk SDK.

## Testing

This template includes a placeholder unit test target. Add your own tests for view models, services, or reducers as the project grows.
