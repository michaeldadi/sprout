import { expect, it } from "vitest";
import { MemoryStore } from "../domain/store";
import { claim, defer, schedule, type Job } from "../domain/jobs";

it("defers only the live claim without spending an attempt, and replays the same policy decision", async () => {
  const store = new MemoryStore(),
    now = new Date("2026-11-10T03:00:00Z"),
    due = new Date("2026-11-10T13:00:00Z");
  const job = await store.mutate("queue", "queue", (tx) =>
    schedule(tx, "reminder.deliver", "renewal", {}, now),
  );
  await claim(store, job.id, "worker", now);
  await expect(
    defer(store, job.id, "stale", due, "QUIET_HOURS", now),
  ).rejects.toMatchObject({ code: "LEASE_LOST" });
  const result = await defer(store, job.id, "worker", due, "QUIET_HOURS", now);
  expect(result.data).toMatchObject({
    status: "retry",
    attempts: 0,
    dueAt: due.toISOString(),
    leaseToken: null,
  });
  expect(await defer(store, job.id, "worker", due, "QUIET_HOURS", now)).toEqual(
    result,
  );
});
it("rejects expired or corrupt claims and invalid deferral boundaries", async () => {
  const store = new MemoryStore(),
    now = new Date("2026-11-10T03:00:00Z");
  const job = await store.mutate("queue", "queue", (tx) =>
    schedule(tx, "reminder.deliver", "renewal", {}, now),
  );
  const running = (await claim(store, job.id, "worker", now))!;
  await expect(
    defer(
      store,
      job.id,
      "worker",
      new Date("2026-11-10T14:00:00Z"),
      "QUIET_HOURS",
      new Date("2026-11-10T03:04:00Z"),
    ),
  ).rejects.toMatchObject({ code: "LEASE_LOST" });
  await store.mutate("corrupt", "corrupt", (tx) =>
    tx.put<Job>(
      "jobs",
      job.id,
      { ...running.data, leaseUntil: "corrupt" },
      running.version,
    ),
  );
  await expect(
    defer(
      store,
      job.id,
      "worker",
      new Date("2026-11-10T14:00:00Z"),
      "QUIET_HOURS",
      now,
    ),
  ).rejects.toMatchObject({ code: "LEASE_LOST" });
  await expect(
    defer(store, job.id, "worker", now, "QUIET_HOURS", now),
  ).rejects.toMatchObject({ code: "INVALID_TIME" });
  await expect(
    defer(
      store,
      job.id,
      "worker",
      new Date("2026-11-12T14:00:00Z"),
      "QUIET_HOURS",
      now,
    ),
  ).rejects.toMatchObject({ code: "INVALID_TIME" });
});
