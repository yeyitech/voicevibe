import Foundation

final class SharedRecorderStore {
    private enum Keys {
        static let snapshot = "shared.recorder.snapshot"
    }

    private let defaults: UserDefaults?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> SharedRecorderSnapshot {
        guard
            let defaults
        else {
            print("[SharedRecorderStore] Load empty snapshot")
            return .empty
        }

        defaults.synchronize()

        guard
            let data = defaults.data(forKey: Keys.snapshot),
            let snapshot = try? decoder.decode(SharedRecorderSnapshot.self, from: data)
        else {
            print("[SharedRecorderStore] Load empty snapshot")
            return .empty
        }

        print("[SharedRecorderStore] Loaded snapshot status=\(snapshot.status.rawValue)")
        return snapshot
    }

    func save(_ snapshot: SharedRecorderSnapshot) {
        guard let defaults else {
            print("[SharedRecorderStore] Save failed: defaults is nil")
            return
        }

        guard let data = try? encoder.encode(snapshot) else {
            print("[SharedRecorderStore] Save failed: encode error")
            return
        }

        defaults.set(data, forKey: Keys.snapshot)
        defaults.synchronize()
        print("[SharedRecorderStore] Saved snapshot status=\(snapshot.status.rawValue)")
    }
}
