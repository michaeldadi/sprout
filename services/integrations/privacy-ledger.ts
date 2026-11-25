import { Client, TablesDB, Query } from "node-appwrite";
import { AppError } from "../contracts";
import {
  privacyHash,
  deletionProgress,
  type DeletionProgress,
} from "../domain/privacy";

export class PrivacyLedger {
  readonly tables: TablesDB;
  readonly database: string;
  constructor(key: string) {
    this.database = process.env.SPROUT_PRIVACY_DATABASE_ID ?? "";
    if (!this.database || !key)
      throw new AppError(
        "NOT_CONFIGURED",
        "Privacy processing is not configured.",
        503,
      );
    this.tables = new TablesDB(
      new Client()
        .setEndpoint(process.env.APPWRITE_FUNCTION_API_ENDPOINT!)
        .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID!)
        .setKey(key),
    );
  }
  private ownerHash(owner: string) {
    return privacyHash(`${process.env.APPWRITE_FUNCTION_PROJECT_ID}:${owner}`);
  }
  async get(owner: string): Promise<DeletionProgress | null> {
    try {
      const row = await this.tables.getRow({
        databaseId: this.database,
        tableId: "deletion_ledger",
        rowId: this.ownerHash(owner).slice(0, 36),
      });
      if (row.owner_hash !== this.ownerHash(owner))
        throw new AppError(
          "PRIVACY_RECOVERY",
          "Privacy record ownership needs review.",
          409,
        );
      return deletionProgress.parse(JSON.parse(String(row.payload)));
    } catch (error: any) {
      if (error.code === 404) return null;
      throw error;
    }
  }
  async accept(owner: string, receiptHash: string, acceptedAt: string) {
    const progress: DeletionProgress = {
      status: "queued",
      attempts: 0,
      acceptedAt,
      updatedAt: acceptedAt,
      steps: {
        accessRevoked: false,
        attachmentsRemoved: false,
        financialRecordsRemoved: false,
        identityAnonymized: false,
      },
    };
    try {
      await this.tables.createRow({
        databaseId: this.database,
        tableId: "deletion_ledger",
        rowId: this.ownerHash(owner).slice(0, 36),
        data: {
          owner_hash: this.ownerHash(owner),
          owner_id: owner,
          receipt_hash: receiptHash,
          payload: JSON.stringify(progress),
          state: "queued",
          updated_at: acceptedAt,
          lease_until: null,
          revision: 0,
        },
        permissions: [],
      });
      return progress;
    } catch (error: any) {
      if (error.code !== 409) throw error;
      return (await this.get(owner))!;
    }
  }
  async save(owner: string, progress: DeletionProgress) {
    await this.tables.updateRow({
      databaseId: this.database,
      tableId: "deletion_ledger",
      rowId: this.ownerHash(owner).slice(0, 36),
      data: {
        payload: JSON.stringify(progress),
        state: progress.status,
        updated_at: progress.updatedAt,
        ...(progress.status === "running" ? {} : { lease_until: null }),
      },
    });
  }
  async claim(owner: string) {
    const transaction = await this.tables.createTransaction({ ttl: 60 });
    const transactionId = transaction.$id;
    try {
      const rowId = this.ownerHash(owner).slice(0, 36);
      await this.tables.incrementRowColumn({
        databaseId: this.database,
        tableId: "deletion_ledger",
        rowId,
        column: "revision",
        value: 1,
        transactionId,
      });
      const row = await this.tables.getRow({
        databaseId: this.database,
        tableId: "deletion_ledger",
        rowId,
        transactionId,
      });
      if (row.owner_id !== owner || row.owner_hash !== this.ownerHash(owner))
        throw new AppError(
          "PRIVACY_SCOPE",
          "Privacy record scope failed.",
          409,
        );
      if (
        row.state === "active_data_removed" ||
        (row.lease_until && Date.parse(String(row.lease_until)) > Date.now())
      ) {
        await this.tables.updateTransaction({ transactionId, rollback: true });
        return null;
      }
      // Twice the function's hard runtime limit, so an expired worker cannot
      // write checkpoints after a newer worker acquires this lease.
      await this.tables.updateRow({
        databaseId: this.database,
        tableId: "deletion_ledger",
        rowId,
        transactionId,
        data: {
          lease_until: new Date(Date.now() + 600_000).toISOString(),
          state: "running",
          updated_at: new Date().toISOString(),
        },
      });
      await this.tables.updateTransaction({ transactionId, commit: true });
      return {
        progress: deletionProgress.parse(JSON.parse(String(row.payload))),
        receiptHash: String(row.receipt_hash),
      };
    } catch (error: any) {
      await this.tables
        .updateTransaction({ transactionId, rollback: true })
        .catch(() => undefined);
      if (error.code === 409) return null;
      throw error;
    }
  }
  async status(receiptHash: string): Promise<DeletionProgress> {
    const page = await this.tables.listRows({
      databaseId: this.database,
      tableId: "deletion_ledger",
      queries: [Query.equal("receipt_hash", receiptHash), Query.limit(1)],
    });
    if (page.rows.length !== 1)
      throw new AppError(
        "NOT_FOUND",
        "This privacy receipt was not found.",
        404,
      );
    return deletionProgress.parse(JSON.parse(String(page.rows[0].payload)));
  }
}
