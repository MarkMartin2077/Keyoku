//
//  LanguageModelRouter.swift
//  Keyoku
//

import Foundation
import FoundationModels

/// Routes generation to Private Cloud Compute when it's usable and falls back to the on-device model.
///
/// A fallback happens only for Private Cloud Compute failures (quota, network, service) and only when
/// the on-device model is available. Once a run has fallen back it stays on-device until `beginRun()`.
@MainActor
final class LanguageModelRouter {

    private let cloud = PrivateCloudComputeLanguageModel()
    private let onDevice = SystemLanguageModel.default
    private var prewarmed: PrewarmedSession?

    private(set) var activeModel: GenerationModelKind = .onDevice

    init() {
        activeModel = preferredModel
    }

    var canUseCloud: Bool {
        cloud.isAvailable && !cloud.quotaUsage.isLimitReached
    }

    var availability: GenerationAvailability {
        if canUseCloud {
            return .available(.privateCloud)
        }
        switch onDevice.availability {
        case .available:
            return .available(.onDevice)
        case .unavailable(.deviceNotEligible):
            return .unavailable(.deviceNotEligible)
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable(.appleIntelligenceNotEnabled)
        case .unavailable(.modelNotReady):
            return .unavailable(.modelNotReady)
        @unknown default:
            return .unavailable(.unknown)
        }
    }

    private var preferredModel: GenerationModelKind {
        canUseCloud ? .privateCloud : .onDevice
    }

    @discardableResult
    func beginRun() -> GenerationModelKind {
        activeModel = preferredModel
        return activeModel
    }

    func contextSize() async -> Int {
        if activeModel == .privateCloud, let size = try? await cloud.contextSize {
            return size
        }
        return onDevice.contextSize
    }

    /// Private Cloud Compute has no tokenizer, so the on-device count is the estimate for both models.
    func tokenCount(_ text: String) async -> Int {
        (try? await onDevice.tokenCount(for: text)) ?? text.count / 3
    }

    func tokenCount(for schema: GenerationSchema) async -> Int {
        (try? await onDevice.tokenCount(for: schema)) ?? schema.debugDescription.count / 3
    }

    func prewarm(instructions: String) {
        let model = preferredModel
        let session = makeSession(for: model, instructions: instructions)
        session.prewarm()
        prewarmed = PrewarmedSession(model: model, instructions: instructions, session: session)
    }

    func stream<T: Generable>(
        prompt: String,
        instructions: String,
        generating type: T.Type
    ) -> AsyncThrowingStream<T.PartiallyGenerated, Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: T.PartiallyGenerated.self)

        let task = Task {
            do {
                if activeModel == .privateCloud {
                    if try await streamFromCloud(prompt: prompt, instructions: instructions, type: type, into: continuation) {
                        continuation.finish()
                        return
                    }
                }
                let session = takeSession(for: .onDevice, instructions: instructions)
                for try await snapshot in session.streamResponse(to: prompt, generating: type) {
                    continuation.yield(snapshot.content)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    /// One request on the on-device model, whatever the run's active model. For small follow-up calls
    /// that shouldn't spend Private Cloud Compute quota.
    func respondOnDevice<T: Generable>(to prompt: String, instructions: String, generating type: T.Type) async throws -> T {
        guard onDevice.isAvailable else { throw GenerationFailure.modelUnavailable }
        let session = makeSession(for: .onDevice, instructions: instructions)
        return try await session.respond(to: prompt, generating: type).content
    }

    /// Returns true when the cloud finished the response, false when the caller should retry on-device.
    private func streamFromCloud<T: Generable>(
        prompt: String,
        instructions: String,
        type: T.Type,
        into continuation: AsyncThrowingStream<T.PartiallyGenerated, Error>.Continuation
    ) async throws -> Bool {
        guard canUseCloud else {
            guard onDevice.isAvailable else { throw GenerationFailure.cloudUnavailable }
            activeModel = .onDevice
            return false
        }

        var didYield = false
        do {
            let session = takeSession(for: .privateCloud, instructions: instructions)
            for try await snapshot in session.streamResponse(to: prompt, generating: type) {
                didYield = true
                continuation.yield(snapshot.content)
            }
            return true
        } catch let error as PrivateCloudComputeLanguageModel.Error {
            guard onDevice.isAvailable else { throw error }
            activeModel = .onDevice
            // Snapshots already reached the consumer, so a silent retry would mix two responses.
            // The next call runs on-device; the caller decides whether to retry this one.
            if didYield { throw error }
            return false
        }
    }

    private func takeSession(for model: GenerationModelKind, instructions: String) -> LanguageModelSession {
        if let prewarmed, prewarmed.model == model, prewarmed.instructions == instructions {
            self.prewarmed = nil
            return prewarmed.session
        }
        return makeSession(for: model, instructions: instructions)
    }

    private func makeSession(for model: GenerationModelKind, instructions: String) -> LanguageModelSession {
        switch model {
        case .privateCloud: return LanguageModelSession(model: cloud, instructions: instructions)
        case .onDevice: return LanguageModelSession(model: onDevice, instructions: instructions)
        }
    }
}

private struct PrewarmedSession {
    let model: GenerationModelKind
    let instructions: String
    let session: LanguageModelSession
}
