import { randomUUID } from "node:crypto";
import { z } from "zod";
import { capabilities, id, AppError } from "../contracts";
import { AppwriteStore } from "../integrations/appwrite-store";
import { answerQuestion } from "../integrations/assistant";
import { claim, finish } from "../domain/jobs";
import { fingerprint } from "../domain/finance";
import { failure, rawBody, serviceKey, type FunctionContext } from "./context";

export default async function main(context: FunctionContext) {
  try {
    const input = z
      .object({ owner: id, jobId: id })
      .strict()
      .parse(JSON.parse(rawBody(context)));
    const control = new AppwriteStore(input.owner, serviceKey(context), true);
    const store = new AppwriteStore(input.owner, serviceKey(context));
    const token = randomUUID();
    const job = await claim(control, input.jobId, token);
    if (!job)
      return context.res.json({ status: "already_claimed_or_finished" });
    try {
      if (
        (await store.get<{ type: string }>("privacy_jobs", "current"))?.data
          .type === "delete"
      )
        throw new AppError(
          "ACCOUNT_DELETING",
          "Account deletion is pending.",
          410,
        );
      const question = z.string().max(2000).parse(job.data.payload.question);
      const requestId = z.string().parse(job.data.payload.requestId);
      const contextId = z.string().nullable().parse(job.data.payload.context);
      const result = await answerQuestion(
        store,
        question,
        contextId,
        capabilities(),
        requestId,
      );
      await store.mutate(
        `conversation:${job.id}`,
        fingerprint(result),
        async (tx) =>
          tx.put("conversations", job.id, {
            question,
            context: contextId,
            answer: result,
            createdAt: new Date().toISOString(),
          }),
      );
      await finish(control, job.id, token, result);
      return context.res.json({ status: "succeeded" });
    } catch (error) {
      // A provider timeout can have consumed tokens. No automatic AI retry or escalation.
      await control.mutate(
        `ai-failed:${token}`,
        fingerprint(job.id),
        async (tx) => {
          const current = await tx.get<import("../domain/jobs").Job>(
            "jobs",
            job.id,
          );
          if (current?.data.leaseToken === token)
            return tx.put(
              "jobs",
              job.id,
              {
                ...current.data,
                status: "needs_attention",
                leaseUntil: null,
                leaseToken: null,
                error:
                  error instanceof AppError ? error.code : "AI_UNAVAILABLE",
              },
              current.version,
            );
          return null;
        },
      );
      return context.res.json({ status: "needs_attention" }, 202);
    }
  } catch (error) {
    return failure(context.res, error);
  }
}
