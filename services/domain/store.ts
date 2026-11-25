import {
  AppError,
  journalRecord,
  type Kind,
  type RecordValue,
  type SyncEvent,
} from "../contracts";
export interface ReadStore {
  get<T>(kind: Kind, id: string): Promise<RecordValue<T> | null>;
  list<T>(kind: Kind): Promise<RecordValue<T>[]>;
}
export interface WriteStore extends ReadStore {
  put<T>(
    kind: Kind,
    id: string,
    data: T,
    expectedVersion?: number,
  ): Promise<RecordValue<T>>;
  remove(kind: Kind, id: string, expectedVersion: number): Promise<void>;
}
export interface UserStore extends ReadStore {
  /** A private, owner-readable revision signal. Its payload is never application data. */
  readonly changeChannel?: string;
  mutate<T>(
    mutationId: string,
    requestHash: string,
    operation: (store: WriteStore) => Promise<T>,
  ): Promise<T>;
  changes(
    after: number,
    limit?: number,
    through?: number,
  ): Promise<SyncEvent[]>;
  revision(): Promise<number>;
}
/** Test implementation only. Production entrypoints require AppwriteStore. */
export class MemoryStore implements UserStore {
  private records = new Map<string, RecordValue<unknown>>();
  private receipts = new Map<string, { hash: string; result: unknown }>();
  private events: SyncEvent[] = [];
  private tail: Promise<unknown> = Promise.resolve();
  constructor(private now: () => string = () => new Date().toISOString()) {}
  async get<T>(kind: Kind, id: string) {
    const value = this.records.get(`${kind}/${id}`);
    return value ? (structuredClone(value) as RecordValue<T>) : null;
  }
  async list<T>(kind: Kind) {
    return [...this.records]
      .filter(([key, value]) => key.startsWith(`${kind}/`) && !value.deleted)
      .map(([, v]) => structuredClone(v) as RecordValue<T>);
  }
  async revision() {
    return this.events.length;
  }
  async changes(after: number, limit = 50, through = Number.MAX_SAFE_INTEGER) {
    return structuredClone(
      this.events
        .filter((e) => e.sequence > after && e.sequence <= through)
        .slice(0, limit),
    );
  }
  mutate<T>(
    mutationId: string,
    requestHash: string,
    operation: (store: WriteStore) => Promise<T>,
  ): Promise<T> {
    const execute = async () => {
      const receipt = this.receipts.get(mutationId);
      if (receipt) {
        if (receipt.hash !== requestHash)
          throw new AppError(
            "MUTATION_REUSED",
            "Mutation ID was already used for different content.",
            409,
          );
        return structuredClone(receipt.result) as T;
      }
      const original = structuredClone(this.records);
      const changes: SyncEvent["changes"] = [];
      const put = async <D>(
        kind: Kind,
        id: string,
        data: D,
        expectedVersion?: number,
      ) => {
        const existing = await this.get<D>(kind, id);
        if (
          expectedVersion !== undefined &&
          expectedVersion !== (existing?.version ?? 0)
        )
          throw new AppError(
            "VERSION_CONFLICT",
            "The record changed on another device. Refresh before retrying.",
            409,
          );
        const record = {
          id,
          version: (existing?.version ?? 0) + 1,
          updatedAt: this.now(),
          deleted: false,
          data,
        };
        this.records.set(`${kind}/${id}`, record);
        changes.push({ kind, record: journalRecord(kind, record) });
        return record;
      };
      try {
        const result = await operation({
          get: this.get.bind(this),
          list: this.list.bind(this),
          put,
          remove: async (kind, id, expected) => {
            const r = await put(kind, id, null, expected);
            r.deleted = true;
            this.records.set(`${kind}/${id}`, r);
          },
        });
        this.receipts.set(mutationId, {
          hash: requestHash,
          result: structuredClone(result),
        });
        if (changes.length)
          this.events.push({ sequence: this.events.length + 1, changes });
        return result;
      } catch (e) {
        this.records = original;
        throw e;
      }
    };
    const next = this.tail.then(execute, execute);
    this.tail = next.catch(() => undefined);
    return next;
  }
}
