import { AppError } from "../contracts";
import { fingerprint } from "../domain/finance";

export async function deliverReminder(owner: string, occurrenceId: string) {
  return deliver(owner, occurrenceId, false);
}
export async function deliverWeeklyReview(owner: string, occurrenceId: string) {
  return deliver(owner, occurrenceId, true);
}
async function deliver(owner: string, occurrenceId: string, weekly: boolean) {
  if (!process.env.ONESIGNAL_APP_ID || !process.env.ONESIGNAL_REST_API_KEY)
    throw new AppError(
      "NOT_CONFIGURED",
      "Notification delivery is unavailable.",
      503,
    );
  const hash = fingerprint(occurrenceId).slice(0, 32);
  const idempotencyKey = `${hash.slice(0, 8)}-${hash.slice(8, 12)}-4${hash.slice(13, 16)}-a${hash.slice(17, 20)}-${hash.slice(20)}`;
  const result = await fetch("https://api.onesignal.com/notifications", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Key ${process.env.ONESIGNAL_REST_API_KEY}`,
    },
    body: JSON.stringify({
      app_id: process.env.ONESIGNAL_APP_ID,
      include_aliases: { external_id: [owner] },
      target_channel: "push",
      contents: {
        en: weekly
          ? "Your weekly money review is ready. Open Sprout to see your available history."
          : "A renewal you track is approaching. Open Sprout to review it.",
      },
      headings: { en: weekly ? "Your Sprout review" : "Your Sprout reminder" },
      data: { route: weekly ? "/insights" : "/subscriptions" },
      idempotency_key: idempotencyKey,
    }),
    signal: AbortSignal.timeout(12_000),
  });
  if (!result.ok)
    throw new AppError(
      "DELIVERY_UNAVAILABLE",
      "Notification provider did not accept the reminder.",
      503,
    );
  const response = (await result.json()) as { id?: string };
  if (!response.id)
    throw new AppError(
      "DELIVERY_UNAVAILABLE",
      "No eligible notification device was found.",
      503,
    );
  return {
    providerReference: response.id,
    status: "accepted",
    delivered: false,
  };
}
