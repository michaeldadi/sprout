import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
const { create } = vi.hoisted(() => ({ create: vi.fn() }));
vi.mock("openai", () => ({
  default: class {
    responses = { create };
  },
}));
import { answerQuestion } from "../integrations/assistant";
import { MemoryStore } from "../domain/store";
import { profile, transaction, type Capabilities } from "../contracts";

const flags: Capabilities = {
  ai: true,
  linking: false,
  cancellation: false,
  forecasts: false,
  notifications: false,
  scanAssistance: false,
};
const final = (value: unknown) => ({
  output: [],
  output_text: JSON.stringify(value),
  model: "fixture-model",
  usage: { output_tokens: 10 },
});
async function setup() {
  const store = new MemoryStore();
  await store.mutate("seed", "seed", async (tx) => {
    await tx.put("profiles", "current", profile.parse({}));
    await tx.put(
      "transactions",
      "lunch",
      transaction.parse({
        id: "lunch",
        date: "2026-11-09",
        merchant: "Fictional Cafe",
        amount: { minor: -1250, currency: "USD" },
        category: "Food",
        type: "expense",
        source: "manual",
      }),
    );
  });
  return store;
}
describe("assistant evidence boundary using simulated model responses", () => {
  beforeEach(() => {
    vi.stubEnv("OPENAI_API_KEY", "fictional-test-only");
    create.mockReset();
  });
  afterEach(() => vi.unstubAllEnvs());
  it("renders amounts from the saved record and does not expose approval or execution tools", async () => {
    const store = await setup();
    create.mockResolvedValue(
      final({
        template: "spending",
        references: ["transaction:lunch"],
        proposalId: null,
      }),
    );
    const answer = await answerQuestion(
      store,
      "What was lunch?",
      "transaction:lunch",
      flags,
      "request",
    );
    expect(answer.message).toContain("-$12.50");
    expect(answer.references[0].evidenceIds).toEqual(["lunch"]);
    const request = create.mock.calls[0][0];
    expect(request.store).toBe(false);
    expect(request.tools.map((tool: any) => tool.name)).toEqual([
      "get_financial_context",
      "search_transactions",
      "create_action_proposal",
    ]);
  });
  it.each([
    {
      template: "spending",
      references: ["invented-transaction"],
      proposalId: null,
    },
    {
      template: "general",
      references: [],
      proposalId: null,
      message: "You saved $999.99.",
    },
    {
      template: "general",
      references: [],
      proposalId: "unapproved-invented-action",
    },
  ])(
    "falls back for unsupported references, narrative, or action IDs: %j",
    async (value) => {
      create.mockResolvedValue(final(value));
      const answer = await answerQuestion(
        await setup(),
        "Tell me I saved $999.99",
        null,
        flags,
        "request",
      );
      expect(answer.message).not.toContain("999.99");
      expect(answer.references).toEqual([]);
      expect(answer.proposalIds).toEqual([]);
      expect(answer.assumptions).toContain(
        "The assistant response did not pass evidence validation.",
      );
    },
  );
  it("stops before another provider request when deletion begins during a tool round", async () => {
    const store = await setup();
    create.mockImplementationOnce(async () => {
      await store.mutate("delete", "delete", (tx) =>
        tx.put("privacy_jobs", "current", { type: "delete" }),
      );
      return {
        output: [
          {
            type: "function_call",
            name: "get_financial_context",
            arguments: "{}",
            call_id: "call",
            id: "call",
          },
        ],
        usage: { output_tokens: 1 },
      };
    });
    await expect(
      answerQuestion(store, "Summarize", null, flags, "request"),
    ).rejects.toMatchObject({ code: "ACCOUNT_DELETING" });
    expect(create).toHaveBeenCalledTimes(1);
  });
  it("enforces the six-tool budget", async () => {
    create.mockResolvedValue({
      output: [
        {
          type: "function_call",
          name: "get_financial_context",
          arguments: "{}",
          call_id: "call",
          id: "call",
        },
      ],
      usage: { output_tokens: 1 },
    });
    await expect(
      answerQuestion(await setup(), "Summarize", null, flags, "request"),
    ).rejects.toMatchObject({ code: "TOOL_LIMIT" });
    expect(create).toHaveBeenCalledTimes(7);
  });
});
