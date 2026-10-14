import AppKit
import SwiftUI

enum ConnectionPhase: Equatable {
    case notConfigured, disconnected, connecting, connected, needsPairing
}

enum PairingStage: Equatable {
    case idle, starting, awaitingCode, verifying
}

@MainActor final class RemoteStore: ObservableObject {
    static let remotePort: UInt16 = 6466
    static let pairingPort: UInt16 = 6467

    @Published var host: String { didSet { defaults.set(host, forKey: "host") } }
    @Published var name: String { didSet { defaults.set(name, forKey: "name") } }
    @Published var mac: String { didSet { defaults.set(mac, forKey: "mac") } }
    @Published var favorites: [String] { didSet { defaults.set(favorites, forKey: "favorites") } }
    @Published var customApps: [TVApp] { didSet { defaults.set(try? JSONEncoder().encode(customApps), forKey: "customApps") } }

    @Published private(set) var phase: ConnectionPhase = .notConfigured
    @Published private(set) var pairing: PairingStage = .idle
    @Published private(set) var isOn: Bool?
    @Published private(set) var foregroundPackage = ""
    @Published private(set) var volume: VolumeState?
    @Published private(set) var device: TVDeviceInfo?
    @Published private(set) var textFieldFocused = false
    @Published private(set) var discovered: [DiscoveredTV] = []
    @Published private(set) var discovering = false
    @Published var error: String?
    @Published var notice: String?

    private let defaults = UserDefaults.standard
    private var identity: ClientIdentity?
    private var session: RemoteSession?
    private var pairingSession: PairingSession?
    private var wantsConnection = false
    private var reconnectDelay: Double = 2
    private var reconnectTask: Task<Void, Never>?
    private let discovery = TVDiscovery()
    private var volumeTarget: Int?
    private var sessionToken = UUID()

    init() {
        host = defaults.string(forKey: "host") ?? ""
        name = defaults.string(forKey: "name") ?? ""
        mac = defaults.string(forKey: "mac") ?? ""
        favorites = defaults.stringArray(forKey: "favorites") ?? AppCatalog.defaultFavorites
        customApps = (defaults.data(forKey: "customApps")).flatMap { try? JSONDecoder().decode([TVApp].self, from: $0) } ?? []
        phase = host.isEmpty ? .notConfigured : (isPaired ? .disconnected : .needsPairing)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.wantsConnection, self.phase != .connected else { return }
                self.connect()
            }
        }
    }

    // MARK: Derived state

    var displayName: String { name.isEmpty ? "Philips TV" : name }
    var isConnected: Bool { phase == .connected }
    var allApps: [TVApp] { AppCatalog.builtIn + customApps }
    var favoriteApps: [TVApp] { favorites.compactMap { id in allApps.first { $0.id == id } } }
    var foregroundName: String { foregroundPackage.isEmpty ? "—" : AppCatalog.displayName(for: foregroundPackage, custom: customApps) }
    var foregroundIsUnknownApp: Bool {
        !foregroundPackage.isEmpty && !AppCatalog.isSystemPackage(foregroundPackage) && !allApps.contains { $0.id == foregroundPackage }
    }

    private var pairedKey: String { "paired.\(host)" }
    private var pinKey: String { "pin.\(host).\(Self.remotePort)" }
    var isPaired: Bool { !host.isEmpty && defaults.bool(forKey: pairedKey) }

    // MARK: Connection

    func connect() {
        guard !host.isEmpty else { phase = .notConfigured; return }
        guard isPaired else { phase = .needsPairing; return }
        guard phase != .connecting else { return }
        wantsConnection = true
        reconnectTask?.cancel()
        session?.close()
        phase = .connecting
        let host = host
        let token = UUID()
        sessionToken = token
        Task {
            do {
                let identity = try loadIdentity()
                let session = RemoteSession(host: host, port: Self.remotePort, identity: identity, pinnedFingerprint: defaults.string(forKey: pinKey)) { [weak self] event in
                    Task { @MainActor in
                        // Events from a session that was already replaced are stale.
                        guard let self, self.sessionToken == token else { return }
                        self.handle(event)
                    }
                }
                self.session = session
                try await session.start()
                guard self.session === session else { session.close(); return }
                if defaults.string(forKey: pinKey) == nil, let fingerprint = session.serverFingerprint {
                    defaults.set(fingerprint, forKey: pinKey)
                }
                phase = .connected
                reconnectDelay = 2
                error = nil
            } catch {
                guard sessionToken == token else { return }
                connectionFailed(error)
            }
        }
    }

    func disconnect() {
        sessionToken = UUID()
        wantsConnection = false
        reconnectTask?.cancel()
        session?.close()
        session = nil
        phase = host.isEmpty ? .notConfigured : (isPaired ? .disconnected : .needsPairing)
    }

    private func connectionFailed(_ failure: Error) {
        session = nil
        switch failure {
        case LinkError.certificateChanged:
            phase = .needsPairing
            error = failure.localizedDescription
            wantsConnection = false
        case LinkError.tls:
            // The TV drops the TLS handshake of a client it doesn't know: pairing was lost.
            defaults.set(false, forKey: pairedKey)
            phase = .needsPairing
            error = "A TV não reconhece mais este Mac. Pareie novamente em Ajustes."
            wantsConnection = false
        default:
            phase = .disconnected
            if wantsConnection { scheduleReconnect(reason: failure) }
        }
    }

    private func scheduleReconnect(reason: Error?) {
        notice = "TV indisponível. Tentando de novo em \(Int(reconnectDelay)) s…"
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 60)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self, self.wantsConnection else { return }
            self.connect()
        }
    }

    private func handle(_ event: RemoteEvent) {
        switch event {
        case .configured(let info): device = info
        case .power(let on): isOn = on
        case .foregroundApp(let package):
            foregroundPackage = package
            textFieldFocused = false
        case .volume(let state):
            volume = state
            continueVolumeRamp()
        case .textFieldFocused: textFieldFocused = true
        case .closed(let failure):
            guard phase == .connected || phase == .connecting else { return }
            session = nil
            isOn = nil
            if let failure { connectionFailed(failure) } else {
                phase = .disconnected
                if wantsConnection { scheduleReconnect(reason: nil) }
            }
        }
    }

    private func loadIdentity() throws -> ClientIdentity {
        if let identity { return identity }
        let loaded = try ClientIdentity.loadOrCreate()
        identity = loaded
        return loaded
    }

    // MARK: Commands

    func send(_ key: KeyCode) {
        guard let session, isConnected else {
            if !isConnected { notice = "Conectando à TV…"; connect() }
            return
        }
        session.send(key)
    }

    func launch(_ app: TVApp) {
        guard let session, isConnected else { return }
        session.launch(app.id)
        notice = "Abrindo \(app.name)…"
    }

    func sendText(_ text: String) {
        guard let session, isConnected, !text.isEmpty else { return }
        session.sendText(text)
    }

    func powerButton() {
        if isConnected {
            send(.power)
        } else if !mac.isEmpty {
            do {
                try WakeOnLAN.send(mac: mac)
                notice = "Pacote para ligar a TV enviado. Conectando…"
                wantsConnection = true
                reconnectDelay = 4
                scheduleReconnect(reason: nil)
            } catch { self.error = error.localizedDescription }
        } else {
            connect()
        }
    }

    /// The protocol has no absolute volume command, so a target is reached with key presses,
    /// one per volume report from the TV.
    func setVolume(_ target: Int) {
        guard isConnected, volume != nil else { return }
        volumeTarget = target
        continueVolumeRamp()
    }

    private func continueVolumeRamp() {
        guard let target = volumeTarget, let volume else { return }
        if volume.level == target { volumeTarget = nil; return }
        send(volume.level < target ? .volumeUp : .volumeDown)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            // Give up if the TV stopped reporting volume changes.
            if self?.volume?.level == volume.level, self?.volumeTarget == target { self?.volumeTarget = nil }
        }
    }

    // MARK: Pairing

    func startPairing() {
        guard !host.isEmpty else { error = "Informe o IP da TV primeiro."; return }
        disconnect()
        pairingSession?.cancel()
        pairing = .starting
        error = nil
        notice = nil
        let host = host
        Task {
            do {
                let identity = try loadIdentity()
                let pairingSession = PairingSession(host: host, port: Self.pairingPort, identity: identity, clientName: "PhilipsTV Menubar")
                self.pairingSession = pairingSession
                try await pairingSession.start()
                pairing = .awaitingCode
                notice = "Digite o código que apareceu na TV."
            } catch {
                pairing = .idle
                pairingSession = nil
                self.error = error.localizedDescription
            }
        }
    }

    func submitPairingCode(_ code: String) {
        guard let pairingSession, pairing == .awaitingCode else { return }
        pairing = .verifying
        Task {
            do {
                try await pairingSession.finish(code: code)
                self.pairingSession = nil
                pairing = .idle
                defaults.set(true, forKey: pairedKey)
                defaults.removeObject(forKey: pinKey)
                notice = "Pareado. Conectando…"
                phase = .disconnected
                connect()
            } catch PairingError.invalidCode {
                pairing = .awaitingCode
                error = PairingError.invalidCode.localizedDescription
            } catch PairingError.wrongCode {
                // Checked locally before sending, so the TV still waits for another try.
                pairing = .awaitingCode
                error = PairingError.wrongCode.localizedDescription
            } catch {
                pairing = .idle
                self.pairingSession = nil
                self.error = error.localizedDescription + " Comece o pareamento de novo."
            }
        }
    }

    func cancelPairing() {
        pairingSession?.cancel()
        pairingSession = nil
        pairing = .idle
        notice = nil
    }

    func forgetPairing() {
        disconnect()
        defaults.removeObject(forKey: pairedKey)
        defaults.removeObject(forKey: pinKey)
        phase = host.isEmpty ? .notConfigured : .needsPairing
        notice = "Pareamento esquecido."
    }

    func saveSettings(host newHost: String, name newName: String, mac newMAC: String) {
        let trimmedHost = newHost.trimmingCharacters(in: .whitespaces)
        let hostChanged = trimmedHost != host
        if hostChanged { disconnect() }
        host = trimmedHost
        name = newName.trimmingCharacters(in: .whitespaces)
        mac = newMAC.trimmingCharacters(in: .whitespaces)
        error = nil
        if !mac.isEmpty, WakeOnLAN.macBytes(mac) == nil { error = WakeOnLAN.WakeError.invalidMAC.localizedDescription }
        if host.isEmpty { phase = .notConfigured } else if isPaired { connect() } else { phase = .needsPairing }
    }

    // MARK: Discovery

    func discover() {
        discovered = []
        discovering = true
        discovery.run(found: { [weak self] tv in
            guard let self, !self.discovered.contains(tv) else { return }
            self.discovered.append(tv)
        }, done: { [weak self] in
            self?.discovering = false
        })
    }

    // MARK: Apps

    func toggleFavorite(_ app: TVApp) {
        if let index = favorites.firstIndex(of: app.id) { favorites.remove(at: index) } else { favorites.append(app.id) }
    }

    func addCustomApp(name: String, package: String) {
        let package = package.trimmingCharacters(in: .whitespaces)
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !package.isEmpty, !allApps.contains(where: { $0.id == package }) else { return }
        customApps.append(TVApp(id: package, name: name.isEmpty ? package : name, color: 0x6E7681, symbol: "app.fill"))
    }

    /// Adds the app currently on screen (reported by package name) to the catalog and favorites.
    func saveForegroundApp() {
        guard foregroundIsUnknownApp else { return }
        let package = foregroundPackage
        addCustomApp(name: package.split(separator: ".").last.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? package, package: package)
        if !favorites.contains(package) { favorites.append(package) }
        notice = "App salvo nos favoritos."
    }

    func removeCustomApp(_ app: TVApp) {
        customApps.removeAll { $0.id == app.id }
        favorites.removeAll { $0 == app.id }
    }

    // MARK: Keyboard

    /// Mac keyboard shortcuts while the panel is open. Returns true when the key was used.
    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard isConnected, event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        let key: KeyCode?
        switch event.keyCode {
        case 126: key = .dpadUp
        case 125: key = .dpadDown
        case 123: key = .dpadLeft
        case 124: key = .dpadRight
        case 36, 76: key = .dpadCenter
        case 51: key = .back
        case 49: key = .playPause
        default:
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "h": key = .home
            case "m": key = .mute
            case "+", "=": key = .volumeUp
            case "-": key = .volumeDown
            default: key = nil
            }
        }
        guard let key else { return false }
        send(key)
        return true
    }
}
