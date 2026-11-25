import { describe, expect, it } from "vitest";
import {
  parseUSD,
  detectRecurring,
  budgetSummary,
  parseExpenseText,
  forecast,
  normalizedMinor,
  checkedSum,
} from "../domain/finance";
import { transaction } from "../contracts";
const expense = (id: string, date: string, minor = -1199) =>
  transaction.parse({
    id,
    date,
    amount: { minor, currency: "USD" },
    merchant: "Example TV",
    category: "Entertainment",
    type: "expense",
    source: "manual",
  });
describe("financial correctness", () => {
  it("keeps cadence ratios exact and rejects totals outside safe minor units", () => {
    expect(normalizedMinor(1199, 52, 12)).toBe(5196);
    expect(normalizedMinor(Number.MAX_SAFE_INTEGER, 1, 12)).toBe(
      750599937895083,
    );
    expect(() => normalizedMinor(Number.MAX_SAFE_INTEGER, 52, 12)).toThrow();
    expect(() => checkedSum([Number.MAX_SAFE_INTEGER, 1])).toThrow();
    expect(() =>
      budgetSummary(
        [
          {
            ...expense("refund", "2026-11-09", 0),
            type: "refund",
            amount: { minor: Number.MAX_SAFE_INTEGER, currency: "USD" },
          },
        ],
        [
          {
            id: "limit",
            category: "Entertainment",
            month: "2026-11",
            limit: { minor: 1, currency: "USD" },
          },
        ],
        "2026-11-09",
      ),
    ).toThrow();
  });
  it("converts decimal strings without binary multiplication", () => {
    expect(parseUSD("0.29")).toBe(29);
    expect(parseUSD("$1,234.56")).toBe(123456);
    expect(() => parseUSD("1.005")).toThrow();
    expect(() => parseUSD("Infinity")).toThrow();
  });
  it("rejects invalid dates and directions", () => {
    expect(() => expense("a", "2026-02-30")).toThrow();
    expect(() => expense("a", "2026-11-01", 100)).toThrow();
  });
  it("requires three observations, ignores pending and normalizes cadence", () => {
    const rows = [
      expense("1", "2026-08-18"),
      expense("2", "2026-09-18"),
      expense("3", "2026-10-18"),
    ];
    expect(detectRecurring(rows.slice(0, 2))).toHaveLength(0);
    const stream = detectRecurring(rows)[0];
    expect(stream.cadence).toBe("monthly");
    expect(stream.nextDate).toBe("2026-11-18");
    expect(stream.monthlyMinor).toBe(1199);
    expect(
      detectRecurring(rows.map((t) => ({ ...t, pending: true }))),
    ).toHaveLength(0);
  });
  it("does not infer ordinary repeat visits as monthly subscriptions", () => {
    expect(
      detectRecurring([
        expense("1", "2026-10-01"),
        expense("2", "2026-10-03"),
        expense("3", "2026-10-10"),
      ]),
    ).toHaveLength(0);
  });
  it("computes budget totals and excludes transfers", () => {
    const rows = [
      expense("1", "2026-11-09", -2900),
      { ...expense("2", "2026-11-09", -5000), type: "transfer" as const },
    ];
    const r = budgetSummary(
      rows,
      [
        {
          id: "ent",
          category: "Entertainment",
          month: "2026-11",
          limit: { minor: 10000, currency: "USD" },
        },
      ],
      "2026-11-09",
    );
    expect(r.spentMinor).toBe(2900);
    expect(r.categories[0].remainingMinor).toBe(7100);
    expect(r.daysLeft).toBe(22);
  });
  it("never silently picks the first number from ambiguous speech or receipt text", () => {
    expect(
      parseExpenseText("Today 9 Nov I spent $14 on lunch").amountMinor,
    ).toBe(1400);
    expect(
      parseExpenseText("subtotal $14 tax $1 total $15").amountMinor,
    ).toBeNull();
    expect(parseExpenseText("table 14 lunch").amountMinor).toBeNull();
  });
  it("suppresses a forecast for incomplete coverage", () => {
    expect(
      forecast({
        balanceMinor: 50000,
        balanceAsOf: "2026-11-09",
        asOf: "2026-11-09T12:00:00Z",
        today: "2026-11-09",
        coverageComplete: false,
        transactions: [],
        commitments: [],
        horizon: 7,
      }).eligible,
    ).toBe(false);
  });
});
