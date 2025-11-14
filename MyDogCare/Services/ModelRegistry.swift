import Foundation
import SwiftUI

@MainActor
final class ModelRegistry: ObservableObject {
    struct Descriptor: Identifiable, Equatable {
        enum LoadMode: Equatable {
            case llamaContext
            case mmproj(baseModelFilename: String)
        }

        let id = UUID()
        let filename: String
        let fileExtension: String
        let displayName: String
        let directory: String?
        let loadMode: LoadMode

        var fileNameWithExtension: String {
            "\(filename).\(fileExtension)"
        }
    }

    enum LoadState: Equatable {
        case pending
        case loading
        case loaded
        case failed(String)

        var statusText: String {
            switch self {
            case .pending:
                return "대기 중"
            case .loading:
                return "로드 중…"
            case .loaded:
                return "로드 완료"
            case .failed:
                return "실패"
            }
        }

        var accessorySystemImage: String {
            switch self {
            case .pending:
                return "hourglass"
            case .loading:
                return "arrow.triangle.2.circlepath"
            case .loaded:
                return "checkmark.circle.fill"
            case .failed:
                return "exclamationmark.triangle.fill"
            }
        }
    }

    struct Status: Identifiable, Equatable {
        let descriptor: Descriptor
        var state: LoadState = .pending
        var location: URL?
        var lastError: String?

        var id: UUID { descriptor.id }

        var subtitle: String {
            switch state {
            case .failed(let message):
                return message
            case .loaded:
                return location?.lastPathComponent ?? "메모리에 상주 중"
            case .pending, .loading:
                return descriptor.fileNameWithExtension
            }
        }
    }

    @Published private(set) var statuses: [Status]

    private enum LoadedResource {
        case llama(LlamaContext)
        case projector(MultimodalProjector)
    }

    private var resources: [UUID: LoadedResource] = [:]
    private let descriptors: [Descriptor]
    private let fileManager: FileManager
    private var hasStartedLoading = false

    init(
        models: [Descriptor] = ModelRegistry.defaultDescriptors(),
        fileManager: FileManager = .default
    ) {
        self.descriptors = models
        self.fileManager = fileManager
        self.statuses = models.map { Status(descriptor: $0) }
    }

    func ensureModelsLoaded() {
        guard !hasStartedLoading else { return }
        hasStartedLoading = true

        Task {
            for descriptor in descriptors {
                await loadModel(for: descriptor)
            }
        }
    }

    var isVisionPipelineReady: Bool {
        visionResources() != nil
    }

    func visionResources() -> (context: LlamaContext, projector: MultimodalProjector)? {
        guard
            let textDescriptor = descriptors.first(where: {
                if case .llamaContext = $0.loadMode { return true }
                return false
            }),
            let projectorDescriptor = descriptors.first(where: {
                if case .mmproj = $0.loadMode { return true }
                return false
            }),
            let textResource = resources[textDescriptor.id],
            let projectorResource = resources[projectorDescriptor.id],
            case let .llama(context) = textResource,
            case let .projector(projector) = projectorResource
        else {
            return nil
        }
        return (context, projector)
    }

    private func loadModel(for descriptor: Descriptor) async {
        updateStatus(for: descriptor) { $0.state = .loading }

        guard let url = resolveModelURL(for: descriptor) else {
            updateStatus(for: descriptor) {
                $0.state = .failed("파일을 찾을 수 없어요")
            }
            return
        }

        switch descriptor.loadMode {
        case .llamaContext:
            do {
                let context = try await ModelRegistry.makeContext(at: url)
                resources[descriptor.id] = .llama(context)
                updateStatus(for: descriptor) {
                    $0.location = url
                    $0.state = .loaded
                    $0.lastError = nil
                }
            } catch {
                updateStatus(for: descriptor) {
                    $0.location = url
                    $0.state = .failed(error.localizedDescription)
                    $0.lastError = error.localizedDescription
                }
            }
        case .mmproj(let baseModelFilename):
            guard let baseContext = llamaContext(forFilename: baseModelFilename) else {
                updateStatus(for: descriptor) {
                    $0.location = url
                    $0.state = .failed("텍스트 모델이 먼저 로드되어야 해요")
                    $0.lastError = "텍스트 모델이 먼저 로드되어야 해요"
                }
                return
            }

            do {
                let projector = try await ModelRegistry.makeProjector(at: url, textContext: baseContext)
                resources[descriptor.id] = .projector(projector)
                updateStatus(for: descriptor) {
                    $0.location = url
                    $0.state = .loaded
                    $0.lastError = nil
                }
            } catch {
                updateStatus(for: descriptor) {
                    $0.location = url
                    $0.state = .failed(error.localizedDescription)
                    $0.lastError = error.localizedDescription
                }
            }
        }
    }

    private func llamaContext(forFilename filename: String) -> LlamaContext? {
        guard let descriptor = descriptors.first(where: { $0.filename == filename }) else { return nil }
        guard let resource = resources[descriptor.id] else { return nil }
        if case let .llama(context) = resource {
            return context
        }
        return nil
    }

    private func updateStatus(for descriptor: Descriptor, mutate: (inout Status) -> Void) {
        guard let index = statuses.firstIndex(where: { $0.descriptor.id == descriptor.id }) else { return }
        mutate(&statuses[index])
    }

    private func resolveModelURL(for descriptor: Descriptor) -> URL? {
        if let url = Bundle.main.url(
            forResource: descriptor.filename,
            withExtension: descriptor.fileExtension,
            subdirectory: descriptor.directory
        ) {
            return url
        }

        if let url = Bundle.main.url(
            forResource: descriptor.filename,
            withExtension: descriptor.fileExtension
        ) {
            return url
        }

        if let resourceURL = Bundle.main.resourceURL {
            let directURL = resourceURL.appendingPathComponent(descriptor.fileNameWithExtension)
            if fileManager.fileExists(atPath: directURL.path) {
                return directURL
            }

            if let directory = descriptor.directory {
                let nestedURL = resourceURL
                    .appendingPathComponent(directory, isDirectory: true)
                    .appendingPathComponent(descriptor.fileNameWithExtension)
                if fileManager.fileExists(atPath: nestedURL.path) {
                    return nestedURL
                }
            }
        }

        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docURL = documentsURL
                .appendingPathComponent(descriptor.directory ?? "", isDirectory: true)
                .appendingPathComponent(descriptor.fileNameWithExtension)
            if fileManager.fileExists(atPath: docURL.path) {
                return docURL
            }
        }

        return nil
    }

    private static func makeContext(at url: URL) async throws -> LlamaContext {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let context = try LlamaContext.create_context(path: url.path)
                    continuation.resume(returning: context)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func makeProjector(at url: URL, textContext: LlamaContext) async throws -> MultimodalProjector {
        let pointer = await textContext.modelPointer()
        return try await MultimodalProjector.create(mmprojPath: url.path, textModelPointer: pointer)
    }

    nonisolated static func defaultDescriptors() -> [Descriptor] {
        [
            Descriptor(
                filename: "Qwen3-VL-2B-Instruct-UD-IQ3_XXS",
                fileExtension: "gguf",
                displayName: "Qwen3-VL-2B-Instruct-UD-IQ3_XXS",
                directory: "models",
                loadMode: .llamaContext
            ),
            Descriptor(
                filename: "mmproj-Qwen3VL-2B-Instruct-Q8_0",
                fileExtension: "gguf",
                displayName: "mmproj-Qwen3VL-2B-Instruct-Q8_0",
                directory: "models",
                loadMode: .mmproj(baseModelFilename: "Qwen3-VL-2B-Instruct-UD-IQ3_XXS")
            )
        ]
    }
}

#if DEBUG
extension ModelRegistry {
    static func preview() -> ModelRegistry {
        let registry = ModelRegistry()
        if registry.statuses.count >= 2 {
            registry.statuses[0].state = .loaded
            registry.statuses[0].location = URL(fileURLWithPath: "/tmp/models/\(registry.statuses[0].descriptor.fileNameWithExtension)")
            registry.statuses[1].state = .loading
        }
        return registry
    }
}
#endif
