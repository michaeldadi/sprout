import Foundation
import ImageIO
import Vision

/// Suggestions from on-device OCR. The normal expense editor still validates and saves.
struct MoneyReceiptExtraction {
    var totals: [Int64] = []
    var merchant: String?
    var date: String?
    var amount: String { totals.count == 1 ? NSDecimalNumber(decimal: Decimal(totals[0]) / 100).stringValue : "" }

    static func parse(_ text: String) -> Self {
        guard text.utf16.count <= SproutReceiptRules.maxCharacters else { return Self() }
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }.filter { !$0.isEmpty }
        func regex(_ pattern: String) -> NSRegularExpression? { try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) }
        func matches(_ pattern: String, _ value: String) -> [NSTextCheckingResult] { regex(pattern)?.matches(in: value, range: NSRange(value.startIndex..., in: value)) ?? [] }
        let totalPattern = regex(SproutReceiptRules.finalTotal)
        let foreign = !matches(SproutCaptureRules.unsupportedCurrency, text).isEmpty
        let refund = lines.contains { !matches(SproutReceiptRules.refund, $0).isEmpty }
        let totals: [Int64] = foreign || refund ? [] : Array(Set(lines.compactMap { line -> Int64? in
            guard let match = totalPattern?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)), let range = Range(match.range(at: 1), in: line) else { return nil }
            return MoneyAmount.parse(String(line[range]).replacingOccurrences(of: ",", with: ""))
        })).sorted()
        let merchant = lines.prefix(6).first { line in line.utf16.count <= 160 && line.filter(\.isLetter).count >= 2 && matches(SproutReceiptRules.merchantNoise, line).isEmpty }
        let dates = Set(matches(SproutReceiptRules.date, text).compactMap { match -> String? in
            func value(_ group: Int) -> Int? { Range(match.range(at: group), in: text).flatMap { Int(text[$0]) } }
            let iso = value(1) != nil
            guard let year = value(iso ? 1 : 6), let month = value(iso ? 2 : 4), let day = value(iso ? 3 : 5), (1900...2100).contains(year) else { return nil }
            let date = String(format: "%04d-%02d-%02d", year, month, day)
            let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
            guard let parsed = formatter.date(from: date), formatter.string(from: parsed) == date else { return nil }
            return date
        })
        return Self(totals: totals, merchant: merchant, date: dates.count == 1 ? dates.first : nil)
    }
}

enum MoneyReceiptOCR {
    static func recognize(_ data: Data) async throws -> String {
        try await scan(data).text
    }
    static func scan(_ data: Data) async throws -> (text: String, jpeg: Data?) {
        guard data.count <= 25 * 1024 * 1024 else { throw MoneyAPIError(code: "RECEIPT_SIZE", message: "Choose a smaller receipt image or enter its details manually.") }
        return try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            guard let source = CGImageSourceCreateWithData(data as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 2400, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { throw MoneyAPIError(code: "RECEIPT_IMAGE", message: "This receipt image could not be opened.") }
            let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.recognitionLanguages = ["en-US"]
            try VNImageRequestHandler(cgImage: image).perform([request])
            try Task.checkCancellation()
            let text = request.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") ?? ""
            var jpeg: Data?
            for quality in [0.85, 0.7, 0.55, 0.4] {
                let output = NSMutableData()
                if let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
                    if CGImageDestinationFinalize(destination), output.length <= 650_000 { jpeg = output as Data; break }
                }
            }
            return (text, jpeg)
        }.value
    }
}
