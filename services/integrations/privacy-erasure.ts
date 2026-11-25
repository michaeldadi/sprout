import { Client, Permission, Query, Role, Storage, Users } from "node-appwrite";
import { randomBytes } from "node:crypto";
import { AuthenticatorType } from "node-appwrite";
import { AppError, kinds } from "../contracts";
import { eraseActiveData, privacyHash } from "../domain/privacy";
import { AppwriteStore } from "./appwrite-store";
import { PrivacyLedger } from "./privacy-ledger";
import { privateFileWorkPending, type Receipt } from "../domain/receipts";
import type { Job } from "../domain/jobs";

export async function eraseFirstParty(
  store: AppwriteStore,
  key: string,
  receiptHash?: string,
  acceptedAt?: string,
  diagnostic?: (error: unknown) => void,
) {
  const ledger = new PrivacyLedger(key);
  if (receiptHash && acceptedAt)
    await ledger.accept(store.owner, receiptHash, acceptedAt);
  const claimed = await ledger.claim(store.owner);
  if (!claimed) return { status: "already_claimed_or_finished" };
  const progress = claimed.progress;
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_FUNCTION_API_ENDPOINT!)
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID!)
    .setKey(key);
  const users = new Users(client),
    storage = new Storage(client);
  const eraseRows = async (table: string, ownerColumn = "owner") => {
    while (true) {
      let rows;
      try {
        rows = await store.tables.listRows({
          databaseId: store.database,
          tableId: table,
          queries: [Query.equal(ownerColumn, store.owner), Query.limit(100)],
        });
      } catch (error: any) {
        if (error.code === 404 && table === "manual_transactions_v1") return;
        throw error;
      }
      if (!rows.rows.length) return;
      for (const row of rows.rows) {
        if (row[ownerColumn] !== store.owner)
          throw new AppError("PRIVACY_SCOPE", "Privacy row scope failed.", 409);
        await store.tables.deleteRow({
          databaseId: store.database,
          tableId: table,
          rowId: row.$id,
        });
      }
    }
  };
  return eraseActiveData(progress, {
    externalDependencies: async () => {
      const [
        connections,
        actions,
        credentials,
        conversations,
        entitlements,
        notifications,
      ] = await Promise.all([
        store.list("connections"),
        store.list("actions"),
        store.tables.listRows({
          databaseId: store.database,
          tableId: "provider_credentials",
          queries: [Query.equal("owner", store.owner), Query.limit(1)],
        }),
        store.list("conversations"),
        store.list("entitlements"),
        store.list("notifications"),
      ]);
      return (
        connections.length > 0 ||
        credentials.rows.length > 0 ||
        conversations.length > 0 ||
        entitlements.length > 0 ||
        notifications.length > 0 ||
        actions.some((a) =>
          ["awaiting_partner", "submitted", "verifying"].includes(
            String((a.data as any).state),
          ),
        )
      );
    },
    revokeAccess: async () => {
      await users.updateStatus({ userId: store.owner, status: false });
      await users.deleteSessions({ userId: store.owner });
    },
    removeAttachments: async () => {
      const [receipts, jobs] = await Promise.all([
        store.list<Receipt>("receipts"),
        store.list<Job>("jobs"),
      ]);
      // Stop access immediately, then let previously registered file IO expire
      // before the final sweep. New reservations are blocked by the ledger.
      if (privateFileWorkPending(receipts, jobs))
        throw new AppError(
          "PRIVACY_FILE_WORK_PENDING",
          "Access is revoked. Previously started private file work is finishing before removal.",
          503,
        );
      const bucket = process.env.SPROUT_PRIVATE_BUCKET_ID;
      if (!bucket)
        throw new AppError(
          "NOT_CONFIGURED",
          "Private storage is unavailable.",
          503,
        );
      // Only exact per-user ACLs identify files owned by this account. No broad
      // bucket grants exist; refuse unexpected ACLs rather than deleting others.
      let after: string | undefined;
      do {
        const page = await storage.listFiles({
          bucketId: bucket,
          queries: [
            Query.orderAsc("$id"),
            Query.limit(100),
            ...(after ? [Query.cursorAfter(after)] : []),
          ],
        });
        const next =
          page.files.length === 100 ? page.files.at(-1)!.$id : undefined;
        for (const file of page.files)
          if (
            file.$permissions.includes(Permission.read(Role.user(store.owner)))
          ) {
            if (
              file.$permissions.some((p) => !p.includes(`user:${store.owner}`))
            )
              throw new AppError(
                "PRIVACY_SCOPE",
                "Attachment ownership needs review.",
                409,
              );
            await storage.deleteFile({ bucketId: bucket, fileId: file.$id });
          }
        // A deleted cursor cannot be reused; restart after a page containing
        // matching files. Already removed files cannot be selected again.
        if (
          page.files.some((f) =>
            f.$permissions.includes(Permission.read(Role.user(store.owner))),
          )
        ) {
          after = undefined;
          continue;
        }
        after = next;
        if (!next) break;
      } while (true);
    },
    anonymizeAndReserveIdentity: async () => {
      for (;;) {
        const identities = await users.listIdentities({
          queries: [Query.equal("userId", store.owner), Query.limit(100)],
        });
        if (!identities.identities.length) break;
        for (const identity of identities.identities)
          await users.deleteIdentity({ identityId: identity.$id });
      }
      for (;;) {
        const targets = await users.listTargets({
          userId: store.owner,
          queries: [Query.limit(100)],
        });
        if (!targets.targets.length) break;
        for (const target of targets.targets)
          await users.deleteTarget({
            userId: store.owner,
            targetId: target.$id,
          });
      }
      const factors = await users.listMFAFactors({ userId: store.owner });
      await users.updateMFA({ userId: store.owner, mfa: false });
      if (factors.totp)
        await users.deleteMFAAuthenticator({
          userId: store.owner,
          type: AuthenticatorType.Totp,
        });
      await users.updateName({ userId: store.owner, name: "" });
      await users.updateEmail({
        userId: store.owner,
        email: `deleted-${privacyHash(store.owner).slice(0, 24)}@example.invalid`,
      });
      await users.updatePassword({
        userId: store.owner,
        password: "aA1!" + randomBytes(32).toString("base64url"),
      });
      const account = await users.get({ userId: store.owner });
      if (account.phone)
        await users.updatePhone({ userId: store.owner, number: "" });
      await users.updatePrefs({
        userId: store.owner,
        prefs: { sproutDeleted: true },
      });
      await users.updateLabels({ userId: store.owner, labels: [] });
      await users.updateEmailVerification({
        userId: store.owner,
        emailVerification: false,
      });
      await users.updatePhoneVerification({
        userId: store.owner,
        phoneVerification: false,
      });
      const verified = await users.get({ userId: store.owner });
      if (
        verified.status ||
        verified.name ||
        verified.phone ||
        !verified.email.endsWith("@example.invalid")
      )
        throw new AppError(
          "PRIVACY_RECOVERY",
          "Identity anonymization requires review.",
          409,
        );
    },
    removeFinancialRecords: async () => {
      // Keep the deletion lock until every other owned row has gone. The
      // independent ledger and disabled Auth ID survive this final removal.
      for (const kind of [
        ...kinds.filter((k) => k !== "privacy_jobs"),
        "provider_credentials",
        "webhook_receipts",
        "sync_events",
        "mutation_receipts",
        "sync_heads",
        "manual_transactions_v1",
        "privacy_jobs",
      ])
        await eraseRows(
          kind,
          kind === "manual_transactions_v1" ? "owner_id" : "owner",
        );
    },
    failure: diagnostic,
    save: async (p) => ledger.save(store.owner, p),
  });
}
