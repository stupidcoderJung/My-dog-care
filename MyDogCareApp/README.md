# MyDogCareApp

A SwiftUI-based iOS application template for a dog care service. The template includes:

- A loading screen that checks Clerk authentication state.
- An authenticated main page that shows the currently signed-in user and dog care information.
- A settings page with sign-out support.

## Getting started

1. Open the project in Xcode 15 or newer.
2. Add your Clerk publishable key to the `ClerkConfiguration.plist` file (create it in the project if necessary) or update `ClerkAuthService` to load it from your preferred source.
3. Update the bundle identifier and signing information to match your Apple Developer account.
4. Run the application on an iOS 16+ simulator or device.

## Clerk setup

Follow the [Clerk iOS quickstart](https://clerk.com/docs/quickstarts/ios) to configure your instance and obtain API keys. Provide the frontend API and publishable key through the configuration file or environment.

## Project structure

```
MyDogCareApp/
├── Package.swift
├── README.md
├── Sources/
│   └── MyDogCareApp/
│       ├── App/
│       │   ├── AppState.swift
│       │   └── MyDogCareApp.swift
│       ├── Features/
│       │   ├── Loading/LoadingView.swift
│       │   ├── Main/MainView.swift
│       │   └── Settings/SettingsView.swift
│       ├── Root/ContentView.swift
│       └── Services/Auth/ClerkAuthService.swift
└── Tests/
    └── MyDogCareAppTests/
        └── PlaceholderTests.swift
```

The `ClerkAuthService` class centralizes Clerk SDK interactions. Views use `@EnvironmentObject` to access `AppState`, which monitors authentication and toggles between screens.

## License

This project is provided as-is for demonstration purposes.
