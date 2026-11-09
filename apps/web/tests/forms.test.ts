import { describe, it, expect, vi, afterEach } from 'vitest';
import { createFormHandler, validate } from '../src/server/forms';
import type { Writer } from '../src/server/forms';
const base = {
  email: '  Maya@example.test ',
  platform: 'ios',
  placement: 'hero',
  consent: true,
  website: '',
};
function request(body: unknown = base, init: RequestInit = {}) {
  return new Request('http://127.0.0.1:3000/api/waitlist', {
    method: 'POST',
    headers: {
      Origin: 'http://127.0.0.1:3000',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
    ...init,
  });
}
afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllEnvs();
});
describe('marketing form boundary', () => {
  it('normalizes and records an explicit versioned consent after persistence', async () => {
    const write = vi.fn<Writer>().mockResolvedValue();
    const result = await createFormHandler('waitlist', write)(request());
    expect(result.status).toBe(200);
    expect(write).toHaveBeenCalledOnce();
    expect(write.mock.calls[0][2]).toMatchObject({
      email: 'maya@example.test',
      consent_version: 'launch-updates-2026-11-09',
      platform: 'ios',
    });
    expect(await result.json()).toEqual({ ok: true });
    expect(result.headers.get('Cache-Control')).toBe('no-store');
  });
  it.each([
    { ...base, consent: false },
    { ...base, email: 'not-an-email' },
    { ...base, platform: 'desktop' },
    { ...base, placement: 'unknown' },
  ])('rejects invalid data without writing', async (body) => {
    const write = vi.fn<Writer>();
    const result = await createFormHandler('waitlist', write)(request(body));
    expect(result.status).toBe(400);
    expect(write).not.toHaveBeenCalled();
  });
  it('accepts a database uniqueness conflict without disclosing membership', async () => {
    const write = vi.fn<Writer>().mockRejectedValue({ code: 409 });
    expect(
      await (await createFormHandler('waitlist', write)(request())).json()
    ).toEqual({ ok: true });
  });
  it('does not claim success when storage fails or leak provider details', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const write = vi
      .fn<Writer>()
      .mockRejectedValue(new Error('sensitive-provider-detail'));
    const result = await createFormHandler('waitlist', write)(request());
    expect(result.status).toBe(503);
    expect(await result.text()).not.toContain('sensitive');
  });
  it('rejects a foreign origin, even with a same-origin host', async () => {
    const write = vi.fn<Writer>();
    const result = await createFormHandler(
      'waitlist',
      write
    )(
      request(base, {
        headers: {
          Origin: 'https://attacker.test',
          'Content-Type': 'application/json',
        },
      })
    );
    expect(result.status).toBe(403);
    expect(write).not.toHaveBeenCalled();
  });
  it('requires an explicit matching origin on hosted deployments', async () => {
    vi.stubEnv('SPROUT_SITE_ORIGIN', 'https://sprout.example');
    const result = await createFormHandler('waitlist', vi.fn())(request());
    expect(result.status).toBe(403);
  });
  it('rejects malformed JSON and non-object payloads', async () => {
    for (const body of ['{', '[]', 'null']) {
      expect(
        (await createFormHandler('waitlist', vi.fn())(request(base, { body })))
          .status
      ).toBe(400);
    }
  });
  it('enforces the body bound for declared and streamed bodies', async () => {
    const write = vi.fn<Writer>();
    for (const headers of [
      {
        Origin: 'http://127.0.0.1:3000',
        'Content-Type': 'application/json',
        'Content-Length': '9000',
      },
      { Origin: 'http://127.0.0.1:3000', 'Content-Type': 'application/json' },
    ] as Record<string, string>[]) {
      expect(
        (
          await createFormHandler(
            'waitlist',
            write
          )(request({ ...base, extra: 'x'.repeat(9000) }, { headers }))
        ).status
      ).toBe(413);
    }
    expect(write).not.toHaveBeenCalled();
  });
  it('rejects other methods and content types', async () => {
    const handler = createFormHandler('waitlist', vi.fn());
    expect(
      (await handler(new Request('http://127.0.0.1:3000/api/waitlist'))).status
    ).toBe(405);
    expect(
      (
        await handler(
          request(base, {
            headers: {
              Origin: 'http://127.0.0.1:3000',
              'Content-Type': 'text/plain',
            },
          })
        )
      ).status
    ).toBe(415);
  });
  it('silently discards honeypot submissions', async () => {
    const write = vi.fn<Writer>();
    expect(
      (
        await createFormHandler(
          'waitlist',
          write
        )(request({ ...base, website: 'https://spam.test' }))
      ).status
    ).toBe(200);
    expect(write).not.toHaveBeenCalled();
  });
  it('makes simultaneous duplicate creates safe using the database constraint', async () => {
    const emails = new Set<string>();
    const write: Writer = async (_kind, _id, data) => {
      if (emails.has(String(data.email))) throw { code: 409 };
      emails.add(String(data.email));
    };
    const handler = createFormHandler('waitlist', write);
    const results = await Promise.all(
      Array.from({ length: 4 }, () => handler(request()))
    );
    expect(results.every((r) => r.status === 200)).toBe(true);
    expect(emails.size).toBe(1);
  });
  it('uses the contact UUID for retry idempotency and trims text', async () => {
    const id = 'e8009433-3993-46e3-901d-357a0fb884ad';
    const input = {
      submissionId: id,
      name: ' Maya ',
      email: 'maya@example.test',
      category: 'deletion',
      message: ' Please delete my waitlist signup. ',
    };
    const write = vi.fn<Writer>().mockResolvedValue();
    expect(
      (await createFormHandler('contact', write)(request(input))).status
    ).toBe(200);
    expect(write.mock.calls[0][1]).toBe(id);
    expect(write.mock.calls[0][2]).toMatchObject({
      name: 'Maya',
      status: 'new',
      message: 'Please delete my waitlist signup.',
    });
  });
  it('checks all inquiry boundaries', () => {
    expect(
      Object.keys(
        validate('contact', {
          submissionId: 'bad',
          name: 'x'.repeat(101),
          email: 'x',
          category: 'bad',
          message: 'tiny',
        }).fields
      ).sort()
    ).toEqual(['category', 'email', 'message', 'name', 'submissionId']);
  });
});
