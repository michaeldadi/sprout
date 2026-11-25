import CryptoKit
import Foundation

enum MoneyExportArchive {
    struct Receipt: Decodable {
        let id: String
        let deleted: Bool
        let data: Detail
        struct Detail: Decodable { let status: String; let fileId: String; let bucketId: String; let sha256: String; let bytes: Int }
    }
    private struct Snapshot: Decodable {
        let schemaVersion: Int
        let revision: Int64
        let exportedAt: String
        let records: Records
        struct Records: Decodable { let receipts: [Receipt]? }
    }
    static func receipts(in json: Data, bucket: String) throws -> [Receipt] {
        guard json.count <= 9_000_000 else { throw invalid() }
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: json)
        guard snapshot.schemaVersion == 1, snapshot.revision >= 0, ISO8601DateFormatter().date(from: snapshot.exportedAt) != nil || ISO8601DateFormatter.fractional.date(from: snapshot.exportedAt) != nil else { throw invalid() }
        let receipts = (snapshot.records.receipts ?? []).filter { !$0.deleted && $0.data.status == "ready" }
        guard receipts.count <= 100, Set(receipts.map(\.id)).count == receipts.count, receipts.allSatisfy({ UUID(uuidString: $0.id)?.uuidString.lowercased() == $0.id && $0.data.bucketId == bucket && $0.data.bytes > 0 && $0.data.bytes <= 650_000 && $0.data.sha256.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil }), receipts.reduce(0, { $0 + $1.data.bytes }) <= 50_000_000 else { throw invalid() }
        return receipts
    }
    static func verify(_ data: Data, receipt: Receipt) throws {
        guard data.count == receipt.data.bytes, SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == receipt.data.sha256 else { throw invalid() }
    }
    static func invalid() -> NSError { NSError(domain: "SproutExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "This export could not be verified. Request a fresh export if a retained receipt was changed or removed."]) }

    /// Classic stored ZIP: bounded to 102 entries and 60 MB; no compression or
    /// user-supplied paths. Receipts are already compressed JPEGs.
    struct ZIP {
        private(set) var bytes = Data()
        private var central = Data()
        private var names = Set<String>()
        mutating func append(name: String, data: Data) throws {
            guard name.range(of: "^(sprout-export.json|README.txt|receipts/[a-f0-9-]{36}\\.jpg)$", options: .regularExpression) != nil, !names.contains(name), names.count < 102, bytes.count + data.count <= 60_000_000 else { throw MoneyExportArchive.invalid() }
            let filename = Data(name.utf8), size = UInt32(data.count), offset = UInt32(bytes.count), checksum = Self.crc(data)
            bytes.le(UInt32(0x04034b50)); bytes.le(UInt16(20)); bytes.le(UInt16(0)); bytes.le(UInt16(0)); bytes.le(UInt16(0)); bytes.le(UInt16(0x21)); bytes.le(checksum); bytes.le(size); bytes.le(size); bytes.le(UInt16(filename.count)); bytes.le(UInt16(0)); bytes.append(filename); bytes.append(data)
            central.le(UInt32(0x02014b50)); central.le(UInt16(20)); central.le(UInt16(20)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt16(0x21)); central.le(checksum); central.le(size); central.le(size); central.le(UInt16(filename.count)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt32(0)); central.le(offset); central.append(filename); names.insert(name)
        }
        mutating func finish() -> Data {
            let offset = UInt32(bytes.count); bytes.append(central); bytes.le(UInt32(0x06054b50)); bytes.le(UInt16(0)); bytes.le(UInt16(0)); bytes.le(UInt16(names.count)); bytes.le(UInt16(names.count)); bytes.le(UInt32(central.count)); bytes.le(offset); bytes.le(UInt16(0)); return bytes
        }
        private static let table: [UInt32] = (0..<256).map { value in var c = UInt32(value); for _ in 0..<8 { c = c & 1 == 1 ? 0xedb88320 ^ (c >> 1) : c >> 1 }; return c }
        private static func crc(_ data: Data) -> UInt32 { var c: UInt32 = 0xffffffff; for byte in data { c = table[Int((c ^ UInt32(byte)) & 0xff)] ^ (c >> 8) }; return c ^ 0xffffffff }
    }
    static let readme = Data("Sprout private export\nFinancial records and receipt metadata are in sprout-export.json. Ready retained receipt copies are in receipts/<receipt-id>.jpg. Pending uploads and removing copies remain described by their metadata and are not represented as available files. Export reflects the JSON snapshot timestamp. Store this archive securely.\n".utf8)
}
private extension Data {
    mutating func le<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) } }
}
private extension ISO8601DateFormatter {
    static var fractional: ISO8601DateFormatter { let formatter = ISO8601DateFormatter(); formatter.formatOptions.insert(.withFractionalSeconds); return formatter }
}
