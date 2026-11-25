import CryptoKit
import Foundation

enum MoneyReceiptArchive {
    private static func directory(owner: String) throws -> URL {
        let endpoint = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_ENDPOINT") as? String ?? ""
        let project = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_PROJECT_ID") as? String ?? ""
        let scope = SHA256.hash(data: Data("\(endpoint)/\(project)/\(owner)".utf8)).map { String(format: "%02x", $0) }.joined()
        return try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("SproutReceiptOutbox/\(scope)", isDirectory: true)
    }
    private static func file(id: String, owner: String) throws -> URL {
        guard UUID(uuidString: id)?.uuidString.lowercased() == id else { throw MoneyAPIError(code: "INVALID_RECEIPT", message: "This local receipt reference needs review.") }
        return try directory(owner: owner).appendingPathComponent(id + ".jpg")
    }
    static func save(id: String, jpeg: Data, owner: String) throws {
        guard jpeg.count <= 650_000 else { throw MoneyAPIError(code: "INVALID_RECEIPT", message: "Choose a smaller receipt copy.") }
        var directory = try Self.directory(owner: owner)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        var values = URLResourceValues(); values.isExcludedFromBackup = true; try directory.setResourceValues(values)
        try jpeg.write(to: file(id: id, owner: owner), options: [.atomic, .completeFileProtection])
    }
    static func read(id: String, owner: String) throws -> Data {
        let url = try file(id: id, owner: owner)
        guard FileManager.default.fileExists(atPath: url.path) else { throw MoneyAPIError(code: "RECEIPT_LOCAL_MISSING", message: "This device no longer has the pending receipt copy. Choose its photo again, or discard the pending copy in Profile.") }
        guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 650_000 else { throw MoneyAPIError(code: "INVALID_RECEIPT", message: "The pending receipt copy needs review.") }
        do { return try Data(contentsOf: url) } catch { throw MoneyAPIError(code: "RECEIPT_RETRY", message: "Unlock this device to resume its private receipt upload.") }
    }
    static func wire(_ payload: Data, owner: String) throws -> Data {
        guard var value = try JSONSerialization.jsonObject(with: payload) as? [String: Any], let reference = value["attachmentFile"] as? String, var command = value["command"] as? [String: Any], command["type"] as? String == "receipt.attach", let id = command["id"] as? String, reference == id + ".jpg" else { throw MoneyAPIError(code: "INVALID_RECEIPT", message: "This local receipt reference needs review.") }
        let jpeg = try read(id: id, owner: owner), hash = SHA256.hash(data: jpeg).map { String(format: "%02x", $0) }.joined()
        guard hash == command["sha256"] as? String else { throw MoneyAPIError(code: "RECEIPT_LOCAL_CHANGED", message: "The pending receipt image changed. Choose its photo again before uploading.") }
        command["jpegBase64"] = jpeg.base64EncodedString(); value["command"] = command; value.removeValue(forKey: "attachmentFile")
        return try JSONSerialization.data(withJSONObject: value)
    }
    static func reference(_ payload: Data) -> String? {
        guard let value = try? JSONSerialization.jsonObject(with: payload) as? [String: Any], let command = value["command"] as? [String: Any], command["type"] as? String == "receipt.attach", let id = command["id"] as? String, value["attachmentFile"] as? String == id + ".jpg" else { return nil }; return id
    }
    static func remove(id: String, owner: String) throws { let url = try file(id: id, owner: owner); if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) } }
    static func erase(owner: String) throws { let url = try directory(owner: owner); if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) } }
    static func prune(owner: String, keeping: Set<String>) throws {
        let directory = try Self.directory(owner: owner)
        for url in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] where url.pathExtension == "jpg" && UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil && !keeping.contains(url.deletingPathExtension().lastPathComponent) { try FileManager.default.removeItem(at: url) }
    }
}
