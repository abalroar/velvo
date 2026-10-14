import Foundation
import Security
import CryptoKit

enum PairingError: LocalizedError {
    case invalidCode
    case wrongCode
    case rejected(Int)
    case unexpected
    case noServerCertificate

    var errorDescription: String? {
        switch self {
        case .invalidCode: return "O código tem 6 caracteres (0–9 e A–F), como aparece na TV."
        case .wrongCode: return "Código incorreto. Confira o que está na tela da TV."
        case .rejected(let status): return status == 402 ? "A TV recusou o código." : "A TV recusou o pareamento (status \(status))."
        case .unexpected: return "Resposta inesperada da TV durante o pareamento."
        case .noServerCertificate: return "A TV não apresentou certificado."
        }
    }
}

/// Secret proving both sides saw the same code: SHA-256 over both RSA keys plus the last
/// 4 hex digits of the code. The first 2 hex digits must equal the first hash byte.
enum PairingSecret {
    static func compute(client: (modulus: [UInt8], exponent: [UInt8]),
                        server: (modulus: [UInt8], exponent: [UInt8]),
                        code: String) throws -> Data {
        let normalized = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard normalized.count == 6, let codeBytes = hexBytes(normalized) else { throw PairingError.invalidCode }
        var hash = SHA256()
        hash.update(data: client.modulus)
        hash.update(data: client.exponent)
        hash.update(data: server.modulus)
        hash.update(data: server.exponent)
        hash.update(data: codeBytes[1...])
        let digest = Data(hash.finalize())
        guard digest.first == codeBytes[0] else { throw PairingError.wrongCode }
        return digest
    }

    static func hexBytes(_ string: String) -> [UInt8]? {
        let chars = Array(string)
        guard chars.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        for i in stride(from: 0, to: chars.count, by: 2) {
            guard let byte = UInt8(String(chars[i...i + 1]), radix: 16) else { return nil }
            bytes.append(byte)
        }
        return bytes
    }
}

/// Polo pairing on port 6467. `start()` makes the TV show a code; `finish(code:)` sends the secret.
final class PairingSession {
    private enum Field {
        static let protocolVersion = 1, status = 2
        static let pairingRequest = 10, pairingRequestAck = 11, options = 20
        static let configuration = 30, configurationAck = 31, secret = 40, secretAck = 41
    }
    private static let statusOK = 200
    private static let encodingHex = 3, roleInput = 1, codeLength = 6

    private let link: TVLink
    private let identity: ClientIdentity
    private let clientName: String
    private var iterator: AsyncThrowingStream<Data, Error>.AsyncIterator

    init(host: String, port: UInt16, identity: ClientIdentity, clientName: String) {
        link = TVLink(host: host, port: port, identity: identity.identity, pinnedFingerprint: nil)
        iterator = link.messages.makeAsyncIterator()
        self.identity = identity
        self.clientName = clientName
    }

    /// Fingerprint of the certificate the TV presented on the pairing port.
    var serverFingerprint: String? { link.serverCertificate.map(Fingerprint.sha256) }

    func start() async throws {
        try await link.start()
        link.send(Self.pairingRequestMessage(clientName: clientName))
        _ = try await expect(Field.pairingRequestAck)
        link.send(Self.optionsMessage())
        _ = try await expect(Field.options)
        link.send(Self.configurationMessage())
        _ = try await expect(Field.configurationAck)
    }

    func finish(code: String) async throws {
        guard let serverCertificate = link.serverCertificate,
              let key = SecCertificateCopyKey(serverCertificate),
              let der = SecKeyCopyExternalRepresentation(key, nil) as Data? else { throw PairingError.noServerCertificate }
        let secret = try PairingSecret.compute(client: identity.publicKey, server: try DER.rsaPublicKey(pkcs1: der), code: code)
        link.send(Self.secretMessage(secret))
        _ = try await expect(Field.secretAck)
        link.close()
    }

    func cancel() { link.close() }

    // MARK: Messages

    private static func outer(_ body: (inout ProtoWriter) -> Void) -> Data {
        ProtoWriter.build { message in
            message.int(Field.protocolVersion, 2)
            message.int(Field.status, statusOK)
            body(&message)
        }
    }

    static func pairingRequestMessage(clientName: String) -> Data {
        outer { $0.message(Field.pairingRequest) { request in
            request.string(1, "atvremote")
            request.string(2, clientName)
        } }
    }

    static func optionsMessage() -> Data {
        outer { $0.message(Field.options) { options in
            options.message(1) { encoding in
                encoding.int(1, encodingHex)
                encoding.int(2, codeLength)
            }
            options.int(3, roleInput)
        } }
    }

    static func configurationMessage() -> Data {
        outer { $0.message(Field.configuration) { configuration in
            configuration.message(1) { encoding in
                encoding.int(1, encodingHex)
                encoding.int(2, codeLength)
            }
            configuration.int(2, roleInput)
        } }
    }

    static func secretMessage(_ secret: Data) -> Data {
        outer { $0.message(Field.secret) { $0.bytes(1, secret) } }
    }

    private func expect(_ field: Int) async throws -> ProtoMessage {
        let watchdog = Task { [link] in
            try await Task.sleep(nanoseconds: 15_000_000_000)
            link.close()
        }
        defer { watchdog.cancel() }
        guard let raw = try await iterator.next() else { throw LinkError.timeout }
        let message = try ProtoMessage(raw)
        let status = message.int(Field.status)
        guard status == Self.statusOK else { throw PairingError.rejected(status) }
        guard message.has(field) else { throw PairingError.unexpected }
        return message
    }
}
