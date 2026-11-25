import {
  Account,
  Client,
  ID,
  Permission,
  Query,
  Role,
  TablesDB,
} from "node-appwrite";
import { PrivacyLedger } from "./privacy-ledger";
import { assertDeletionPermit } from "../domain/privacy";
import { createHash } from "node:crypto";
import {
  AppError,
  journalRecord,
  type Kind,
  type RecordValue,
  type Change,
  type SyncEvent,
} from "../contracts";
import type { UserStore, WriteStore } from "../domain/store";

export const rowId = (...parts: string[]) =>
  createHash("sha256").update(JSON.stringify(parts)).digest("hex").slice(0, 36);
function configuration() {
  const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT;
  const project = process.env.APPWRITE_FUNCTION_PROJECT_ID;
  const database = process.env.SPROUT_DATABASE_ID;
  if (!endpoint || !project || !database)
    throw new AppError(
      "NOT_CONFIGURED",
      "This environment has not completed financial setup.",
      503,
    );
  return { endpoint, project, database };
}
export async function authenticate(
  jwt: string | undefined,
): Promise<{ id: string; name: string; email: string }> {
  if (!jwt) throw new AppError("UNAUTHENTICATED", "Sign in to continue.", 401);
  const c = configuration();
  try {
    const user = await new Account(
      new Client().setEndpoint(c.endpoint).setProject(c.project).setJWT(jwt),
    ).get();
    return { id: user.$id, name: user.name, email: user.email };
  } catch {
    throw new AppError(
      "UNAUTHENTICATED",
      "Your session has expired. Sign in again.",
      401,
    );
  }
}
type Row = {
  $id: string;
  entity_id: string;
  version: number;
  updated_at: string;
  deleted: boolean;
  payload: string;
  owner: string;
};
const decode = <T>(r: Row): RecordValue<T> => ({
  id: r.entity_id,
  version: r.version,
  updatedAt: r.updated_at,
  deleted: r.deleted,
  data: JSON.parse(r.payload) as T,
});
const isMissing = (e: unknown) =>
  typeof e === "object" && e !== null && "code" in e && e.code === 404;
const isConflict = (e: unknown) =>
  typeof e === "object" && e !== null && "code" in e && e.code === 409;

/** All privileged queries bind owner; callers never choose owner from a request body. */
export class AppwriteStore implements UserStore {
  readonly tables: TablesDB;
  readonly database: string;
  get changeChannel() {
    return `tablesdb.${this.database}.tables.sync_heads.rows.${rowId(this.owner)}`;
  }
  private readonly ledger: PrivacyLedger | null;
  constructor(
    readonly owner: string,
    key: string,
    private allowAfterDeletion = false,
  ) {
    const c = configuration();
    this.database = c.database;
    this.ledger = process.env.SPROUT_PRIVACY_DATABASE_ID
      ? new PrivacyLedger(key)
      : null;
    if (!key)
      throw new AppError(
        "NOT_CONFIGURED",
        "The function service credential is unavailable.",
        503,
      );
    this.tables = new TablesDB(
      new Client().setEndpoint(c.endpoint).setProject(c.project).setKey(key),
    );
  }
  private async row(tableId: string, id: string, transactionId?: string) {
    try {
      const r = await this.tables.getRow({
        databaseId: this.database,
        tableId,
        rowId: id,
        transactionId,
      });
      if ((r as unknown as Row).owner !== this.owner)
        throw new AppError("NOT_FOUND", "Record not found.", 404);
      return r as unknown as Row;
    } catch (e) {
      if (isMissing(e)) return null;
      throw e;
    }
  }
  async get<T>(kind: Kind, id: string) {
    const r = await this.row(kind, rowId(this.owner, kind, id));
    return r ? decode<T>(r) : null;
  }
  private async all<T>(
    kind: Kind,
    transactionId?: string,
  ): Promise<RecordValue<T>[]> {
    const out: RecordValue<T>[] = [];
    let cursor: string | undefined;
    do {
      const page = await this.tables.listRows({
        databaseId: this.database,
        tableId: kind,
        transactionId,
        queries: [
          Query.equal("owner", this.owner),
          Query.equal("deleted", false),
          Query.orderAsc("$id"),
          Query.limit(100),
          ...(cursor ? [Query.cursorAfter(cursor)] : []),
        ],
      });
      out.push(...page.rows.map((r) => decode<T>(r as unknown as Row)));
      cursor =
        page.rows.length === 100
          ? page.rows[page.rows.length - 1].$id
          : undefined;
      if (out.length > 20_000)
        throw new AppError(
          "DATA_LIMIT",
          "This account requires a larger export/snapshot job.",
          413,
        );
    } while (cursor);
    return out;
  }
  list<T>(kind: Kind) {
    return this.all<T>(kind);
  }
  async revision(): Promise<number> {
    const r = await this.row("sync_heads", rowId(this.owner));
    return r ? Number((r as unknown as { sequence: number }).sequence) : 0;
  }
  async changes(
    after: number,
    limit = 50,
    through?: number,
  ): Promise<SyncEvent[]> {
    const r = await this.tables.listRows({
      databaseId: this.database,
      tableId: "sync_events",
      queries: [
        Query.equal("owner", this.owner),
        Query.greaterThan("sequence", after),
        ...(through === undefined
          ? []
          : [Query.lessThanEqual("sequence", through)]),
        Query.orderAsc("sequence"),
        Query.limit(Math.min(100, limit)),
      ],
    });
    return r.rows.map((v) => ({
      sequence: Number(v.sequence),
      changes: JSON.parse(String(v.payload)) as Change[],
    }));
  }
  async assertWritable(control = this.allowAfterDeletion) {
    if (this.ledger)
      assertDeletionPermit(await this.ledger.get(this.owner), control);
  }
  async mutate<T>(
    mutationId: string,
    hash: string,
    operation: (tx: WriteStore) => Promise<T>,
  ): Promise<T> {
    await this.assertWritable();
    const receiptId = rowId(this.owner, mutationId);
    const receipt = await this.row("mutation_receipts", receiptId);
    if (receipt) {
      if (
        (receipt as unknown as { request_hash: string }).request_hash !== hash
      )
        throw new AppError(
          "MUTATION_REUSED",
          "Mutation ID was reused for different content.",
          409,
        );
      return JSON.parse(receipt.payload) as T;
    }
    const headId = rowId(this.owner);
    try {
      await this.tables.createRow({
        databaseId: this.database,
        tableId: "sync_heads",
        rowId: headId,
        data: { owner: this.owner, sequence: 0 },
        permissions: [Permission.read(Role.user(this.owner))],
      });
    } catch (e) {
      if (!isConflict(e)) throw e;
    }
    for (let attempt = 0; attempt < 3; attempt++) {
      const transaction = await this.tables.createTransaction({ ttl: 60 });
      const transactionId = transaction.$id;
      try {
        // Guard first: every canonical writer stages this row before reading entity versions.
        await this.tables.incrementRowColumn({
          databaseId: this.database,
          tableId: "sync_heads",
          rowId: headId,
          column: "sequence",
          value: 1,
          transactionId,
        });
        const head = await this.row("sync_heads", headId, transactionId);
        const sequence = Number(
          (head as unknown as { sequence: number }).sequence,
        );
        const changes: Change[] = [];
        const get = async <D>(kind: Kind, id: string) => {
          const r = await this.row(
            kind,
            rowId(this.owner, kind, id),
            transactionId,
          );
          return r ? decode<D>(r) : null;
        };
        const put = async <D>(
          kind: Kind,
          id: string,
          data: D,
          expectedVersion?: number,
          deleted = false,
        ) => {
          const current = await get<D>(kind, id);
          if (
            expectedVersion !== undefined &&
            expectedVersion !== (current?.version ?? 0)
          )
            throw new AppError(
              "VERSION_CONFLICT",
              "This record changed. Refresh and review both versions.",
              409,
            );
          const record = {
            id,
            version: (current?.version ?? 0) + 1,
            updatedAt: new Date().toISOString(),
            deleted,
            data,
          };
          const payload = JSON.stringify(data);
          if (Buffer.byteLength(payload) > 90_000)
            throw new AppError(
              "PAYLOAD_TOO_LARGE",
              "Record exceeds the supported size.",
              413,
            );
          const indexed =
            kind === "jobs"
              ? {
                  state: (data as any).status,
                  due_at: (data as any).dueAt,
                  lease_until: (data as any).leaseUntil,
                }
              : kind === "connections"
                ? { provider_reference: (data as any)?.itemId ?? null }
                : {};
          await this.tables.upsertRow({
            databaseId: this.database,
            tableId: kind,
            rowId: rowId(this.owner, kind, id),
            transactionId,
            data: {
              owner: this.owner,
              entity_id: id,
              version: record.version,
              updated_at: record.updatedAt,
              deleted,
              payload,
              ...indexed,
            },
            permissions: ["import_inputs", "receipts"].includes(kind)
              ? []
              : [Permission.read(Role.user(this.owner))],
          });
          changes.push({ kind, record: journalRecord(kind, record) });
          return record;
        };
        if (!this.allowAfterDeletion) {
          const privacy = await get<{ type: string }>(
            "privacy_jobs",
            "current",
          );
          if (privacy && !privacy.deleted && privacy.data.type === "delete")
            throw new AppError(
              "ACCOUNT_DELETING",
              "New work is stopped while this account is being deleted.",
              410,
            );
        }
        const result = await operation({
          get,
          list: <D>(kind: Kind) => this.all<D>(kind, transactionId),
          put,
          remove: async (kind, id, version) => {
            await put(kind, id, null, version, true);
          },
        });
        if (
          changes.length > 50 ||
          Buffer.byteLength(JSON.stringify(changes)) > 90_000
        )
          throw new AppError(
            "BATCH_TOO_LARGE",
            "Split this mutation into smaller changes.",
            413,
          );
        if (changes.length === 0) {
          // Keep the physical conflict guard, but do not advance the logical
          // change sequence for skipped claims or other no-op receipts.
          await this.tables.decrementRowColumn({
            databaseId: this.database,
            tableId: "sync_heads",
            rowId: headId,
            column: "sequence",
            value: 1,
            transactionId,
          });
        }
        await this.tables.createRow({
          databaseId: this.database,
          tableId: "mutation_receipts",
          rowId: receiptId,
          transactionId,
          data: {
            owner: this.owner,
            request_hash: hash,
            payload: JSON.stringify(result),
          },
          permissions: [],
        });
        if (changes.length)
          await this.tables.createRow({
            databaseId: this.database,
            tableId: "sync_events",
            rowId: rowId(this.owner, String(sequence)),
            transactionId,
            data: {
              owner: this.owner,
              sequence,
              payload: JSON.stringify(changes),
            },
            permissions: [Permission.read(Role.user(this.owner))],
          });
        await this.tables.updateTransaction({ transactionId, commit: true });
        return result;
      } catch (e) {
        await this.tables
          .updateTransaction({ transactionId, rollback: true })
          .catch(() => undefined);
        if (isConflict(e)) {
          const previous = await this.row("mutation_receipts", receiptId);
          if (previous) {
            if (
              (previous as unknown as { request_hash: string }).request_hash !==
              hash
            )
              throw new AppError(
                "MUTATION_REUSED",
                "Mutation ID was reused.",
                409,
              );
            return JSON.parse(previous.payload) as T;
          }
          if (!(e instanceof AppError) && attempt < 2) continue;
        }
        throw e;
      }
    }
    throw new AppError(
      "BUSY",
      "Another change is being processed. Retry shortly.",
      409,
    );
  }
}

/** Operational records are never granted client permissions, including encrypted provider credentials. */
export async function privatePut(
  store: AppwriteStore,
  table: "provider_credentials" | "webhook_receipts",
  id: string,
  data: unknown,
) {
  await store.assertWritable(false);
  const payload = JSON.stringify(data);
  if (Buffer.byteLength(payload) > 90_000)
    throw new AppError(
      "PAYLOAD_TOO_LARGE",
      "Provider record exceeds supported size.",
      413,
    );
  return store.tables.upsertRow({
    databaseId: store.database,
    tableId: table,
    rowId: rowId(store.owner, table, id),
    data: {
      owner: store.owner,
      entity_id: id,
      version: 1,
      updated_at: new Date().toISOString(),
      deleted: false,
      payload,
    },
    permissions: [],
  });
}
export async function privateGet<T>(
  store: AppwriteStore,
  table: "provider_credentials" | "webhook_receipts",
  id: string,
): Promise<T | null> {
  try {
    const row = await store.tables.getRow({
      databaseId: store.database,
      tableId: table,
      rowId: rowId(store.owner, table, id),
    });
    if (row.owner !== store.owner)
      throw new AppError("NOT_FOUND", "Record not found.", 404);
    return JSON.parse(String(row.payload)) as T;
  } catch (e) {
    if (isMissing(e)) return null;
    throw e;
  }
}
