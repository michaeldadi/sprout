import Appwrite
import CryptoKit
import ImageIO
import SwiftUI
import UIKit

struct MoneyReceiptSection: View {
    @EnvironmentObject private var store: MoneyStore
    let transactionId: String
    private var pending: [MoneyMutation] { store.mutations.filter { mutation in guard MoneyReceiptArchive.reference(mutation.payload) != nil, let value = try? JSONSerialization.jsonObject(with: mutation.payload) as? [String: Any], let command = value["command"] as? [String: Any] else { return false }; return command["transactionId"] as? String == transactionId } }
    var body: some View {
        let localIds = Set(pending.compactMap { MoneyReceiptArchive.reference($0.payload) })
        ForEach(pending, id: \.id) { mutation in
            MoneyCard { Label(mutation.conflict ? "Receipt upload needs review" : "Receipt saved on this device", systemImage: "doc"); Text(mutation.conflict ? "Review or discard the pending copy in Profile. Your transaction remains saved." : "The private copy uploads after its transaction has synced.").font(.footnote); MoneyPendingReceiptButton(mutation: mutation) }
        }
        ForEach(store.workspace?.receipts?.filter { $0.transactionId == transactionId && !localIds.contains($0.id) } ?? []) { MoneyReceiptRow(receipt: $0).environmentObject(store) }
    }
}

struct MoneyPendingReceiptButton: View {
    @EnvironmentObject private var store: MoneyStore
    let mutation: MoneyMutation
    @State private var jpeg: Data?
    @State private var error: String?
    var body: some View {
        Button("View on-device receipt copy") { do { guard let id = MoneyReceiptArchive.reference(mutation.payload) else { return }; jpeg = try MoneyReceiptArchive.read(id: id, owner: store.identity.id) } catch { self.error = error.localizedDescription } }
            .sheet(isPresented: Binding(get: { jpeg != nil }, set: { if !$0 { jpeg = nil } })) { if let jpeg { MoneyReceiptImage(data: jpeg, owner: store.identity.id) } }
        if let error { Text(error).font(.footnote).foregroundStyle(SproutColor.error) }
    }
}

private struct MoneyReceiptRow: View {
    @EnvironmentObject private var store: MoneyStore
    let receipt: MoneyReceipt
    @State private var requested = false
    @State private var jpeg: Data?
    @State private var error: String?
    @State private var confirm = false
    @State private var removalVersion: Int?
    private var removing: Bool { receipt.status == "removing" || store.mutations.contains { $0.entityKey == "receipt-remove:\(receipt.id)" || $0.entityKey == "receipt-cancel:\(receipt.id)" } }
    var body: some View {
        MoneyCard {
            Label("Private receipt copy", systemImage: "doc.richtext").font(.headline)
            Text(ByteCountFormatter.string(fromByteCount: Int64(receipt.bytes), countStyle: .file)).font(.caption).foregroundStyle(SproutColor.textSecondary)
            if removing { Text("Removal is saved and will finish when connected. Previously started uploads are reconciled first.").font(.footnote) }
            else if receipt.status == "ready" { Button(requested ? "Opening receipt…" : "View private receipt") { requested = true }.disabled(requested) }
            else { Text(receipt.status == "awaiting_upload" ? "Waiting for this device's saved copy to upload." : "Private upload is being recovered.").font(.footnote) }
            Button("Remove Sprout receipt copy", role: .destructive) { removalVersion = receipt.version; confirm = true }.disabled(removing)
            if let error { Text(error).font(.footnote).foregroundStyle(SproutColor.error) }
        }
        .confirmationDialog("Remove this private Sprout copy?", isPresented: $confirm, titleVisibility: .visible) { Button("Remove receipt copy", role: .destructive) { do { guard let version = removalVersion else { return }; try store.enqueue(["type": "receipt.remove", "id": receipt.id, "expectedVersion": version], entity: "receipt-remove:\(receipt.id)"); jpeg = nil } catch { self.error = error.localizedDescription } } }
        .task(id: requested) {
            guard requested else { return }; defer { requested = false }
            do {
                guard !removing, let file = receipt.fileId, let bucket = receipt.bucketId, AppwriteNativeSession.shared.identity?.id == store.identity.id else { throw CancellationError() }
                let downloaded = try await Storage(AppwriteConnection.client()).getFileDownload(bucketId: bucket, fileId: file)
                try Task.checkCancellation()
                let bytes = Data(downloaded.readableBytesView)
                guard AppwriteNativeSession.shared.identity?.id == store.identity.id, bytes.count == receipt.bytes, bytes.count <= 650_000, SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == receipt.sha256 else { throw MoneyAPIError(code: "RECEIPT_SCOPE", message: "This private copy could not be verified. Refresh and try again.") }
                jpeg = bytes; error = nil
            } catch is CancellationError { } catch { self.error = "The private receipt could not be opened. Connect to Sprout and try again." }
        }
        .onChange(of: removing) { _, value in if value { requested = false; jpeg = nil } }
        .sheet(isPresented: Binding(get: { jpeg != nil }, set: { if !$0 { jpeg = nil } })) { if let jpeg { MoneyReceiptImage(data: jpeg, owner: store.identity.id) } }
    }
}

private struct MoneyReceiptImage: View {
    @Environment(\.dismiss) private var dismiss
    let data: Data
    let owner: String
    @State private var image: UIImage?
    @State private var url: URL?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView { VStack(spacing: 16) {
                if let image { Image(uiImage: image).resizable().scaledToFit().accessibilityLabel("Receipt image. Reviewed transaction details are on the previous screen.") }
                if let url { ShareLink("Save or share a copy", item: url) }
                if let error { Text(error).foregroundStyle(SproutColor.error) }
            }.padding() }.navigationTitle("Private receipt").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }.task {
            do {
                guard AppwriteNativeSession.shared.identity?.id == owner, data.count <= 650_000, let source = CGImageSourceCreateWithData(data as CFData, nil), let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 2400, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { throw CancellationError() }
                image = UIImage(cgImage: decoded)
                let endpoint = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_ENDPOINT") as? String ?? "", project = Bundle.main.object(forInfoDictionaryKey: "SPROUT_APPWRITE_PROJECT_ID") as? String ?? ""
                let scope = SHA256.hash(data: Data("\(endpoint)/\(project)/\(owner)".utf8)).map { String(format: "%02x", $0) }.joined()
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sprout-exports/\(scope)", isDirectory: true); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let file = directory.appendingPathComponent("receipt-\(UUID().uuidString).jpg"); try data.write(to: file, options: [.atomic, .completeFileProtection]); url = file
            } catch { self.error = "This receipt image could not be opened." }
        }.onDisappear { if let url { try? FileManager.default.removeItem(at: url) }; image = nil }
    }
}
