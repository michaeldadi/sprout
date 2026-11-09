import { describe, expect, it } from 'vitest';
import { canIndexRequest } from '../src/server/indexing';

describe('crawler policy', () => {
  const origin = 'https://getsprout.appwrite.network';
  it('permits only the configured public production host', () => {
    expect(canIndexRequest(new Request(`${origin}/about`), origin, true)).toBe(
      true
    );
    expect(
      canIndexRequest(
        new Request('https://branch-preview.appwrite.network/about'),
        origin,
        true
      )
    ).toBe(false);
  });
  it('keeps staging and missing configuration non-indexable', () => {
    expect(canIndexRequest(new Request(`${origin}/`), origin, false)).toBe(
      false
    );
    expect(canIndexRequest(new Request(`${origin}/`), '', true)).toBe(false);
  });
});
