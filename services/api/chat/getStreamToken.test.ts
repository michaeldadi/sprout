import assert from 'node:assert/strict';
import test from 'node:test';
import { StreamChat } from 'stream-chat';
import { handler } from './getStreamToken';

const originalGetInstance = StreamChat.getInstance;
const originalKey = process.env.STREAM_API_KEY;
const originalSecret = process.env.STREAM_API_SECRET;

test.afterEach(() => {
  (StreamChat as any).getInstance = originalGetInstance;
  if (originalKey === undefined) delete process.env.STREAM_API_KEY;
  else process.env.STREAM_API_KEY = originalKey;
  if (originalSecret === undefined) delete process.env.STREAM_API_SECRET;
  else process.env.STREAM_API_SECRET = originalSecret;
});

test('chat token is bound to the JWT subject and cannot join caller-selected channels', async () => {
  process.env.STREAM_API_KEY = 'test-key';
  process.env.STREAM_API_SECRET = 'test-secret';
  const calls: string[] = [];
  (StreamChat as any).getInstance = () => ({
    upsertUser: async (user: { id: string }) => { calls.push(`upsert:${user.id}`); },
    createToken: (id: string) => { calls.push(`token:${id}`); return 'signed-token'; },
    channel: () => { throw new Error('Caller must not control channel membership'); }
  });

  const result = await handler({
    requestContext: { authorizer: { jwt: { claims: { sub: 'real-user' } } } },
    headers: { 'x-user-id': 'other-user' },
    queryStringParameters: { channel_cids: 'messaging:private-channel' }
  } as any, {} as any, () => {});

  assert.ok(result && typeof result !== 'string');
  assert.equal(result.statusCode, 200);
  assert.deepEqual(calls, ['upsert:real-user', 'token:real-user']);
  assert.equal(JSON.parse(result.body).userId, 'real-user');
});

test('a spoofed user header cannot obtain a token', async () => {
  const result = await handler({
    requestContext: {},
    headers: { 'x-user-id': 'other-user' }
  } as any, {} as any, () => {});

  assert.ok(result && typeof result !== 'string');
  assert.equal(result.statusCode, 401);
});

test('chat token issuance fails closed when the Stream secret is absent', async () => {
  process.env.STREAM_API_KEY = 'test-key';
  delete process.env.STREAM_API_SECRET;
  const result = await handler({
    requestContext: { authorizer: { jwt: { claims: { sub: 'real-user' } } } }
  } as any, {} as any, () => {});

  assert.ok(result && typeof result !== 'string');
  assert.equal(result.statusCode, 503);
});
