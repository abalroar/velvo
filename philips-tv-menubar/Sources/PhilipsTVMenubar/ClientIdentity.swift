import Foundation
import Security
import CryptoKit

enum IdentityError: LocalizedError {
    case keyGeneration(String)
    case signing(String)
    case certificate
    case identity(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keyGeneration(let detail): return "Não foi possível criar a chave do Mac: \(detail)"
        case .signing(let detail): return "Não foi possível assinar o certificado do Mac: \(detail)"
        case .certificate: return "O certificado gerado é inválido."
        case .identity(let status): return "O Keychain não devolveu a identidade do Mac (OSStatus \(status))."
        }
    }
}

/// The Mac's TLS client identity. The TV remembers this certificate when you pair, so it must
/// survive app restarts: the private key lives in the login Keychain, the (public) certificate
/// in Application Support.
final class ClientIdentity {
    let identity: SecIdentity
    let certificate: SecCertificate
    let publicKey: (modulus: [UInt8], exponent: [UInt8])

    static let keyTag = Data("br.local.PhilipsTVMenubar.client-key".utf8)
    static let label = "PhilipsTV Menubar client key"

    private init(identity: SecIdentity, certificate: SecCertificate) throws {
        self.identity = identity
        self.certificate = certificate
        guard let key = SecCertificateCopyKey(certificate), let der = SecKeyCopyExternalRepresentation(key, nil) as Data? else {
            throw IdentityError.certificate
        }
        publicKey = try DER.rsaPublicKey(pkcs1: der)
    }

    static var certificateURL: URL { AppPaths.dataDirectory.appendingPathComponent("client-certificate.der") }

    static func loadOrCreate() throws -> ClientIdentity {
        if let der = try? Data(contentsOf: certificateURL), let certificate = SecCertificateCreateWithData(nil, der as CFData) {
            var identity: SecIdentity?
            if SecIdentityCreateWithCertificate(nil, certificate, &identity) == errSecSuccess, let identity {
                return try ClientIdentity(identity: identity, certificate: certificate)
            }
        }
        return try create()
    }

    /// Removes the key and certificate. Every TV must be paired again afterwards.
    static func reset() {
        let query: [String: Any] = [kSecClass as String: kSecClassKey, kSecAttrApplicationTag as String: keyTag]
        SecItemDelete(query as CFDictionary)
        try? FileManager.default.removeItem(at: certificateURL)
    }

    private static func create() throws -> ClientIdentity {
        reset()
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag,
                kSecAttrLabel as String: label
            ] as [String: Any]
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw IdentityError.keyGeneration(error.map { "\($0.takeRetainedValue())" } ?? "desconhecido")
        }
        let der = try makeCertificate(privateKey: privateKey, commonName: "PhilipsTV Menubar")
        guard let certificate = SecCertificateCreateWithData(nil, der as CFData) else { throw IdentityError.certificate }
        try FileManager.default.createDirectory(at: AppPaths.dataDirectory, withIntermediateDirectories: true)
        try der.write(to: certificateURL, options: .atomic)
        var identity: SecIdentity?
        let status = SecIdentityCreateWithCertificate(nil, certificate, &identity)
        guard status == errSecSuccess, let identity else { throw IdentityError.identity(status) }
        return try ClientIdentity(identity: identity, certificate: certificate)
    }

    /// Builds and signs a self-signed certificate for `privateKey`.
    static func makeCertificate(privateKey: SecKey, commonName: String) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let publicDER = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw IdentityError.keyGeneration(error.map { "\($0.takeRetainedValue())" } ?? "sem chave pública")
        }
        var serial = [UInt8](repeating: 0, count: 8)
        _ = SecRandomCopyBytes(kSecRandomDefault, serial.count, &serial)
        serial[0] &= 0x7f
        let now = Date()
        let tbs = CertificateBuilder.tbs(
            commonName: commonName,
            publicKeyPKCS1: [UInt8](publicDER),
            serial: serial,
            notBefore: now.addingTimeInterval(-86_400),
            notAfter: now.addingTimeInterval(10 * 365 * 86_400)
        )
        guard let signature = SecKeyCreateSignature(privateKey, .rsaSignatureMessagePKCS1v15SHA256, Data(tbs) as CFData, &error) as Data? else {
            throw IdentityError.signing(error.map { "\($0.takeRetainedValue())" } ?? "desconhecido")
        }
        return Data(CertificateBuilder.certificate(tbs: tbs, signature: [UInt8](signature)))
    }
}

enum Fingerprint {
    static func sha256(_ certificate: SecCertificate) -> String {
        let der = SecCertificateCopyData(certificate) as Data
        return SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined()
    }
}

enum AppPaths {
    static var dataDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["PHILIPSTV_DATA_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("PhilipsTVMenubar", isDirectory: true)
    }
}
