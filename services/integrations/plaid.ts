import {
  createCipheriv,
  createDecipheriv,
  createHash,
  createPublicKey,
  randomBytes,
  verify,
  timingSafeEqual,
} from "node:crypto";
import { z } from "zod";
import { AppError, type Transaction } from "../contracts";

export function sealToken(
  value: string,
  owner: string,
  connectionId: string,
): string {
  const version = process.env.SPROUT_TOKEN_KEY_VERSION ?? "1";
  const key = Buffer.from(
    process.env[`SPROUT_TOKEN_KEY_${version}`] ?? "",
    "base64",
  );
  if (key.length !== 32)
    throw new AppError(
      "NOT_CONFIGURED",
      "Provider token encryption is unavailable.",
      503,
    );
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  cipher.setAAD(Buffer.from(`${version}:${owner}:${connectionId}`));
  return [
    version,
    iv.toString("base64"),
    Buffer.concat([cipher.update(value, "utf8"), cipher.final()]).toString(
      "base64",
    ),
    cipher.getAuthTag().toString("base64"),
  ].join(".");
}
export function assertTokenConfiguration() {
  sealToken("configuration-check", "configuration", "configuration");
}
export function openToken(
  value: string,
  owner: string,
  connectionId: string,
): string {
  const [version, iv, data, tag] = value.split(".");
  const key = Buffer.from(
    process.env[`SPROUT_TOKEN_KEY_${version}`] ?? "",
    "base64",
  );
  if (key.length !== 32)
    throw new AppError(
      "NOT_CONFIGURED",
      "Provider token encryption is unavailable.",
      503,
    );
  const decipher = createDecipheriv(
    "aes-256-gcm",
    key,
    Buffer.from(iv, "base64"),
  );
  decipher.setAAD(Buffer.from(`${version}:${owner}:${connectionId}`));
  decipher.setAuthTag(Buffer.from(tag, "base64"));
  return Buffer.concat([
    decipher.update(Buffer.from(data, "base64")),
    decipher.final(),
  ]).toString("utf8");
}
const bankTransaction = z.object({
  transaction_id: z.string(),
  account_id: z.string(),
  date: z.string(),
  amount: z.number().finite(),
  iso_currency_code: z.string().nullable(),
  name: z.string(),
  merchant_name: z.string().nullable().optional(),
  pending: z.boolean(),
  pending_transaction_id: z.string().nullable().optional(),
  personal_finance_category: z
    .object({ primary: z.string(), detailed: z.string() })
    .nullable()
    .optional(),
});
export type BankTransaction = z.infer<typeof bankTransaction>;
const syncPage = z.object({
  added: z.array(bankTransaction),
  modified: z.array(bankTransaction),
  removed: z.array(z.object({ transaction_id: z.string() })),
  next_cursor: z.string(),
  has_more: z.boolean(),
});
export class PlaidClient {
  constructor(private transport: typeof fetch = fetch) {}
  async post(path: string, data: Record<string, unknown>): Promise<unknown> {
    const environment = process.env.PLAID_ENVIRONMENT;
    if (
      !["sandbox", "production"].includes(environment ?? "") ||
      !process.env.PLAID_CLIENT_ID ||
      !process.env.PLAID_SECRET
    )
      throw new AppError(
        "NOT_CONFIGURED",
        "Bank linking has not been configured.",
        503,
      );
    const response = await this.transport(
      `https://${environment}.plaid.com${path}`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "Plaid-Version": "2020-09-14",
        },
        body: JSON.stringify({
          client_id: process.env.PLAID_CLIENT_ID,
          secret: process.env.PLAID_SECRET,
          ...data,
        }),
        signal: AbortSignal.timeout(12_000),
      },
    );
    const result = (await response.json()) as { error_code?: string };
    if (!response.ok)
      throw new AppError(
        result.error_code === "TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION"
          ? "PAGINATION_MUTATION"
          : result.error_code === "ITEM_LOGIN_REQUIRED"
            ? "CONNECTION_REPAIR"
            : "PROVIDER_UNAVAILABLE",
        "The bank connection needs another attempt or repair.",
        503,
      );
    return result;
  }
  async linkToken(
    owner: string,
    platform: "ios" | "android",
    accessToken?: string,
  ) {
    return z.object({ link_token: z.string(), expiration: z.string() }).parse(
      await this.post("/link/token/create", {
        user: { client_user_id: owner },
        client_name: "Sprout",
        language: "en",
        country_codes: ["US"],
        ...(accessToken
          ? { access_token: accessToken }
          : { products: ["transactions"] }),
        ...(platform === "android"
          ? { android_package_name: "com.michaeldadi.sprout" }
          : {}),
        ...(process.env.PLAID_REDIRECT_URI
          ? { redirect_uri: process.env.PLAID_REDIRECT_URI }
          : {}),
        ...(process.env.PLAID_WEBHOOK_URL
          ? { webhook: process.env.PLAID_WEBHOOK_URL }
          : {}),
      }),
    );
  }
  async exchange(publicToken: string) {
    return z.object({ access_token: z.string(), item_id: z.string() }).parse(
      await this.post("/item/public_token/exchange", {
        public_token: publicToken,
      }),
    );
  }
  async accounts(token: string) {
    return z
      .object({
        accounts: z.array(
          z.object({
            account_id: z.string(),
            name: z.string(),
            mask: z.string().nullable(),
            type: z.string(),
            subtype: z.string().nullable(),
            balances: z.object({
              current: z.number().finite().nullable(),
              available: z.number().finite().nullable(),
              iso_currency_code: z.string().nullable(),
            }),
          }),
        ),
      })
      .parse(await this.post("/accounts/get", { access_token: token }));
  }
  async syncCycle(token: string, cursor?: string) {
    for (let restart = 0; restart < 3; restart++) {
      const added: BankTransaction[] = [];
      const modified: BankTransaction[] = [];
      const removed: { transaction_id: string }[] = [];
      let next = cursor;
      try {
        for (let page = 0; page < 100; page++) {
          const result = syncPage.parse(
            await this.post("/transactions/sync", {
              access_token: token,
              ...(next ? { cursor: next } : {}),
              count: 100,
            }),
          );
          added.push(...result.added);
          modified.push(...result.modified);
          removed.push(...result.removed);
          next = result.next_cursor;
          if (!result.has_more)
            return { added, modified, removed, cursor: next };
        }
        throw new AppError(
          "IMPORT_TOO_LARGE",
          "This import needs a longer-running ingestion deployment.",
          503,
        );
      } catch (e) {
        if (
          e instanceof AppError &&
          e.code === "PAGINATION_MUTATION" &&
          restart < 2
        )
          continue;
        throw e;
      }
    }
    throw new AppError(
      "IMPORT_RETRY",
      "The bank changed during import. Sprout will retry.",
      503,
    );
  }
  async verifyWebhook(
    raw: string,
    jwt: string,
    now = Date.now(),
  ): Promise<void> {
    const parts = jwt.split(".");
    if (parts.length !== 3)
      throw new AppError(
        "INVALID_SIGNATURE",
        "Invalid webhook signature.",
        401,
      );
    const header = z
      .object({ alg: z.literal("ES256"), kid: z.string().max(200) })
      .parse(JSON.parse(Buffer.from(parts[0], "base64url").toString()));
    const payload = z
      .object({ iat: z.number(), request_body_sha256: z.string().length(64) })
      .parse(JSON.parse(Buffer.from(parts[1], "base64url").toString()));
    if (Math.abs(now / 1000 - payload.iat) > 300)
      throw new AppError(
        "EXPIRED_SIGNATURE",
        "Webhook signature expired.",
        401,
      );
    const response = z
      .object({
        key: z.object({
          alg: z.literal("ES256"),
          kty: z.literal("EC"),
          crv: z.literal("P-256"),
          x: z.string(),
          y: z.string(),
          expired_at: z.number().nullable().optional(),
        }),
      })
      .parse(
        await this.post("/webhook_verification_key/get", {
          key_id: header.kid,
        }),
      );
    if (response.key.expired_at && response.key.expired_at < now / 1000)
      throw new AppError("EXPIRED_KEY", "Webhook signing key expired.", 401);
    const key = createPublicKey({ key: response.key, format: "jwk" });
    const valid = verify(
      "sha256",
      Buffer.from(`${parts[0]}.${parts[1]}`),
      { key, dsaEncoding: "ieee-p1363" },
      Buffer.from(parts[2], "base64url"),
    );
    const hash = createHash("sha256").update(raw).digest();
    if (
      !valid ||
      !timingSafeEqual(hash, Buffer.from(payload.request_body_sha256, "hex"))
    )
      throw new AppError(
        "INVALID_SIGNATURE",
        "Invalid webhook signature.",
        401,
      );
  }
}
export function bankFact(
  t: BankTransaction,
  connectionId: string,
): Transaction {
  if (t.iso_currency_code !== "USD")
    throw new AppError(
      "UNSUPPORTED_CURRENCY",
      "Only USD accounts are supported in this release.",
    );
  const minor = Math.round(-t.amount * 100);
  if (
    !Number.isSafeInteger(minor) ||
    Math.abs(minor + t.amount * 100) > 0.00001
  )
    throw new AppError(
      "INVALID_MONEY",
      "Bank amount exceeds supported precision.",
    );
  const detailed = t.personal_finance_category?.detailed ?? "";
  const transfer = /TRANSFER|LOAN_PAYMENTS_CREDIT_CARD_PAYMENT/.test(detailed);
  const type = transfer
    ? "transfer"
    : minor < 0
      ? "expense"
      : t.personal_finance_category?.primary &&
          /^(GENERAL_MERCHANDISE|FOOD_AND_DRINK|TRAVEL|TRANSPORTATION|ENTERTAINMENT|MEDICAL|PERSONAL_CARE|HOME_IMPROVEMENT|GENERAL_SERVICES|RENT_AND_UTILITIES)$/.test(
            t.personal_finance_category.primary,
          )
        ? "refund"
        : "income";
  return {
    id: createHash("sha256")
      .update(`${connectionId}:${t.transaction_id}`)
      .digest("hex")
      .slice(0, 36),
    amount: { minor, currency: "USD" },
    date: t.date,
    merchant: t.merchant_name ?? t.name,
    category: t.personal_finance_category?.primary ?? "Other",
    type,
    source: "plaid",
    accountId: t.account_id,
    description: "",
    pending: t.pending,
    excluded: false,
    providerId: t.transaction_id,
    ...(t.pending_transaction_id
      ? { pendingTransactionId: t.pending_transaction_id }
      : {}),
  };
}
