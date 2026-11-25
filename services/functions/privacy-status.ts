import { z } from "zod";
import { AppError } from "../contracts";
import { deletionReceipt, privacyHash } from "../domain/privacy";
import { PrivacyLedger } from "../integrations/privacy-ledger";
import { failure, rawBody, serviceKey, type FunctionContext } from "./context";

/** Public capability lookup, separate from authenticated financial API. The
 * receipt has 256 bits of entropy; the response contains no identity or facts. */
export default async function main(context: FunctionContext) {
  try {
    if (context.req.method !== "POST")
      throw new AppError("NOT_FOUND", "Operation unavailable.", 404);
    const raw = rawBody(context);
    if (Buffer.byteLength(raw) > 1000)
      throw new AppError("INVALID_REQUEST", "Review the privacy receipt.");
    const input = z
      .object({ receipt: deletionReceipt })
      .strict()
      .parse(JSON.parse(raw));
    const progress = await new PrivacyLedger(serviceKey(context)).status(
      privacyHash(input.receipt),
    );
    return context.res.json({
      ...progress,
      scope: "first_party_active_data",
      retained: [
        "A disabled anonymous account ID prevents restored records from being assigned to a new account.",
        "A minimal privacy restoration ledger is retained for restoration filtering.",
        "Backups expire under the published retention policy; external providers have separate timelines.",
      ],
    });
  } catch (error) {
    return failure(context.res, error);
  }
}
