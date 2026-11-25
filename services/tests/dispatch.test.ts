import { afterEach, describe, expect, it, vi } from "vitest";
import { wakeDispatcher } from "../integrations/dispatch";

afterEach(() => {
  delete process.env.APPWRITE_FUNCTION_API_ENDPOINT;
  delete process.env.APPWRITE_FUNCTION_PROJECT_ID;
});
describe("durable job wake", () => {
  it("does no network work without a complete service configuration", async () => {
    const send = vi.fn();
    expect(await wakeDispatcher("", send)).toBe(false);
    expect(send).not.toHaveBeenCalled();
  });
  it("signals only the dispatcher with asynchronous execution and tolerates outages", async () => {
    process.env.APPWRITE_FUNCTION_API_ENDPOINT =
      "https://staging.example.invalid/v1";
    process.env.APPWRITE_FUNCTION_PROJECT_ID = "staging";
    const send = vi.fn<typeof fetch>(
      async () => new Response("{}", { status: 201 }),
    );
    expect(await wakeDispatcher("fictional", send)).toBe(true);
    expect(send.mock.calls[0][0]).toBe(
      "https://staging.example.invalid/v1/functions/sprout-dispatcher/executions",
    );
    expect(JSON.parse((send.mock.calls[0] as any)[1].body)).toEqual({
      async: true,
      body: "{}",
    });
    expect(
      await wakeDispatcher(
        "fictional",
        vi.fn(async () => {
          throw new Error("offline");
        }),
      ),
    ).toBe(false);
    expect(
      await wakeDispatcher(
        "fictional",
        vi.fn(async () => new Response("", { status: 503 })),
      ),
    ).toBe(false);
  });
});
