import assert from 'node:assert/strict';
import test from 'node:test';
import { createHandler } from './index.js';

type Json = Record<string, unknown>;
type SavedRow = Json & { $id: string; $permissions: string[]; owner_id: string; version: number; modified_at: string };

class FakeAppwrite {
  readonly rows = new Map<string, SavedRow>();
  readonly transactions = new Map<string, Array<{ kind: string; rowId: string; body: Json }>>();
  loseCreateResponse = false;
  loseCommitResponse = false;
  private nextTransaction = 1;

  fetch = async (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    const url = new URL(String(input));
    const method = init?.method || 'GET';
    const headers = new Headers(init?.headers);
    const body = init?.body ? JSON.parse(String(init.body)) as Json : {};
    const send = (status: number, data: unknown) => Response.json(data, { status });

    if (url.pathname === '/v1/account') {
      const jwt = headers.get('X-Appwrite-JWT');
      return jwt === 'jwt-a' || jwt === 'jwt-b'
        ? send(200, { $id: jwt === 'jwt-a' ? 'user-a' : 'user-b' })
        : send(401, { type: 'user_unauthorized' });
    }
    if (headers.get('X-Appwrite-Key') !== 'ephemeral') return send(401, { type: 'key_invalid' });

    if (url.pathname === '/v1/tablesdb/transactions') {
      if (method !== 'POST') return send(405, {});
      const id = `tx-${this.nextTransaction++}`;
      this.transactions.set(id, []);
      return send(201, { $id: id });
    }
    const txMatch = url.pathname.match(/^\/v1\/tablesdb\/transactions\/([^/]+)$/);
    if (txMatch && method === 'PATCH') {
      const txId = txMatch[1];
      const operations = this.transactions.get(txId);
      if (!operations) return send(404, { type: 'transaction_not_found' });
      if (body.rollback) { this.transactions.delete(txId); return send(200, {}); }
      if (!body.commit) return send(400, {});
      const pending = new Map(this.rows);
      for (const operation of operations) {
        const row = pending.get(operation.rowId);
        if (!row) return send(404, { type: 'row_not_found' });
        if (operation.kind === 'increment') {
          const next = row.version + Number(operation.body.value);
          if (next > Number(operation.body.max)) return send(409, { type: 'transaction_conflict' });
          pending.set(operation.rowId, { ...row, version: next });
        } else {
          pending.set(operation.rowId, { ...row, ...(operation.body.data as Json) });
        }
      }
      this.rows.clear();
      for (const [key, value] of pending) this.rows.set(key, value);
      this.transactions.delete(txId);
      if (this.loseCommitResponse) {
        this.loseCommitResponse = false;
        throw new Error('simulated lost response');
      }
      return send(200, { status: 'committed' });
    }

    const base = '/v1/tablesdb/db/tables/manual_transactions_v1/rows';
    if (url.pathname === base && method === 'GET') {
      const queries = url.searchParams.getAll('queries[]').map((value) => JSON.parse(value) as { method: string; attribute?: string; values?: unknown[] });
      const owner = queries.find((query) => query.method === 'equal' && query.attribute === 'owner_id')?.values?.[0];
      const limit = Number(queries.find((query) => query.method === 'limit')?.values?.[0]);
      const cursor = queries.find((query) => query.method === 'cursorAfter')?.values?.[0];
      const sorted = [...this.rows.values()].filter((row) => row.owner_id === owner)
        .sort((a, b) => a.modified_at.localeCompare(b.modified_at) || a.$id.localeCompare(b.$id));
      const start = cursor ? sorted.findIndex((row) => row.$id === cursor) + 1 : 0;
      return send(200, { rows: sorted.slice(start, start + limit) });
    }
    if (url.pathname === base && method === 'POST') {
      const rowId = String(body.rowId);
      if (this.rows.has(rowId)) return send(409, { type: 'row_already_exists' });
      const data = body.data as Json;
      this.rows.set(rowId, { ...data, $id: rowId, $permissions: body.permissions } as SavedRow);
      if (this.loseCreateResponse) {
        this.loseCreateResponse = false;
        throw new Error('simulated lost response');
      }
      return send(201, this.rows.get(rowId));
    }
    const increment = url.pathname.match(/\/rows\/([^/]+)\/version\/increment$/);
    if (increment && method === 'PATCH') {
      this.transactions.get(String(body.transactionId))?.push({ kind: 'increment', rowId: increment[1], body });
      return send(200, {});
    }
    const rowMatch = url.pathname.match(/\/rows\/([^/]+)$/);
    if (rowMatch) {
      const rowId = rowMatch[1];
      if (method === 'GET') {
        const row = this.rows.get(rowId);
        return row ? send(200, row) : send(404, { type: 'row_not_found' });
      }
      if (method === 'PATCH') {
        this.transactions.get(String(body.transactionId))?.push({ kind: 'update', rowId, body });
        return send(200, {});
      }
    }
    return send(404, { type: 'route_not_found' });
  };
}

const create = {
  action: 'create', id: 'txn-a', mutationId: 'mutation-create', amountMinor: -1234,
  currency: 'USD', type: 'expense', category: 'Food', transactionDate: '2026-11-09',
};

function setup() {
  const appwrite = new FakeAppwrite();
  const handler = createHandler({
    fetchImpl: appwrite.fetch,
    env: {
      APPWRITE_FUNCTION_API_ENDPOINT: 'https://staging.example/v1',
      APPWRITE_FUNCTION_PROJECT_ID: 'project',
      SPROUT_DATABASE_ID: 'db',
      SPROUT_TABLE_ID: 'manual_transactions_v1',
    },
    now: () => new Date('2026-11-09T10:00:00.000Z'),
  });
  const call = async (body: Json, jwt = 'jwt-a') => await handler({
    req: {
      method: 'POST', bodyJson: body,
      headers: { 'x-appwrite-user-jwt': jwt, 'x-appwrite-key': 'ephemeral' },
    },
    res: { json: (value, status) => ({ status, body: value }) },
  }) as { status: number; body: Json };
  return { appwrite, call };
}

test('verified identity owns every read and write', async () => {
  const { appwrite, call } = setup();
  assert.equal((await call(create)).status, 201);
  assert.equal(appwrite.rows.get('txn-a')?.owner_id, 'user-a');
  assert.deepEqual(appwrite.rows.get('txn-a')?.$permissions, ['read("user:user-a")']);
  assert.equal((await call({ action: 'get', id: 'txn-a' }, 'jwt-b')).status, 404);
  assert.deepEqual((await call({ action: 'list' }, 'jwt-b')).body.rows, []);
  assert.equal((await call({ action: 'delete', id: 'txn-a', mutationId: 'delete-b', expectedVersion: 1 }, 'jwt-b')).status, 404);
  assert.equal((await call({ ...create, owner_id: 'user-b' })).status, 400);
  assert.equal((await call(create, 'forged-jwt')).status, 401);
});

test('minor-unit money and calendar dates are validated', async () => {
  const { call } = setup();
  assert.equal((await call({ ...create, amountMinor: -12.34 })).body.error, 'invalid_amount');
  assert.equal((await call({ ...create, type: 'income' })).body.error, 'invalid_sign');
  assert.equal((await call({ ...create, currency: 'ZZZ' })).body.error, 'invalid_currency');
  assert.equal((await call({ ...create, transactionDate: '2026-02-30' })).body.error, 'invalid_date');
});

test('lost responses are safe to retry and deletion remains a tombstone', async () => {
  const { appwrite, call } = setup();
  appwrite.loseCreateResponse = true;
  assert.equal((await call(create)).status, 503);
  assert.equal((await call(create)).status, 200);
  const update = { action: 'update', id: 'txn-a', mutationId: 'mutation-update', expectedVersion: 1,
    changes: { amountMinor: -1300 } };
  appwrite.loseCommitResponse = true;
  assert.equal((await call(update)).status, 503);
  assert.equal((await call(update)).status, 200);
  assert.equal((await call(update)).body.version, 2);
  assert.equal((await call({ ...update, mutationId: 'different' })).status, 409);
  const deletion = { action: 'delete', id: 'txn-a', mutationId: 'mutation-delete', expectedVersion: 2 };
  assert.equal((await call(deletion)).status, 200);
  assert.equal((await call(deletion)).body.version, 3);
  assert.ok((await call(deletion)).body.deletedAt);
  assert.equal((await call({ ...update, expectedVersion: 3 })).status, 409);
});

test('cursor pagination and concurrent edits retain one version winner', async () => {
  const { call } = setup();
  await call(create);
  await call({ ...create, id: 'txn-b', mutationId: 'mutation-b' });
  const first = await call({ action: 'list', limit: 1 });
  assert.equal((first.body.rows as unknown[]).length, 1);
  assert.equal(first.body.nextCursor, 'txn-a');
  const second = await call({ action: 'list', limit: 1, cursor: first.body.nextCursor });
  assert.equal((second.body.rows as Array<{ id: string }>)[0].id, 'txn-b');
  const results = await Promise.all([
    call({ action: 'update', id: 'txn-a', mutationId: 'edit-1', expectedVersion: 1, changes: { amountMinor: -1400 } }),
    call({ action: 'update', id: 'txn-a', mutationId: 'edit-2', expectedVersion: 1, changes: { amountMinor: -1500 } }),
  ]);
  assert.deepEqual(results.map((result) => result.status).sort(), [200, 409]);
  assert.equal((await call({ action: 'get', id: 'txn-a' })).body.version, 2);
});
