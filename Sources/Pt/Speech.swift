import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Lines are generated ahead of time so one is ready the moment the walker slips.
@MainActor
final class Speech {
    nonisolated static let longest = 16

    private var lines: [String] = []
    private var preparing = false
    private let generate: @Sendable () async -> [String]

    init(generate: @escaping @Sendable () async -> [String] = Speech.generate) {
        self.generate = generate
    }

    func take() -> String? {
        defer { prepare() }
        return lines.popLast()
    }

    func prepare() {
        guard lines.isEmpty, !preparing else { return }
        preparing = true
        Task {
            lines = Speech.tidy(await generate())
            preparing = false
        }
    }

    nonisolated static func tidy(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        return lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= longest && seen.insert($0).inserted }
    }

    // Stays silent wherever the on-device model is missing or switched off.
    nonisolated static func generate() async -> [String] {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) { return await FallLines.generate() }
        #endif
        return []
    }
}

#if canImport(FoundationModels)
@available(macOS 26, *)
@Generable
struct FallLines {
    @Guide(description: "Different short exclamations of a few words each", .count(6))
    var lines: [String]

    static func generate() async -> [String] {
        guard case .available = SystemLanguageModel.default.availability else { return [] }
        let code = Locale(identifier: Locale.preferredLanguages.first ?? "en").language.languageCode
        let language = Locale(identifier: "en")
            .localizedString(forLanguageCode: code?.identifier ?? "en") ?? "English"
        let session = LanguageModelSession(instructions: """
            You are a tiny mascot that walks along the tops of windows on a desktop. \
            You only ever speak \(language), in a few words, without quotes or emoji.
            """)
        // The cap stops a runaway list from filling the context window.
        let response = try? await session.respond(
            to: """
                You keep slipping off the edges of windows. List what you blurt out as you \
                start to fall, each one different and written in \(language).
                """,
            generating: FallLines.self,
            options: GenerationOptions(temperature: 1.5, maximumResponseTokens: 200))
        return response?.content.lines ?? []
    }
}
#endif
