import Foundation
import Network
import Security

enum LinkError: LocalizedError {
    case timeout
    case closed
    case refused
    case certificateChanged
    case tls(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .timeout: return "A TV não respondeu a tempo."
        case .closed: return "A TV encerrou a conexão."
        case .refused: return "A TV recusou a conexão. Ela está ligada e na mesma rede?"
        case .certificateChanged: return "O certificado da TV mudou desde o último uso. Se for a mesma TV, pareie de novo em Ajustes."
        case .tls(let detail): return "Falha na conexão segura com a TV (\(detail))."
        case .failed(let detail): return "Falha de rede: \(detail)"
        }
    }
}

/// Holds what the TLS verify block learns about the TV. Separate object so the block can be
/// built before `TVLink` finishes initialising.
private final class PeerState: @unchecked Sendable {
    var leaf: SecCertificate?
    var pinMismatch = false
}

/// TLS connection to the TV carrying varint-length-prefixed protobuf messages.
/// All state is confined to `queue`.
final class TVLink: @unchecked Sendable {
    let messages: AsyncThrowingStream<Data, Error>
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let peer: PeerState
    private var buffer: [UInt8] = []
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var finished = false

    /// - Parameter pinnedFingerprint: SHA-256 of the TV certificate seen before. nil accepts any
    ///   certificate (first contact); the caller then pins `serverCertificate`.
    init(host: String, port: UInt16, identity: SecIdentity, pinnedFingerprint: String?) {
        var streamContinuation: AsyncThrowingStream<Data, Error>.Continuation!
        messages = AsyncThrowingStream { streamContinuation = $0 }
        continuation = streamContinuation
        let queue = DispatchQueue(label: "PhilipsTVMenubar.link")
        let peer = PeerState()
        self.queue = queue
        self.peer = peer

        let tls = NWProtocolTLS.Options()
        let security = tls.securityProtocolOptions
        if let localIdentity = sec_identity_create(identity) {
            sec_protocol_options_set_local_identity(security, localIdentity)
        }
        // The TV uses a self-signed certificate, so trust is established by pinning instead of a CA.
        sec_protocol_options_set_verify_block(security, { _, trust, complete in
            let trustRef = sec_trust_copy_ref(trust).takeRetainedValue()
            guard let chain = SecTrustCopyCertificateChain(trustRef) as? [SecCertificate], let leaf = chain.first else {
                complete(false)
                return
            }
            peer.leaf = leaf
            if let pinnedFingerprint, Fingerprint.sha256(leaf) != pinnedFingerprint {
                peer.pinMismatch = true
                complete(false)
                return
            }
            complete(true)
        }, queue)

        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = 6
        tcp.noDelay = true
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? 6466,
            using: NWParameters(tls: tls, tcp: tcp)
        )
    }

    var serverCertificate: SecCertificate? { queue.sync { peer.leaf } }

    func start(timeout: TimeInterval = 8) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                self.startContinuation = continuation
                self.connection.stateUpdateHandler = { [weak self] state in self?.handle(state) }
                self.connection.start(queue: self.queue)
                self.queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
                    guard let self, self.startContinuation != nil else { return }
                    self.finish(LinkError.timeout)
                }
            }
        }
    }

    func send(_ payload: Data) {
        var framed = Data()
        ProtoWriter.appendVarint(UInt64(payload.count), to: &framed)
        framed.append(payload)
        connection.send(content: framed, completion: .contentProcessed { [weak self] error in
            if let error { self?.finish(self?.map(error) ?? LinkError.closed) }
        })
    }

    func close() { queue.async { self.finish(nil) } }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            startContinuation?.resume()
            startContinuation = nil
            receive()
        case .waiting(let error), .failed(let error):
            // `.waiting` means Network.framework would retry forever; report it instead.
            finish(map(error))
        case .cancelled:
            finish(nil)
        default:
            break
        }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(contentsOf: data)
                self.drain()
            }
            if let error {
                self.finish(self.map(error))
            } else if isComplete {
                self.finish(LinkError.closed)
            } else if !self.finished {
                self.receive()
            }
        }
    }

    private func drain() {
        while !buffer.isEmpty {
            var index = 0
            let length: UInt64?
            do { length = try ProtoMessage.readVarint(buffer, at: &index) } catch {
                finish(LinkError.failed("mensagem inválida"))
                return
            }
            guard let length, UInt64(buffer.count - index) >= length else { return }
            let end = index + Int(length)
            continuation.yield(Data(buffer[index..<end]))
            buffer.removeFirst(end)
        }
    }

    private func finish(_ error: Error?) {
        guard !finished else { return }
        finished = true
        if let startContinuation {
            startContinuation.resume(throwing: error ?? LinkError.closed)
            self.startContinuation = nil
        }
        continuation.finish(throwing: error)
        connection.stateUpdateHandler = nil
        connection.cancel()
    }

    private func map(_ error: NWError) -> Error {
        if peer.pinMismatch { return LinkError.certificateChanged }
        switch error {
        case .tls(let status): return LinkError.tls("OSStatus \(status)")
        case .posix(let code) where code == .ECONNREFUSED: return LinkError.refused
        case .posix(let code) where code == .ETIMEDOUT: return LinkError.timeout
        default: return LinkError.failed(error.localizedDescription)
        }
    }
}
