import Foundation

/// Just enough ASN.1 DER to build a self-signed X.509 certificate and read RSA public keys.
enum DER {
    struct Node {
        let tag: UInt8
        let content: [UInt8]
    }

    enum DERError: Error { case malformed }

    static func tlv(_ tag: UInt8, _ content: [UInt8]) -> [UInt8] { [tag] + length(content.count) + content }
    static func sequence(_ items: [[UInt8]]) -> [UInt8] { tlv(0x30, items.flatMap { $0 }) }
    static func set(_ items: [[UInt8]]) -> [UInt8] { tlv(0x31, items.flatMap { $0 }) }
    static func explicit(_ number: UInt8, _ content: [UInt8]) -> [UInt8] { tlv(0xa0 | number, content) }
    static let null: [UInt8] = [0x05, 0x00]
    static func boolean(_ value: Bool) -> [UInt8] { [0x01, 0x01, value ? 0xff : 0x00] }
    static func bitString(_ bytes: [UInt8]) -> [UInt8] { tlv(0x03, [0x00] + bytes) }
    static func octetString(_ bytes: [UInt8]) -> [UInt8] { tlv(0x04, bytes) }
    static func utf8String(_ string: String) -> [UInt8] { tlv(0x0c, Array(string.utf8)) }

    /// Unsigned big-endian magnitude as a DER INTEGER.
    static func integer(_ magnitude: [UInt8]) -> [UInt8] {
        var bytes = Array(magnitude.drop(while: { $0 == 0 }))
        if bytes.isEmpty { bytes = [0] }
        if bytes[0] & 0x80 != 0 { bytes.insert(0, at: 0) }
        return tlv(0x02, bytes)
    }

    static func integer(_ value: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        var v = value
        repeat {
            bytes.insert(UInt8(v & 0xff), at: 0)
            v >>= 8
        } while v > 0
        return integer(bytes)
    }

    static func oid(_ components: [UInt64]) -> [UInt8] {
        var body: [UInt8] = [UInt8(components[0] * 40 + components[1])]
        for component in components.dropFirst(2) {
            var chunk: [UInt8] = [UInt8(component & 0x7f)]
            var v = component >> 7
            while v > 0 {
                chunk.insert(UInt8(v & 0x7f) | 0x80, at: 0)
                v >>= 7
            }
            body += chunk
        }
        return tlv(0x06, body)
    }

    /// UTCTime until 2049, GeneralizedTime from 2050 (RFC 5280 4.1.2.5).
    static func time(_ date: Date) -> [UInt8] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        let year = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: date).year ?? 2000
        if year < 2050 {
            formatter.dateFormat = "yyMMddHHmmss'Z'"
            return tlv(0x17, Array(formatter.string(from: date).utf8))
        }
        formatter.dateFormat = "yyyyMMddHHmmss'Z'"
        return tlv(0x18, Array(formatter.string(from: date).utf8))
    }

    private static func length(_ count: Int) -> [UInt8] {
        if count < 0x80 { return [UInt8(count)] }
        var bytes: [UInt8] = []
        var v = count
        while v > 0 {
            bytes.insert(UInt8(v & 0xff), at: 0)
            v >>= 8
        }
        return [0x80 | UInt8(bytes.count)] + bytes
    }

    // MARK: Reading

    static func read(_ bytes: [UInt8], at index: inout Int) throws -> Node {
        guard index + 2 <= bytes.count else { throw DERError.malformed }
        let tag = bytes[index]
        var length = Int(bytes[index + 1])
        index += 2
        if length & 0x80 != 0 {
            let count = length & 0x7f
            guard count > 0, count <= 4, index + count <= bytes.count else { throw DERError.malformed }
            length = 0
            for _ in 0..<count {
                length = length << 8 | Int(bytes[index])
                index += 1
            }
        }
        guard index + length <= bytes.count else { throw DERError.malformed }
        let node = Node(tag: tag, content: Array(bytes[index..<(index + length)]))
        index += length
        return node
    }

    static func children(_ content: [UInt8]) throws -> [Node] {
        var nodes: [Node] = []
        var index = 0
        while index < content.count { nodes.append(try read(content, at: &index)) }
        return nodes
    }

    /// Parses a PKCS#1 RSAPublicKey (SEQUENCE { modulus, publicExponent }), the format
    /// `SecKeyCopyExternalRepresentation` returns. Leading zero bytes are stripped.
    static func rsaPublicKey(pkcs1 der: Data) throws -> (modulus: [UInt8], exponent: [UInt8]) {
        var index = 0
        let outer = try read([UInt8](der), at: &index)
        let parts = try children(outer.content)
        guard outer.tag == 0x30, parts.count >= 2, parts[0].tag == 0x02, parts[1].tag == 0x02 else { throw DERError.malformed }
        return (Array(parts[0].content.drop(while: { $0 == 0 })), Array(parts[1].content.drop(while: { $0 == 0 })))
    }
}

enum CertificateBuilder {
    static let sha256WithRSA = DER.sequence([DER.oid([1, 2, 840, 113549, 1, 1, 11]), DER.null])
    static let rsaEncryption = DER.sequence([DER.oid([1, 2, 840, 113549, 1, 1, 1]), DER.null])

    /// TBSCertificate for a self-signed RSA certificate. Mirrors the certificate the reference
    /// Python client (androidtvremote2) generates: CN only, basicConstraints CA, 10 years.
    static func tbs(commonName: String, publicKeyPKCS1: [UInt8], serial: [UInt8], notBefore: Date, notAfter: Date) -> [UInt8] {
        let name = DER.sequence([DER.set([DER.sequence([DER.oid([2, 5, 4, 3]), DER.utf8String(commonName)])])])
        let spki = DER.sequence([rsaEncryption, DER.bitString(publicKeyPKCS1)])
        let basicConstraints = DER.sequence([
            DER.oid([2, 5, 29, 19]),
            DER.octetString(DER.sequence([DER.boolean(true)]))
        ])
        return DER.sequence([
            DER.explicit(0, DER.integer(2)),
            DER.integer(serial),
            sha256WithRSA,
            name,
            DER.sequence([DER.time(notBefore), DER.time(notAfter)]),
            name,
            spki,
            DER.explicit(3, DER.sequence([basicConstraints]))
        ])
    }

    static func certificate(tbs: [UInt8], signature: [UInt8]) -> [UInt8] {
        DER.sequence([tbs, sha256WithRSA, DER.bitString(signature)])
    }

    static func pem(_ der: Data) -> String {
        let base64 = der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----\n"
    }
}
