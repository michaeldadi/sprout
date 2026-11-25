import Foundation

/// Reads the same authenticated, non-deleted SwiftData records for Home and Activity.
@MainActor
enum ActivityRecordSource {
    static func load(from dataContainer: DataContainer, userID: String) throws -> [ActivityItem] {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.userId == userID && !transaction.isDeleted
        }
        return try dataContainer.fetchTransactions(predicate: predicate).map { record in
            ActivityItem(
                id: record.id,
                title: [record.merchant, record.transactionDescription, record.category]
                    .compactMap { $0 }.first(where: { !$0.isEmpty }) ?? "Transaction",
                category: record.category,
                amount: Decimal(string: String(record.amount)) ?? Decimal(record.amount),
                currencyCode: record.currency,
                date: record.date,
                kind: displayKind(record.type),
                syncState: ActivitySyncState(rawValue: record.syncStatus.rawValue) ?? .pending,
                lastSyncedAt: record.lastSyncedAt,
                paymentMethod: record.paymentMethod,
                notes: record.notes
            )
        }
    }

    private static func displayKind(_ type: TransactionType) -> ActivityKind {
        switch type {
        case .income: return .income
        case .expense: return .expense
        case .transfer: return .transfer
        }
    }
}
