import { Client, TablesDB, ID } from 'node-appwrite';
export type FormKind = 'waitlist' | 'contact';
type RecordData = Record<string, string | boolean>;
export type Writer = (
  kind: FormKind,
  id: string,
  data: RecordData,
  request: Request
) => Promise<void>;
const placements = ['hero', 'final-cta', 'footer', 'waitlist-page'];
const categories = ['support', 'press', 'careers', 'privacy', 'deletion'];
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export const CONSENT_VERSION = 'launch-updates-2026-11-09';
function json(status: number, body: unknown) {
  return Response.json(body, {
    status,
    headers: {
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}
export function validate(kind: FormKind, input: Record<string, unknown>) {
  const fields: Record<string, string> = {};
  const email =
    typeof input.email === 'string' ? input.email.trim().toLowerCase() : '';
  if (!email || email.length > 254 || !/^\S+@[^\s@]+\.[^\s@]+$/.test(email))
    fields.email = 'Enter a valid email address.';
  if (input.website !== undefined && typeof input.website !== 'string')
    fields.website = 'Invalid form submission.';
  const data: RecordData = { email };
  let id = ID.unique();
  if (kind === 'waitlist') {
    if (!['ios', 'android', 'both'].includes(String(input.platform)))
      fields.platform = 'Choose your phone platform.';
    if (!placements.includes(String(input.placement)))
      fields.placement = 'Invalid signup location.';
    if (input.consent !== true)
      fields.consent = 'Please agree to receive Sprout launch updates.';
    Object.assign(data, {
      platform: input.platform,
      placement: input.placement,
      consent_version: CONSENT_VERSION,
      consented_at: new Date().toISOString(),
    });
  } else {
    if (
      typeof input.submissionId !== 'string' ||
      !uuid.test(input.submissionId)
    )
      fields.submissionId = 'Refresh this page and try again.';
    else id = input.submissionId.toLowerCase();
    if (
      input.name !== undefined &&
      (typeof input.name !== 'string' || input.name.trim().length > 100)
    )
      fields.name = 'Use a name of 100 characters or fewer.';
    if (!categories.includes(String(input.category)))
      fields.category = 'Choose an inquiry topic.';
    if (
      typeof input.message !== 'string' ||
      input.message.trim().length < 10 ||
      input.message.trim().length > 5000
    )
      fields.message = 'Write a message between 10 and 5000 characters.';
    Object.assign(data, {
      name: typeof input.name === 'string' ? input.name.trim() : '',
      category: input.category,
      message: typeof input.message === 'string' ? input.message.trim() : '',
      status: 'new',
    });
  }
  return { fields, data, id };
}
async function readBody(request: Request) {
  if (Number(request.headers.get('Content-Length') || 0) > 8192)
    throw new RangeError();
  const reader = request.body?.getReader();
  if (!reader) throw new SyntaxError();
  let size = 0;
  const chunks: Uint8Array[] = [];
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 8192) {
        await reader.cancel();
        throw new RangeError();
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return JSON.parse(new TextDecoder().decode(bytes)) as unknown;
}
function allowedOrigin(request: Request) {
  const configured =
    process.env.SPROUT_SITE_ORIGIN || process.env.VITE_SITE_ORIGIN;
  const origin = request.headers.get('Origin');
  if (!origin || request.headers.get('Sec-Fetch-Site') === 'cross-site')
    return false;
  if (configured) return origin === new URL(configured).origin;
  const url = new URL(request.url);
  return (
    ['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname) &&
    origin === url.origin
  );
}
export const writeRow: Writer = async (kind, id, data, request) => {
  const hosted = !!process.env.APPWRITE_SITE_PROJECT_ID;
  const endpoint = hosted
    ? process.env.APPWRITE_SITE_API_ENDPOINT
    : process.env.SPROUT_APPWRITE_ENDPOINT;
  const project = hosted
    ? process.env.APPWRITE_SITE_PROJECT_ID
    : process.env.SPROUT_APPWRITE_PROJECT_ID;
  const key = hosted
    ? request.headers.get('x-appwrite-key')
    : process.env.SPROUT_APPWRITE_API_KEY;
  const database = process.env.SPROUT_MARKETING_DATABASE_ID;
  const table =
    kind === 'waitlist'
      ? process.env.SPROUT_WAITLIST_TABLE_ID
      : process.env.SPROUT_INQUIRIES_TABLE_ID;
  if (!endpoint || !project || !key || !database || !table)
    throw new Error('form_configuration_missing');
  const client = new Client()
    .setEndpoint(endpoint)
    .setProject(project)
    .setKey(key);
  await new TablesDB(client).createRow({
    databaseId: database,
    tableId: table,
    rowId: id,
    data,
    permissions: [],
  });
};
export function createFormHandler(kind: FormKind, write: Writer = writeRow) {
  return async (request: Request) => {
    if (request.method !== 'POST')
      return new Response(null, {
        status: 405,
        headers: { Allow: 'POST', 'Cache-Control': 'no-store' },
      });
    if (!allowedOrigin(request))
      return json(403, {
        message: 'Please submit this form from the Sprout website.',
      });
    if (
      request.headers
        .get('Content-Type')
        ?.split(';')[0]
        .trim()
        .toLowerCase() !== 'application/json'
    )
      return json(415, { message: 'Submit the form as JSON.' });
    let input: unknown;
    try {
      input = await readBody(request);
    } catch (error) {
      return json(error instanceof RangeError ? 413 : 400, {
        message:
          error instanceof RangeError
            ? 'Your request is too large.'
            : 'Please check the form and try again.',
      });
    }
    if (!input || typeof input !== 'object' || Array.isArray(input))
      return json(400, { message: 'Please check the form and try again.' });
    const body = input as Record<string, unknown>;
    if (typeof body.website === 'string' && body.website.trim())
      return json(200, { ok: true });
    const { fields, data, id } = validate(kind, body);
    if (Object.keys(fields).length)
      return json(400, {
        message: 'Please check the highlighted fields.',
        fields,
      });
    try {
      await write(kind, id, data, request);
      return json(200, { ok: true });
    } catch (error) {
      // Appwrite createRow uses 409 for an existing row ID or the unique email index.
      // Both cases are an accepted replay; no record or membership detail is returned.
      if (
        error &&
        typeof error === 'object' &&
        'code' in error &&
        error.code === 409
      )
        return json(200, { ok: true });
      console.error('marketing_submission_failed', {
        kind,
        code:
          error && typeof error === 'object' && 'code' in error
            ? error.code
            : 'unavailable',
      });
      return json(503, {
        message: 'We could not save your request right now. Please try again.',
      });
    }
  };
}
