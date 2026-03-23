import Foundation

final class SharedRecorderCommandStore {
    private enum Keys {
        static let command = "shared.recorder.command"
    }

    private let defaults: UserDefaults?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> SharedRecorderCommand? {
        guard
            let defaults
        else {
            return nil
        }

        defaults.synchronize()

        guard
            let data = defaults.data(forKey: Keys.command),
            let command = try? decoder.decode(SharedRecorderCommand.self, from: data)
        else {
            return nil
        }

        print("[SharedCommandStore] Loaded command id=\(command.id) action=\(command.action.rawValue)")
        return command
    }

    func save(_ command: SharedRecorderCommand) {
        guard let defaults else {
            print("[SharedCommandStore] Save failed: defaults is nil")
            return
        }

        guard let data = try? encoder.encode(command) else {
            print("[SharedCommandStore] Save failed: encode error")
            return
        }

        defaults.set(data, forKey: Keys.command)
        defaults.synchronize()
        print("[SharedCommandStore] Saved command id=\(command.id) action=\(command.action.rawValue)")
    }

    func clear() {
        defaults?.removeObject(forKey: Keys.command)
        defaults?.synchronize()
        print("[SharedCommandStore] Cleared command")
    }
}
