import { z } from "zod";
import { AppError } from "../contracts";
export interface FunctionContext {
  req: {
    path: string;
    method: string;
    headers: Record<string, string>;
    bodyText?: string;
    bodyJson?: unknown;
  };
  res: { json: (value: unknown, status?: number) => unknown };
}
export function serviceKey(context: FunctionContext) {
  return (
    context.req.headers["x-appwrite-key"] ??
    process.env.APPWRITE_FUNCTION_API_KEY ??
    ""
  );
}
export function rawBody(context: FunctionContext, limit = 100_000) {
  const value =
    context.req.bodyText ?? JSON.stringify(context.req.bodyJson ?? {});
  if (Buffer.byteLength(value) > limit)
    throw new AppError(
      "PAYLOAD_TOO_LARGE",
      "Request exceeds the supported size.",
      413,
    );
  return value;
}
export function failure(res: FunctionContext["res"], error: unknown) {
  if (error instanceof AppError)
    return res.json(
      { error: { code: error.code, message: error.message } },
      error.status,
    );
  if (error instanceof z.ZodError || error instanceof SyntaxError)
    return res.json(
      {
        error: {
          code: "INVALID_REQUEST",
          message: "Review the supplied fields.",
        },
      },
      400,
    );
  // Operational classification only. Never log exception messages, request
  // bodies, vendor responses, financial facts, credentials or stack locals.
  const upstream = error as { code?: unknown; type?: unknown } | null;
  const type =
    typeof upstream?.type === "string" && /^[a-z_]{1,80}$/.test(upstream.type)
      ? upstream.type
      : "unclassified";
  const status =
    typeof upstream?.code === "number" &&
    upstream.code >= 400 &&
    upstream.code <= 599
      ? upstream.code
      : null;
  console.error(
    JSON.stringify({ event: "sprout_request_failed", type, status }),
  );
  return res.json(
    {
      error: {
        code: "SERVICE_UNAVAILABLE",
        message: "Sprout could not complete this request. Retry shortly.",
      },
    },
    503,
  );
}
