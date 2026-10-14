import Foundation
import Network

struct DiscoveredTV: Identifiable, Hashable {
    var id: String { host }
    let name: String
    let host: String
}

/// Finds Android TVs through the Bonjour service the Remote Service advertises.
@MainActor final class TVDiscovery {
    private var browser: NWBrowser?
    private var resolvers: [NWConnection] = []

    func run(seconds: Double = 6, found: @escaping @MainActor (DiscoveredTV) -> Void, done: @escaping @MainActor () -> Void) {
        stop()
        let browser = NWBrowser(for: .bonjour(type: "_androidtvremote2._tcp", domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                for result in results { self?.resolve(result.endpoint, found: found) }
            }
        }
        browser.start(queue: .main)
        self.browser = browser
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.stop()
            done()
        }
    }

    func stop() {
        browser?.cancel()
        browser = nil
        resolvers.forEach { $0.cancel() }
        resolvers.removeAll()
    }

    /// Bonjour gives a service name; a short TCP connection reveals its IPv4 address.
    private func resolve(_ endpoint: NWEndpoint, found: @escaping @MainActor (DiscoveredTV) -> Void) {
        guard case .service(let name, _, _, _) = endpoint else { return }
        let parameters = NWParameters.tcp
        if let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options { ip.version = .v4 }
        let connection = NWConnection(to: endpoint, using: parameters)
        connection.stateUpdateHandler = { [weak connection] state in
            guard case .ready = state, let connection else { return }
            if case .hostPort(let host, _)? = connection.currentPath?.remoteEndpoint, case .ipv4(let address) = host {
                let ip = "\(address)".components(separatedBy: "%").first ?? "\(address)"
                Task { @MainActor in found(DiscoveredTV(name: name, host: ip)) }
            }
            connection.cancel()
        }
        connection.start(queue: .main)
        resolvers.append(connection)
    }
}

enum WakeOnLAN {
    enum WakeError: LocalizedError {
        case invalidMAC, socket
        var errorDescription: String? {
            switch self {
            case .invalidMAC: return "Endereço MAC inválido. Use o formato AA:BB:CC:DD:EE:FF."
            case .socket: return "Não foi possível enviar o pacote Wake-on-LAN."
            }
        }
    }

    static func macBytes(_ mac: String) -> [UInt8]? {
        let hex = mac.filter(\.isHexDigit)
        guard hex.count == 12 else { return nil }
        return PairingSecret.hexBytes(hex.uppercased())
    }

    /// Sends the magic packet (6 × 0xFF + 16 × MAC) to the local broadcast address, ports 9 and 7.
    static func send(mac: String) throws {
        guard let bytes = macBytes(mac) else { throw WakeError.invalidMAC }
        let packet = [UInt8](repeating: 0xff, count: 6) + Array([[UInt8]](repeating: bytes, count: 16).joined())
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw WakeError.socket }
        defer { Darwin.close(fd) }
        var enable: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &enable, socklen_t(MemoryLayout<Int32>.size))
        var sent = false
        for port: UInt16 in [9, 7] {
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = port.bigEndian
            address.sin_addr.s_addr = UInt32(0xffff_ffff)
            let result = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, packet, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if result == packet.count { sent = true }
        }
        if !sent { throw WakeError.socket }
    }
}
