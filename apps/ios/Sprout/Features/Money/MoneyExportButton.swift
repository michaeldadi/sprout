import Appwrite
import CryptoKit
import SwiftUI

struct MoneyExportButton: View {
    @EnvironmentObject private var store: MoneyStore
    let fileId: String
    let bucketId: String
    @State private var url: URL?
    @State private var busy = false
    @State private var error: String?
    @State private var progress = "Preparing your export…"
    var body: some View {
        if let url {
            ShareLink("Save or share export", item: url)
        } else {
            Button("Download private export") { Task { await download() } }.disabled(busy)
        }
        if busy {
            ProgressView(progress)
        }
        if let error {
            Text(error).font(.footnote).foregroundStyle(SproutColor.error)
        }
    }

    private func download() async {
        busy = true; defer { busy = false }
        do {
            guard AppwriteNativeSession.shared.identity?.id == store.identity.id else { throw CancellationError() }
            let storage = Storage(try AppwriteConnection.client())
            let data = try await storage.getFileDownload(bucketId: bucketId, fileId: fileId)
            guard AppwriteNativeSession.shared.identity?.id == store.identity.id else { throw CancellationError() }
            let json = Data(data.readableBytesView), receipts = try MoneyExportArchive.receipts(in: json, bucket: bucketId)
            var archive = MoneyExportArchive.ZIP()
            try archive.append(name: "sprout-export.json", data: json)
            try archive.append(name: "README.txt", data: MoneyExportArchive.readme)
            for (index, receipt) in receipts.enumerated() {
                try Task.checkCancellation()
                guard AppwriteNativeSession.shared.identity?.id == store.identity.id else { throw CancellationError() }
                progress = "Preparing receipt \(index + 1) of \(receipts.count)…"
                let image = try await storage.getFileDownload(bucketId: receipt.data.bucketId, fileId: receipt.data.fileId)
                guard AppwriteNativeSession.shared.identity?.id == store.identity.id else { throw CancellationError() }
                let bytes = Data(image.readableBytesView); try MoneyExportArchive.verify(bytes, receipt: receipt)
                try archive.append(name: "receipts/\(receipt.id).jpg", data: bytes)
            }
            let project = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_PROJECT_ID") as? String ?? ""
            let endpoint = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_ENDPOINT") as? String ?? ""
            let scope = SHA256.hash(data: Data("\(endpoint)/\(project)/\(store.identity.id)".utf8)).map { String(format: "%02x", $0) }.joined()
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sprout-exports/\(scope)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let target = directory.appendingPathComponent("sprout-\(UUID().uuidString).zip")
            try archive.finish().write(to: target, options: [.atomic, .completeFileProtection])
            url = target
        } catch { self.error = "Your export could not be prepared. Sign in to the same account and retry, or request a fresh export if a retained receipt was removed." }
    }
}
