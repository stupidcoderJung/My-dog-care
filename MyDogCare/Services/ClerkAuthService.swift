import Foundation
import SwiftUI
#if canImport(ClerkSDK)
import ClerkSDK
#endif

@MainActor
final class ClerkAuthService: ObservableObject {
    @Published private(set) var sessionState: SessionState = .loading

    enum SessionState: Equatable {
        case loading
        case needsSignIn
        case signedIn(SessionDetails)
        case error(String)
    }

    struct SessionDetails: Equatable {
        let userId: String
        let firstName: String?
        let lastName: String?
        let emailAddress: String?

        var displayName: String {
            let name = [firstName, lastName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            if !name.isEmpty { return name }
            if let emailAddress, !emailAddress.isEmpty { return emailAddress }
            return "Dog lover"
        }

        static let mock = SessionDetails(
            userId: "user_mock",
            firstName: "Jamie",
            lastName: "Park",
            emailAddress: "jamie@mydogcare.app"
        )
    }

    static let preview: ClerkAuthService = {
        let service = ClerkAuthService()
        service.sessionState = .signedIn(.mock)
        return service
    }()

    private var isConfigured = false

    func configure(force: Bool = false) async {
        if isConfigured && !force {
            await refreshSession()
            return
        }

        do {
            #if canImport(ClerkSDK)
            let configuration = try ClerkConfigLoader.load()
            try await Clerk.shared.setPublishableKey(configuration.publishableKey)
            isConfigured = true
            await refreshSession()
            #else
            throw ClerkConfigurationError.sdkUnavailable
            #endif
        } catch {
            sessionState = .error(error.localizedDescription)
        }
    }

    func refreshSession() async {
        #if canImport(ClerkSDK)
        guard isConfigured else {
            sessionState = .loading
            return
        }

        do {
            if let session = try await Clerk.shared.sessionList(refresh: true).first {
                sessionState = .signedIn(SessionDetails(session: session))
            } else {
                sessionState = .needsSignIn
            }
        } catch {
            sessionState = .error(error.localizedDescription)
        }
        #else
        sessionState = .error(ClerkConfigurationError.sdkUnavailable.localizedDescription)
        #endif
    }

    func signOut() async {
        #if canImport(ClerkSDK)
        do {
            try await Clerk.shared.signOut()
            sessionState = .needsSignIn
        } catch {
            sessionState = .error(error.localizedDescription)
        }
        #else
        sessionState = .error(ClerkConfigurationError.sdkUnavailable.localizedDescription)
        #endif
    }
}

#if canImport(ClerkSDK)
private extension ClerkAuthService.SessionDetails {
    init(session: Clerk.Session) {
        self.init(
            userId: session.user.id,
            firstName: session.user.firstName,
            lastName: session.user.lastName,
            emailAddress: session.user.primaryEmailAddress?.emailAddress
        )
    }
}
#endif

enum ClerkConfigurationError: LocalizedError {
    case missingConfiguration
    case sdkUnavailable

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Missing Clerk configuration."
        case .sdkUnavailable:
            return "Clerk SDK is unavailable in the current build."
        }
    }
}

struct ClerkConfiguration: Decodable {
    let publishableKey: String
}

enum ClerkConfigLoader {
    static func load() throws -> ClerkConfiguration {
        guard let url = Bundle.main.url(forResource: "ClerkConfig", withExtension: "plist") else {
            throw ClerkConfigurationError.missingConfiguration
        }

        let data = try Data(contentsOf: url)
        return try PropertyListDecoder().decode(ClerkConfiguration.self, from: data)
    }
}
