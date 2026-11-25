import { expect, it, vi } from "vitest";
import { failure } from "../functions/context";

it("classifies operational failures without recording financial or credential content", () => {
  const log = vi.spyOn(console, "error").mockImplementation(() => undefined);
  try {
    const res = { json: (body: unknown, status = 200) => ({ body, status }) };
    const result = failure(res, {
      code: 409,
      type: "transaction_conflict",
      message: "private merchant amount token",
      request: { secret: "do not log" },
    });
    expect(result).toMatchObject({ status: 503 });
    expect(log.mock.calls).toEqual([
      [
        JSON.stringify({
          event: "sprout_request_failed",
          type: "transaction_conflict",
          status: 409,
        }),
      ],
    ]);
    log.mockClear();
    failure(res, { code: "private account", type: "private merchant $540" });
    expect(log.mock.calls).toEqual([
      [
        JSON.stringify({
          event: "sprout_request_failed",
          type: "unclassified",
          status: null,
        }),
      ],
    ]);
  } finally {
    log.mockRestore();
  }
});
