import Foundation

struct VolumeState: Equatable {
    var level: Int
    var max: Int
    var muted: Bool
}

struct TVDeviceInfo: Equatable {
    var vendor: String
    var model: String
    var version: String
    var features: Int
}

enum RemoteEvent {
    case configured(TVDeviceInfo)
    case power(Bool)
    case foregroundApp(String)
    case volume(VolumeState)
    case textFieldFocused
    case closed(Error?)
}

/// Remote protocol on port 6466: the TV drives a short handshake (configure, set active),
/// then pings every few seconds and pushes power, app and volume updates.
final class RemoteSession: @unchecked Sendable {
    private enum Field {
        static let configure = 1, setActive = 2, error = 3
        static let pingRequest = 8, pingResponse = 9, keyInject = 10
        static let imeKeyInject = 20, imeBatchEdit = 21, imeShowRequest = 22
        static let start = 40, setVolume = 50, appLink = 90
    }

    /// PING | KEY | IME | POWER | VOLUME | APP_LINK, as androidtvremote2 requests.
    static let requestedFeatures = 1 | 2 | 4 | 32 | 64 | 512
    private static let idleTimeout: UInt64 = 20_000_000_000

    private let link: TVLink
    private let onEvent: @Sendable (RemoteEvent) -> Void
    private let lock = NSLock()
    private var features = RemoteSession.requestedFeatures
    private var imeCounter = 0
    private var fieldCounter = 0
    private var lastActivity = Date()
    private var readerTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?

    init(host: String, port: UInt16, identity: ClientIdentity, pinnedFingerprint: String?, onEvent: @escaping @Sendable (RemoteEvent) -> Void) {
        link = TVLink(host: host, port: port, identity: identity.identity, pinnedFingerprint: pinnedFingerprint)
        self.onEvent = onEvent
    }

    var serverFingerprint: String? { link.serverCertificate.map(Fingerprint.sha256) }

    func start() async throws {
        try await link.start()
        touch()
        readerTask = Task { [weak self, link] in
            do {
                for try await raw in link.messages { self?.handle(raw) }
                self?.closed(nil)
            } catch {
                self?.closed(error)
            }
        }
        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self else { return }
                if Date().timeIntervalSince(self.lockedLastActivity) > Double(Self.idleTimeout) / 1e9 {
                    self.link.close()
                    return
                }
            }
        }
    }

    func close() {
        watchdogTask?.cancel()
        link.close()
    }

    func send(_ key: KeyCode) { link.send(Self.keyMessage(key)) }

    /// Launches an app by deep link, or by package name through `market://launch`.
    func launch(_ appLinkOrPackage: String) { link.send(Self.appLinkMessage(appLinkOrPackage)) }

    /// Replaces the focused text field's content. Works only while a text field is focused on the TV.
    func sendText(_ text: String) {
        guard !text.isEmpty else { return }
        let (ime, field) = lock.locked { (imeCounter, fieldCounter) }
        link.send(Self.textMessage(text, imeCounter: ime, fieldCounter: field))
    }

    // MARK: Messages

    static func keyMessage(_ key: KeyCode) -> Data {
        ProtoWriter.build { $0.message(Field.keyInject) { inject in
            inject.int(1, key.rawValue)
            inject.int(2, 3) // SHORT press
        } }
    }

    static func appLinkMessage(_ appLinkOrPackage: String) -> Data {
        let link = appLinkOrPackage.contains("://") ? appLinkOrPackage : "market://launch?id=\(appLinkOrPackage)"
        return ProtoWriter.build { $0.message(Field.appLink) { $0.string(1, link) } }
    }

    static func textMessage(_ text: String, imeCounter: Int, fieldCounter: Int) -> Data {
        let cursor = text.count - 1
        return ProtoWriter.build { $0.message(Field.imeBatchEdit) { edit in
            edit.int(1, imeCounter)
            edit.int(2, fieldCounter)
            edit.message(3) { info in
                info.int(1, 1)
                info.message(2) { object in
                    object.int(1, cursor)
                    object.int(2, cursor)
                    object.string(3, text)
                }
            }
        } }
    }

    static func configureReply(features: Int) -> Data {
        ProtoWriter.build { $0.message(Field.configure) { reply in
            reply.int(1, features)
            reply.message(2) { device in
                device.int(3, 1)
                device.string(4, "1")
                device.string(5, "atvremote")
                device.string(6, "1.0.0")
            }
        } }
    }

    static func setActiveReply(features: Int) -> Data {
        ProtoWriter.build { $0.message(Field.setActive) { $0.int(1, features) } }
    }

    static func pingReply(_ value: Int) -> Data {
        ProtoWriter.build { $0.message(Field.pingResponse) { $0.int(1, value) } }
    }

    private var lockedLastActivity: Date { lock.locked { lastActivity } }
    private func touch() { lock.locked { lastActivity = Date() } }

    private func handle(_ raw: Data) {
        touch()
        guard let message = try? ProtoMessage(raw) else { return }
        if let configure = message.message(Field.configure) {
            let supported = configure.int(1)
            let active = lock.locked { () -> Int in
                features &= supported
                return features
            }
            let info = configure.message(2)
            onEvent(.configured(TVDeviceInfo(vendor: info?.string(2) ?? "", model: info?.string(1) ?? "", version: info?.string(6) ?? "", features: supported)))
            link.send(Self.configureReply(features: active))
        } else if message.has(Field.setActive) {
            let active = lock.locked { features }
            link.send(Self.setActiveReply(features: active))
        } else if let ping = message.message(Field.pingRequest) {
            link.send(Self.pingReply(ping.int(1)))
        } else if let ime = message.message(Field.imeKeyInject) {
            let package = ime.message(1)?.string(12) ?? ""
            if !package.isEmpty { onEvent(.foregroundApp(package)) }
        } else if let edit = message.message(Field.imeBatchEdit) {
            lock.locked {
                imeCounter = edit.int(1)
                fieldCounter = edit.int(2)
            }
            onEvent(.textFieldFocused)
        } else if message.has(Field.imeShowRequest) {
            onEvent(.textFieldFocused)
        } else if let volume = message.message(Field.setVolume) {
            onEvent(.volume(VolumeState(level: volume.int(7), max: max(1, volume.int(6)), muted: volume.bool(8))))
        } else if message.has(Field.start) {
            onEvent(.power(message.message(Field.start)?.bool(1) ?? false))
        }
    }

    private func closed(_ error: Error?) {
        watchdogTask?.cancel()
        onEvent(.closed(error))
    }
}

extension NSLock {
    func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
