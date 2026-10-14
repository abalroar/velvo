import Foundation

/// Minimal protobuf wire format: varint (type 0) and length-delimited (type 2) fields,
/// which is all the Android TV Remote v2 messages use.
struct ProtoWriter {
    private(set) var data = Data()

    mutating func uint(_ field: Int, _ value: UInt64) { key(field, 0); Self.appendVarint(value, to: &data) }
    mutating func int(_ field: Int, _ value: Int) { uint(field, UInt64(bitPattern: Int64(value))) }
    mutating func bool(_ field: Int, _ value: Bool) { uint(field, value ? 1 : 0) }
    mutating func bytes(_ field: Int, _ value: Data) {
        key(field, 2)
        Self.appendVarint(UInt64(value.count), to: &data)
        data.append(value)
    }
    mutating func string(_ field: Int, _ value: String) { bytes(field, Data(value.utf8)) }
    mutating func message(_ field: Int, _ build: (inout ProtoWriter) -> Void) {
        var nested = ProtoWriter()
        build(&nested)
        bytes(field, nested.data)
    }

    private mutating func key(_ field: Int, _ wireType: UInt64) { Self.appendVarint(UInt64(field) << 3 | wireType, to: &data) }

    static func appendVarint(_ value: UInt64, to data: inout Data) {
        var v = value
        while v >= 0x80 {
            data.append(UInt8(v & 0x7f) | 0x80)
            v >>= 7
        }
        data.append(UInt8(v))
    }

    static func build(_ body: (inout ProtoWriter) -> Void) -> Data {
        var writer = ProtoWriter()
        body(&writer)
        return writer.data
    }
}

enum ProtoError: Error {
    case malformed
}

/// Decoded message. Repeated fields keep every occurrence; scalar accessors return the last one,
/// as protobuf does.
struct ProtoMessage {
    private var varints: [Int: [UInt64]] = [:]
    private var blobs: [Int: [Data]] = [:]

    init(_ data: Data) throws {
        let bytes = [UInt8](data)
        var index = 0
        while index < bytes.count {
            guard let key = try ProtoMessage.readVarint(bytes, at: &index) else { throw ProtoError.malformed }
            let field = Int(key >> 3)
            switch key & 7 {
            case 0:
                guard let value = try ProtoMessage.readVarint(bytes, at: &index) else { throw ProtoError.malformed }
                varints[field, default: []].append(value)
            case 1:
                index += 8
            case 2:
                guard let length = try ProtoMessage.readVarint(bytes, at: &index), length <= UInt64(bytes.count - index) else { throw ProtoError.malformed }
                let end = index + Int(length)
                blobs[field, default: []].append(Data(bytes[index..<end]))
                index = end
            case 5:
                index += 4
            default:
                throw ProtoError.malformed
            }
            if index > bytes.count { throw ProtoError.malformed }
        }
    }

    func has(_ field: Int) -> Bool { varints[field] != nil || blobs[field] != nil }
    func uint(_ field: Int) -> UInt64 { varints[field]?.last ?? 0 }
    func int(_ field: Int) -> Int { Int(Int32(truncatingIfNeeded: uint(field))) }
    func bool(_ field: Int) -> Bool { uint(field) != 0 }
    func data(_ field: Int) -> Data? { blobs[field]?.last }
    func string(_ field: Int) -> String { data(field).flatMap { String(data: $0, encoding: .utf8) } ?? "" }
    func message(_ field: Int) -> ProtoMessage? { data(field).flatMap { try? ProtoMessage($0) } }
    func messages(_ field: Int) -> [ProtoMessage] { (blobs[field] ?? []).compactMap { try? ProtoMessage($0) } }

    /// Reads a varint at `index`. Returns nil when the buffer ends before the varint does.
    static func readVarint(_ bytes: [UInt8], at index: inout Int) throws -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        var i = index
        while i < bytes.count {
            let byte = bytes[i]
            result |= UInt64(byte & 0x7f) << shift
            i += 1
            if byte & 0x80 == 0 {
                index = i
                return result
            }
            shift += 7
            if shift >= 64 { throw ProtoError.malformed }
        }
        return nil
    }
}
