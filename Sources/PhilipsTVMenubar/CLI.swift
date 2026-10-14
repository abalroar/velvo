import Foundation
import Security

/// Command-line diagnostics. Run the binary inside the app bundle, e.g.
/// `PhilipsTVMenubar.app/Contents/MacOS/PhilipsTVMenubar --status --host 192.168.0.50`.
enum CLI {
    private static let commands = ["--pair", "--status", "--send-key", "--launch", "--text", "--export-client-cert", "--help"]

    static func handles(_ arguments: [String]) -> Bool { arguments.contains { commands.contains($0) } }

    static func run(_ arguments: [String]) -> Never {
        setvbuf(stdout, nil, _IOLBF, 0)
        Task {
            do {
                try await execute(Options(arguments))
                exit(0)
            } catch {
                print("ERROR: \(error.localizedDescription)")
                exit(1)
            }
        }
        dispatchMain()
    }

    private struct Options {
        let arguments: [String]
        init(_ arguments: [String]) { self.arguments = arguments }
        func has(_ flag: String) -> Bool { arguments.contains(flag) }
        func value(_ flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        func port(_ flag: String, default value: UInt16) -> UInt16 { self.value(flag).flatMap(UInt16.init) ?? value }
    }

    private struct UsageError: LocalizedError {
        let errorDescription: String?
    }

    private static func execute(_ options: Options) async throws {
        if options.has("--help") {
            print("""
            PhilipsTVMenubar — command-line diagnostics
              --self-check                         offline tests
              --export-client-cert PATH            write the Mac's client certificate (PEM)
              --pair --host IP [--code C | --code-file F] [--pair-port 6467]
              --status --host IP [--port 6466]     print what the TV reports
              --send-key KEY[,KEY…] --host IP      e.g. HOME, DPAD_UP, VOLUME_UP, TV_INPUT_HDMI_1
              --launch PACKAGE_OR_LINK --host IP   e.g. com.netflix.ninja
              --text TEXT --host IP                type into the focused text field
            """)
            return
        }
        let identity = try ClientIdentity.loadOrCreate()
        if let path = options.value("--export-client-cert") {
            let der = SecCertificateCopyData(identity.certificate) as Data
            try CertificateBuilder.pem(der).write(toFile: path, atomically: true, encoding: .utf8)
            print("CERTIFICATE \(path)")
            return
        }
        guard let host = options.value("--host") else { throw UsageError(errorDescription: "--host IP is required") }

        if options.has("--pair") {
            let session = PairingSession(host: host, port: options.port("--pair-port", default: 6467), identity: identity, clientName: "PhilipsTV Menubar")
            try await session.start()
            print("PAIRING code requested; check the TV screen")
            let code = try await readCode(options)
            try await session.finish(code: code)
            UserDefaults.standard.set(true, forKey: "paired.\(host)")
            print("PAIRED")
            return
        }

        let events = EventLog()
        let session = RemoteSession(host: host, port: options.port("--port", default: 6466), identity: identity, pinnedFingerprint: nil) { event in
            events.record(event)
        }
        try await session.start()
        print("CONNECTED")
        // The TV sends configure, power, app and volume within a moment of connecting.
        for _ in 0..<30 where !events.ready {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        if let keys = options.value("--send-key") {
            for name in keys.split(separator: ",") {
                guard let key = KeyCode(name: String(name)) else { throw UsageError(errorDescription: "unknown key \(name)") }
                session.send(key)
                print("SENT \(key.name)")
                try await Task.sleep(nanoseconds: 300_000_000)
            }
        }
        if let app = options.value("--launch") {
            session.launch(app)
            print("LAUNCHED \(app)")
        }
        if let text = options.value("--text") {
            session.sendText(text)
            print("TYPED \(text.count) characters")
        }
        try await Task.sleep(nanoseconds: 1_500_000_000)
        session.close()
    }

    private static func readCode(_ options: Options) async throws -> String {
        if let code = options.value("--code") { return code }
        if let path = options.value("--code-file") {
            for _ in 0..<300 {
                if let code = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), code.count == 6 {
                    return code
                }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            throw UsageError(errorDescription: "no code in \(path)")
        }
        print("Code shown on the TV: ", terminator: "")
        return readLine() ?? ""
    }
}

/// Prints remote events as they arrive.
private final class EventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var gotPower = false

    var ready: Bool { lock.locked { gotPower } }

    func record(_ event: RemoteEvent) {
        switch event {
        case .configured(let info): print("DEVICE vendor=\(info.vendor) model=\(info.model) version=\(info.version) features=\(info.features)")
        case .power(let on):
            lock.locked { gotPower = true }
            print("POWER \(on ? "on" : "standby")")
        case .foregroundApp(let package): print("APP \(package)")
        case .volume(let volume): print("VOLUME \(volume.level)/\(volume.max)\(volume.muted ? " muted" : "")")
        case .textFieldFocused: print("TEXT_FIELD focused")
        case .closed(let error): print("CLOSED \(error?.localizedDescription ?? "")")
        }
    }
}
