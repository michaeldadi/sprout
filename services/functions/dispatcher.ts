import { Client, Functions, Query } from "node-appwrite";
import { PrivacyLedger } from "../integrations/privacy-ledger";
import { AppwriteStore } from "../integrations/appwrite-store";
import { failure, serviceKey, type FunctionContext } from "./context";

export default async function main(context: FunctionContext) {
  try {
    const key = serviceKey(context);
    const store = new AppwriteStore("system", key);
    const now = new Date().toISOString();
    const page = await store.tables.listRows({
      databaseId: store.database,
      tableId: "jobs",
      queries: [
        Query.equal("state", ["queued", "retry", "running"]),
        Query.lessThanEqual("due_at", now),
        Query.orderAsc("due_at"),
        Query.limit(25),
      ],
    });
    const client = new Client()
      .setEndpoint(process.env.APPWRITE_FUNCTION_API_ENDPOINT!)
      .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID!)
      .setKey(key);
    let dispatched = 0;
    for (const row of page.rows) {
      if (row.lease_until && Date.parse(String(row.lease_until)) > Date.now())
        continue;
      const job = JSON.parse(String(row.payload));
      const target =
        job.type.startsWith("privacy.") || job.type.startsWith("receipt.")
          ? "privacy"
          : job.type === "assistant"
            ? "ai"
            : "worker";
      await new Functions(client).createExecution({
        functionId: `sprout-${target}`,
        async: true,
        body: JSON.stringify({ owner: row.owner, jobId: row.entity_id }),
      });
      dispatched++;
    }
    if (
      process.env.SPROUT_PRIVACY_DATABASE_ID &&
      process.env.SPROUT_FIRST_PARTY_ERASURE === "true"
    ) {
      const ledger = new PrivacyLedger(key);
      const recoveries = await ledger.tables.listRows({
        databaseId: ledger.database,
        tableId: "deletion_ledger",
        queries: [
          Query.equal("state", ["queued", "running", "retry"]),
          Query.lessThanEqual(
            "updated_at",
            new Date(Date.now() - 300_000).toISOString(),
          ),
          Query.limit(10),
        ],
      });
      for (const row of recoveries.rows)
        if (
          !row.lease_until ||
          Date.parse(String(row.lease_until)) <= Date.now()
        ) {
          await new Functions(client).createExecution({
            functionId: "sprout-privacy",
            async: true,
            body: JSON.stringify({ owner: row.owner_id, recovery: true }),
          });
          dispatched++;
        }
    }
    return context.res.json({ dispatched });
  } catch (error) {
    return failure(context.res, error);
  }
}
