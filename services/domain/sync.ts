import { createHash, createHmac, timingSafeEqual } from "node:crypto";
import { z } from "zod";
import { AppError, type Capabilities } from "../contracts";
import type { UserStore } from "./store";
import { workspace } from "./application";

const claims = z
  .object({
    v: z.literal(2),
    projectedAt: z.number().int().nonnegative().safe(),
    account: z.string().length(64),
    after: z.number().int().nonnegative().safe(),
    through: z.number().int().nonnegative().safe().nullable(),
    expires: z.number().int().positive().safe(),
  })
  .strict();
function key() {
  const value = Buffer.from(process.env.SPROUT_SYNC_CURSOR_KEY ?? "", "base64");
  if (value.length !== 32)
    throw new AppError(
      "NOT_CONFIGURED",
      "Financial sync is not configured.",
      503,
    );
  return value;
}
const accountHash = (owner: string) =>
  createHash("sha256").update(owner).digest("hex");
export function syncCursor(
  owner: string,
  after: number,
  through: number | null = null,
  now = new Date(),
  projectedAt = now.getTime(),
) {
  const body = Buffer.from(
    JSON.stringify(
      claims.parse({
        v: 2,
        projectedAt,
        account: accountHash(owner),
        after,
        through,
        expires: Math.floor(now.getTime() / 1000) + 30 * 86400,
      }),
    ),
  ).toString("base64url");
  return (
    body + "." + createHmac("sha256", key()).update(body).digest("base64url")
  );
}
export function readSyncCursor(owner: string, value: string, now = new Date()) {
  const secret = key();
  try {
    if (value.length > 2048 || !/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(value))
      throw new Error();
    const [body, mac] = value.split(".");
    const expected = createHmac("sha256", secret).update(body).digest();
    const supplied = Buffer.from(mac, "base64url");
    if (
      supplied.length !== expected.length ||
      !timingSafeEqual(supplied, expected)
    )
      throw new Error();
    const valueClaims = claims.parse(
      JSON.parse(Buffer.from(body, "base64url").toString("utf8")),
    );
    if (
      valueClaims.account !== accountHash(owner) ||
      valueClaims.expires <= Math.floor(now.getTime() / 1000) ||
      (valueClaims.through !== null && valueClaims.after > valueClaims.through)
    )
      throw new Error();
    return valueClaims;
  } catch {
    throw new AppError(
      "CURSOR_INVALID",
      "Refresh your account snapshot to continue syncing. Pending local changes are preserved.",
      409,
    );
  }
}

/** A fixed revision bounds every page. The projection is captured at that same
 * revision on the first page; clients publish it only after all pages arrive. */
export async function syncPage(
  store: UserStore,
  owner: string,
  flags: Capabilities,
  cursor: string,
  now = new Date(),
) {
  const current = readSyncCursor(owner, cursor, now);
  const head = await store.revision();
  if (
    current.after > head ||
    (current.through !== null && current.through > head)
  )
    throw new AppError(
      "CURSOR_INVALID",
      "Refresh your account snapshot to continue syncing.",
      409,
    );
  if (
    current.through === null &&
    current.after === head &&
    now.getTime() - current.projectedAt < 300_000
  )
    return {
      contractVersion: 1,
      accountId: owner,
      throughRevision: head,
      events: [],
      hasMore: false,
      unchanged: true,
      projection: null,
      capabilities: flags,
      nextCursor: syncCursor(owner, head, null, now, current.projectedAt),
    };
  let projection: Record<string, unknown> | null = null;
  let through = current.through;
  if (through === null) {
    const { transactions: _transactions, ...snapshot } = await workspace(
      store,
      flags,
      now,
    );
    through = snapshot.revision;
    projection = { ...snapshot, accountId: owner };
  }
  const events = await store.changes(current.after, 50, through);
  if (
    (current.after < through && events.length === 0) ||
    events.some((event, index) => event.sequence !== current.after + index + 1)
  )
    throw new AppError(
      "CURSOR_EXPIRED",
      "Your sync history requires a fresh snapshot. Pending local changes are preserved.",
      409,
    );
  const after = events.at(-1)?.sequence ?? current.after;
  const hasMore = after < through;
  return {
    contractVersion: 1,
    accountId: owner,
    throughRevision: through,
    events: events.map((event) => ({
      sequence: event.sequence,
      changes: event.changes.filter((change) => change.kind === "transactions"),
    })),
    hasMore,
    unchanged: false,
    projection,
    capabilities: flags,
    nextCursor: syncCursor(
      owner,
      after,
      hasMore ? through : null,
      now,
      projection ? now.getTime() : current.projectedAt,
    ),
  };
}
