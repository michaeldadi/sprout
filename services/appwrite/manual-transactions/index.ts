import { createHash } from 'node:crypto';

const ID = /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,35}$/;
const CURRENCIES = new Set(Intl.supportedValuesOf('currency'));
const FIELDS = ['amountMinor', 'currency', 'type', 'category', 'description', 'merchant', 'transactionDate'];

type StorageFields = {
  amount_minor: number;
  currency: string;
  type: 'expense' | 'income' | 'transfer';
  category: string;
  description: string | null;
  merchant: string | null;
  transaction_date: string;
};
type Row = StorageFields & {
  $id: string;
  owner_id: string;
  source: 'manual';
  source_id: string;
  version: number;
  modified_at: string;
  deleted_at: string | null;
  last_mutation_id: string;
  last_mutation_hash: string;
};
type FunctionRequest = { method: string; headers: Record<string, string | undefined>; bodyJson: unknown };
type FunctionResponse = { json: (body: unknown, status?: number) => unknown };
type FunctionContext = { req: FunctionRequest; res: FunctionResponse };
type Environment = Record<string, string | undefined>;

class ServiceError extends Error {
  constructor(public readonly status: number, public readonly code: string) {
    super(code);
  }
}

function object(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function exactKeys(value: unknown, allowed: readonly string[]): asserts value is Record<string, unknown> {
  if (!object(value) || Object.keys(value).some((key) => !allowed.includes(key))) {
    throw new ServiceError(400, 'invalid_request');
  }
}

function id(value: unknown): string {
  if (typeof value !== 'string' || !ID.test(value)) throw new ServiceError(400, 'invalid_id');
  return value;
}

function date(value: unknown): string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new ServiceError(400, 'invalid_date');
  }
  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (!Number.isFinite(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== value) {
    throw new ServiceError(400, 'invalid_date');
  }
  return value;
}

function normalizeFields(input: unknown, partial = false): Partial<StorageFields> {
  exactKeys(input, FIELDS);
  if (partial && Object.keys(input).length === 0) throw new ServiceError(400, 'empty_changes');
  if (!partial && ['amountMinor', 'currency', 'type', 'category', 'transactionDate'].some((key) => input[key] === undefined)) {
    throw new ServiceError(400, 'missing_fields');
  }
  const result: Partial<StorageFields> = {};
  if ('amountMinor' in input) {
    if (!Number.isSafeInteger(input.amountMinor) || input.amountMinor === 0) {
      throw new ServiceError(400, 'invalid_amount');
    }
    result.amount_minor = input.amountMinor as number;
  }
  if ('currency' in input) {
    if (typeof input.currency !== 'string' || !CURRENCIES.has(input.currency)) {
      throw new ServiceError(400, 'invalid_currency');
    }
    result.currency = input.currency;
  }
  if ('type' in input) {
    if (typeof input.type !== 'string' || !['expense', 'income', 'transfer'].includes(input.type)) {
      throw new ServiceError(400, 'invalid_type');
    }
    result.type = input.type as StorageFields['type'];
  }
  if ('category' in input) {
    if (typeof input.category !== 'string' || !input.category.trim() || input.category.trim().length > 64) {
      throw new ServiceError(400, 'invalid_category');
    }
    result.category = input.category.trim();
  }
  for (const [field, max] of [['description', 512], ['merchant', 128]] as const) {
    if (field in input) {
      if (input[field] !== null && (typeof input[field] !== 'string' || input[field].length > max)) {
        throw new ServiceError(400, `invalid_${field}`);
      }
      result[field] = typeof input[field] === 'string' ? input[field].trim() || null : null;
    }
  }
  if ('transactionDate' in input) result.transaction_date = date(input.transactionDate);
  return result;
}

function validateSign(fields: Pick<StorageFields, 'amount_minor' | 'type'>) {
  if (fields.type === 'expense' && fields.amount_minor >= 0) throw new ServiceError(400, 'invalid_sign');
  if (fields.type === 'income' && fields.amount_minor <= 0) throw new ServiceError(400, 'invalid_sign');
}

function digest(value: unknown): string {
  return createHash('sha256').update(JSON.stringify(value)).digest('hex');
}

function publicRow(row: Row) {
  return {
    id: row.$id,
    amountMinor: row.amount_minor,
    currency: row.currency,
    type: row.type,
    category: row.category,
    description: row.description ?? null,
    merchant: row.merchant ?? null,
    transactionDate: row.transaction_date,
    source: row.source,
    sourceId: row.source_id,
    version: row.version,
    modifiedAt: row.modified_at,
    deletedAt: row.deleted_at ?? null,
  };
}

function query(method: string, attribute: string | null, values: unknown[] = []): string {
  return JSON.stringify({ method, ...(attribute ? { attribute } : {}), ...(values.length ? { values } : {}) });
}

export function createHandler({ fetchImpl = fetch, env = process.env, now = () => new Date() }: {
  fetchImpl?: typeof fetch;
  env?: Environment;
  now?: () => Date;
} = {}) {
  return async ({ req, res }: FunctionContext) => {
    const reply = (status: number, body: unknown) => res.json(body, status);
    try {
      if (req.method !== 'POST') throw new ServiceError(405, 'method_not_allowed');
      const endpoint = env.APPWRITE_FUNCTION_API_ENDPOINT;
      const project = env.APPWRITE_FUNCTION_PROJECT_ID;
      const database = env.SPROUT_DATABASE_ID;
      const table = env.SPROUT_TABLE_ID;
      if (!endpoint?.startsWith('https://') || !project || !database || !table) {
        throw new ServiceError(503, 'service_unconfigured');
      }
      const jwt = req.headers?.['x-appwrite-user-jwt'];
      const apiKey = req.headers?.['x-appwrite-key'];
      if (!jwt || !apiKey) throw new ServiceError(401, 'unauthorized');

      const api = async <T>(method: string, path: string, body?: unknown,
        auth: 'key' | 'jwt' = 'key', params?: Array<[string, string]>): Promise<T> => {
        const url = new URL(`${endpoint.replace(/\/$/, '')}${path}`);
        for (const [key, value] of params || []) url.searchParams.append(key, value);
        const response = await fetchImpl(url, {
          method,
          headers: {
            'Content-Type': 'application/json',
            'X-Appwrite-Project': project,
            [auth === 'jwt' ? 'X-Appwrite-JWT' : 'X-Appwrite-Key']: auth === 'jwt' ? jwt : apiKey,
          },
          ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        });
        let payload = null;
        try { payload = await response.json(); } catch { /* empty response */ }
        if (!response.ok) throw new ServiceError(response.status, payload?.type || 'appwrite_error');
        return payload as T;
      };

      const account = await api<{ $id: string }>('GET', '/account', undefined, 'jwt');
      const owner = account?.$id;
      if (typeof owner !== 'string' || !ID.test(owner) ||
          (req.headers['x-appwrite-user-id'] && req.headers['x-appwrite-user-id'] !== owner)) {
        throw new ServiceError(401, 'unauthorized');
      }
      const body = req.bodyJson;
      if (!object(body) || typeof body.action !== 'string') throw new ServiceError(400, 'invalid_request');
      const rowPath = `/tablesdb/${encodeURIComponent(database)}/tables/${encodeURIComponent(table)}/rows`;
      const get = async (rowId: string): Promise<Row | null> => {
        try { return await api<Row>('GET', `${rowPath}/${encodeURIComponent(rowId)}`); }
        catch (error) { if (error instanceof ServiceError && error.status === 404) return null; throw error; }
      };
      const owned = (row: Row | null): Row => {
        if (!row || row.owner_id !== owner) throw new ServiceError(404, 'not_found');
        return row;
      };

      if (body.action === 'get') {
        exactKeys(body, ['action', 'id']);
        return reply(200, publicRow(owned(await get(id(body.id)))));
      }

      if (body.action === 'list') {
        exactKeys(body, ['action', 'cursor', 'limit']);
        const limit = body.limit === undefined ? 50 : body.limit;
        if (typeof limit !== 'number' || !Number.isInteger(limit) || limit < 1 || limit > 100) throw new ServiceError(400, 'invalid_limit');
        const queries = [
          query('equal', 'owner_id', [owner]),
          query('orderAsc', 'modified_at'),
          query('orderAsc', '$id'),
          query('limit', null, [limit + 1]),
        ];
        if (body.cursor !== undefined) queries.push(query('cursorAfter', null, [id(body.cursor)]));
        const result = await api<{ rows: Row[] }>('GET', rowPath, undefined, 'key', queries.map((value): [string, string] => ['queries[]', value]));
        const rows = result?.rows;
        if (!Array.isArray(rows) || rows.some((row) => row.owner_id !== owner)) {
          throw new ServiceError(503, 'invalid_upstream_response');
        }
        const page = rows.slice(0, limit);
        return reply(200, {
          rows: page.map(publicRow),
          nextCursor: rows.length > limit ? page.at(-1)!.$id : null,
        });
      }

      if (body.action === 'create') {
        exactKeys(body, ['action', 'id', 'mutationId', ...FIELDS]);
        const rowId = id(body.id);
        const mutationId = id(body.mutationId);
        const fields = normalizeFields(Object.fromEntries(FIELDS.filter((key) => key in body).map((key) => [key, body[key]])));
        validateSign({ amount_minor: fields.amount_minor!, type: fields.type! });
        const hash = digest({ action: 'create', owner, rowId, fields });
        const existing = await get(rowId);
        if (existing) {
          if (existing.owner_id !== owner) throw new ServiceError(404, 'not_found');
          if (existing.last_mutation_id === mutationId && existing.last_mutation_hash === hash) {
            return reply(200, publicRow(existing));
          }
          throw new ServiceError(409, 'id_conflict');
        }
        const record = {
          owner_id: owner, ...fields, source: 'manual', source_id: rowId, version: 1,
          modified_at: now().toISOString(), deleted_at: null,
          last_mutation_id: mutationId, last_mutation_hash: hash,
        };
        try {
          const created = await api<Row>('POST', rowPath, {
            rowId, data: record, permissions: [`read("user:${owner}")`],
          });
          return reply(201, publicRow(owned(created)));
        } catch (error) {
          if (!(error instanceof ServiceError) || error.status !== 409) throw error;
          const after = await get(rowId);
          if (after?.owner_id === owner && after.last_mutation_id === mutationId && after.last_mutation_hash === hash) {
            return reply(200, publicRow(after));
          }
          throw new ServiceError(409, 'id_conflict');
        }
      }

      if (body.action === 'update' || body.action === 'delete') {
        exactKeys(body, body.action === 'update'
          ? ['action', 'id', 'mutationId', 'expectedVersion', 'changes']
          : ['action', 'id', 'mutationId', 'expectedVersion']);
        const rowId = id(body.id);
        const mutationId = id(body.mutationId);
        if (typeof body.expectedVersion !== 'number' || !Number.isInteger(body.expectedVersion) || body.expectedVersion < 1 || body.expectedVersion >= 2147483647) {
          throw new ServiceError(400, 'invalid_version');
        }
        const changes = body.action === 'update' ? normalizeFields(body.changes, true) : {};
        const hash = digest({ action: body.action, owner, rowId, expectedVersion: body.expectedVersion, changes });
        const current = owned(await get(rowId));
        if (current.last_mutation_id === mutationId) {
          if (current.last_mutation_hash === hash) return reply(200, publicRow(current));
          throw new ServiceError(409, 'mutation_conflict');
        }
        if (current.deleted_at || current.version !== body.expectedVersion) throw new ServiceError(409, 'version_conflict');
        if (body.action === 'update') validateSign({
          amount_minor: changes.amount_minor ?? current.amount_minor,
          type: changes.type ?? current.type,
        });

        const transaction = await api<{ $id: string }>('POST', '/tablesdb/transactions', {});
        const txId = transaction?.$id;
        if (typeof txId !== 'string') throw new ServiceError(503, 'invalid_upstream_response');
        try {
          await api('PATCH', `${rowPath}/${encodeURIComponent(rowId)}/version/increment`, {
            value: 1, max: body.expectedVersion + 1, transactionId: txId,
          });
          await api('PATCH', `${rowPath}/${encodeURIComponent(rowId)}`, {
            data: {
              ...changes,
              ...(body.action === 'delete' ? { deleted_at: now().toISOString() } : {}),
              modified_at: now().toISOString(),
              last_mutation_id: mutationId,
              last_mutation_hash: hash,
            },
            transactionId: txId,
          });
          await api('PATCH', `/tablesdb/transactions/${encodeURIComponent(txId)}`, { commit: true });
        } catch (error) {
          try { await api('PATCH', `/tablesdb/transactions/${encodeURIComponent(txId)}`, { rollback: true }); } catch { /* may already be committed */ }
          if (error instanceof ServiceError && error.status === 409) throw new ServiceError(409, 'version_conflict');
          throw error;
        }
        return reply(200, publicRow(owned(await get(rowId))));
      }
      throw new ServiceError(400, 'invalid_action');
    } catch (error) {
      if (error instanceof ServiceError) {
        const status = [400, 401, 404, 405, 409, 503].includes(error.status) ? error.status : 503;
        return reply(status, { error: error.code });
      }
      return reply(503, { error: 'service_unavailable' });
    }
  };
}

export default createHandler();
