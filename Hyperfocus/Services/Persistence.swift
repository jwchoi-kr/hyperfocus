import Foundation
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "Persistence")

final class Persistence {
    let fileURL: URL
    private var debounceWork: DispatchWorkItem?
    private let writeQueue = DispatchQueue(label: "com.hyperfocus.persistence", qos: .utility)

    init(fileURL: URL? = nil) {
        if let url = fileURL {
            self.fileURL = url
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            self.fileURL = appSupport
                .appendingPathComponent("Hyperfocus")
                .appendingPathComponent("state.json")
        }
    }

    func load() -> PersistedState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.info("No state file found, returning empty state")
            return PersistedState()
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let state = try Self.decoder.decode(PersistedState.self, from: data)
            logger.info("State loaded from disk")
            return state
        } catch {
            logger.error("Failed to load state: \(error.localizedDescription, privacy: .public)")
            return PersistedState()
        }
    }

    func requestSave(_ state: PersistedState) {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.write(state)
        }
        debounceWork = work
        writeQueue.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow(_ state: PersistedState) {
        debounceWork?.cancel()
        debounceWork = nil
        write(state)
    }

    private func write(_ state: PersistedState) {
        let url = fileURL
        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try Self.encoder.encode(state)
            try data.write(to: url, options: .atomic)
            logger.debug("State saved to disk")
        } catch {
            logger.error("Failed to save state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }()
}
