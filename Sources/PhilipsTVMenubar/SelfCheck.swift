import Foundation
import Security

/// Offline checks (`--self-check`). Expected bytes come from androidtvremote2's generated
/// protobuf classes, the reference implementation of the protocol.
enum SelfCheck {
    private static var failures = 0

    static func run() -> Int32 {
        check("protobuf varint 300") { ProtoWriter.build { $0.uint(1, 300) }.hex == "08ac02" }
        check("protobuf negative int") { (try? ProtoMessage(ProtoWriter.build { $0.int(1, -2) }))?.int(1) == -2 }
        check("protobuf nested round trip") {
            let data = ProtoWriter.build { $0.message(50) { $0.int(6, 100); $0.int(7, 23); $0.bool(8, true) } }
            guard let volume = (try? ProtoMessage(data))?.message(50) else { return false }
            return volume.int(6) == 100 && volume.int(7) == 23 && volume.bool(8)
        }
        check("protobuf empty sub-message") {
            guard let message = try? ProtoMessage(Data([0xc2, 0x02, 0x00])) else { return false }
            return message.has(40) && message.message(40)?.bool(1) == false
        }
        check("varint incomplete") {
            var index = 0
            do { return try ProtoMessage.readVarint([0x80], at: &index) == nil } catch { return false }
        }

        check("key message") { RemoteSession.keyMessage(.home).hex == "520408031003" }
        check("app link message") {
            RemoteSession.appLinkMessage("com.netflix.ninja").hex
                == "d205260a246d61726b65743a2f2f6c61756e63683f69643d636f6d2e6e6574666c69782e6e696e6a61"
        }
        check("configure reply") { RemoteSession.configureReply(features: 615).hex == "0a1c08e704121718012201312a0961747672656d6f74653205312e302e30" }
        check("set active reply") { RemoteSession.setActiveReply(features: 615).hex == "120308e704" }
        check("ping reply") { RemoteSession.pingReply(7).hex == "4a020807" }
        check("text message") { RemoteSession.textMessage("abc", imeCounter: 5, fieldCounter: 7).hex == "aa0113080510071a0d08011209080210021a03616263" }
        check("pairing request") {
            PairingSession.pairingRequestMessage(clientName: "PhilipsTV Menubar").hex
                == "080210c801521e0a0961747672656d6f746512115068696c6970735456204d656e75626172"
        }
        check("pairing options") { PairingSession.optionsMessage().hex == "080210c801a201080a04080310061801" }
        check("pairing configuration") { PairingSession.configurationMessage().hex == "080210c801f201080a04080310061001" }
        check("pairing secret message") {
            PairingSession.secretMessage(Data((0..<32).map { UInt8($0) })).hex
                == "080210c801c202220a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
        }

        check("pairing secret vector") {
            let client = [UInt8(0xc1)] + (0..<255).map { UInt8(($0 * 7) % 256) }
            let server = [UInt8(0xa5)] + (0..<255).map { UInt8(($0 * 13 + 1) % 256) }
            let exponent: [UInt8] = [1, 0, 1]
            let secret = try? PairingSecret.compute(client: (client, exponent), server: (server, exponent), code: "4e3f9a")
            return secret?.hex == "4e624079faa2d026568a4736ae8c88ce38c88e34059d81dfa52698c58c500c91"
        }
        check("pairing rejects wrong code") {
            let key = ([UInt8](repeating: 0xc1, count: 256), [UInt8]([1, 0, 1]))
            do { _ = try PairingSecret.compute(client: key, server: key, code: "ZZ0000"); return false } catch PairingError.invalidCode { return true } catch { return false }
        }

        check("DER integer sign padding") { DER.integer([0x80]) == [0x02, 0x02, 0x00, 0x80] }
        check("DER OID sha256WithRSA") { DER.oid([1, 2, 840, 113549, 1, 1, 11]) == [0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x0b] }
        check("DER long length") { DER.tlv(0x04, [UInt8](repeating: 0, count: 300)).prefix(4) == [0x04, 0x82, 0x01, 0x2c] }
        check("self-signed certificate") { certificateCheck() }

        check("app catalog") {
            let ids = AppCatalog.builtIn.map(\.id)
            return Set(ids).count == ids.count && AppCatalog.builtIn.allSatisfy { $0.link?.contains("://") ?? true }
                && AppCatalog.defaultFavorites.allSatisfy { ids.contains($0) }
        }
        check("key names") { KeyCode(name: "KEYCODE_HOME") == .home && KeyCode(name: "5") == .digit5 && KeyCode(name: "tv_input_hdmi_2") == .hdmi2 }
        check("MAC parsing") { WakeOnLAN.macBytes("aa-bb-cc-dd-ee-0f") == [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0x0f] && WakeOnLAN.macBytes("aa:bb") == nil }

        print(failures == 0 ? "SELF-CHECK OK" : "SELF-CHECK FAILED: \(failures)")
        return failures == 0 ? 0 : 1
    }

    private static func check(_ name: String, _ body: () -> Bool) {
        let passed = body()
        if !passed { failures += 1 }
        print("\(passed ? "PASS" : "FAIL") \(name)")
    }

    /// Builds a certificate with a throwaway key (not stored in the Keychain) and checks that
    /// Security.framework parses it and that the signature verifies.
    private static func certificateCheck() -> Bool {
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: 2048]
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, nil),
              let publicKey = SecKeyCopyPublicKey(privateKey),
              let publicDER = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?,
              let der = try? ClientIdentity.makeCertificate(privateKey: privateKey, commonName: "PhilipsTV Menubar"),
              let certificate = SecCertificateCreateWithData(nil, der as CFData),
              let certificateKey = SecCertificateCopyKey(certificate),
              let certificateKeyDER = SecKeyCopyExternalRepresentation(certificateKey, nil) as Data?,
              certificateKeyDER == publicDER,
              SecCertificateCopySubjectSummary(certificate) as String? == "PhilipsTV Menubar" else { return false }
        var index = 0
        guard let outer = try? DER.read([UInt8](der), at: &index), let parts = try? DER.children(outer.content), parts.count == 3 else { return false }
        let tbs = DER.tlv(parts[0].tag, parts[0].content)
        let signature = Data(parts[2].content.dropFirst())
        return SecKeyVerifySignature(publicKey, .rsaSignatureMessagePKCS1v15SHA256, Data(tbs) as CFData, signature as CFData, nil)
    }
}

extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
