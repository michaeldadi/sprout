import { describe, expect, it } from "vitest";
import { forecast } from "../domain/finance";
import { transaction } from "../contracts";

const today = "2026-11-09", start = Date.parse(today + "T00:00:00Z");
const history = Array.from({length: 56}, (_, i) => transaction.parse({
  id: `daily-${i}`, accountId: "checking", source: "plaid", merchant: "Fixture",
  category: "Other", type: "expense", amount: {minor: -1000, currency: "USD"},
  date: new Date(start - (i + 1) * 86400000).toISOString().slice(0, 10),
}));
const input = () => ({
  balanceMinor: 200000, balanceAsOf: today + "T11:00:00Z", asOf: today + "T12:00:00Z", today,
  coverageComplete: true,
  historyCoverage: {fromDate: "2026-09-14", throughDate: "2026-11-08", accountIds: ["checking"]},
  transactions: history, commitments: [] as {date: string; minor: number; historicalEvidenceIds?: string[]}[], horizon: 7 as const,
});
describe("closed forecast eligibility and cash scope", () => {
  it("rejects invalid, future and stale balance observations and unsupported horizons", () => {
    for (const balanceAsOf of ["invalid", "2026-11-10T00:00:00Z", "2026-11-08T11:59:59Z", "2026-02-30T12:00:00Z", "November 9, 2026 11:00 UTC"]) {
      expect(forecast({...input(), balanceAsOf}).eligible).toBe(false);
    }
    expect(forecast({...input(), asOf: "invalid"}).eligible).toBe(false);
    expect(forecast({...input(), today: "2026-03-02", asOf: "2026-02-30T12:00:00Z", balanceAsOf: "2026-03-02T11:00:00Z"}).eligible).toBe(false);
    expect(forecast({...input(), asOf: "2025-11-09T12:00:00Z", balanceAsOf: "2025-11-09T11:00:00Z"}).eligible).toBe(false);
    expect(forecast({...input(), horizon: 8 as 7}).eligible).toBe(false);
    expect(forecast({...input(), balanceMinor: Infinity}).eligible).toBe(false);
  });
  it("requires explicit continuous coverage rather than first and last charge dates", () => {
    expect(forecast({...input(), historyCoverage: undefined, transactions: [history[0], history[55]]}).eligible).toBe(false);
    const base = input();
    for (const patch of [{fromDate: "2026-11-01"}, {throughDate: "2026-11-07"}, {throughDate: "2026-11-10"}, {fromDate: "invalid"}, {accountIds: []}, {accountIds: ["checking", "checking"]}]) {
      expect(forecast({...base, historyCoverage: {...base.historyCoverage, ...patch}}).eligible).toBe(false);
    }
  });
  it("uses only covered cash spending and excludes scheduled bill history, pending facts and credit purchases", () => {
    const bill = {...history[0], id: "rent", amount: {minor: -100000, currency: "USD" as const}};
    const other = {...history[0], id: "credit", accountId: "credit-card", amount: {minor: -90000, currency: "USD" as const}};
    const pending = {...history[0], id: "hold", pending: true};
    const result = forecast({...input(), transactions: [...history, bill, other, pending], commitments: [
      {date: "2026-11-10", minor: -100000, historicalEvidenceIds: ["rent"]},
      {date: "2026-11-11", minor: -10000}, // One cash card payment; purchases above are not counted again.
      {date: "2026-11-12", minor: 50000},
      {date: "2026-11-16", minor: -99999}, // Outside the seven-day half-open horizon.
    ]});
    expect(result).toMatchObject({eligible: true, expectedMinor: 133000, accountIds: ["checking"], modelVersion: "robust-cash-baseline-v2", balanceAsOf: input().balanceAsOf});
  });
  it("calculates 7, 14 and 30-day projections in exact cents with explicit uncalibrated assumptions", () => {
    for (const horizon of [7, 14, 30] as const) {
      const result = forecast({...input(), horizon});
      expect(result).toMatchObject({eligible: true, horizon, expectedMinor: 200000 - 1000 * horizon});
      if (result.eligible) {
        expect(result.lowMinor).toBeLessThanOrEqual(result.expectedMinor);
        expect(result.highMinor).toBeGreaterThanOrEqual(result.expectedMinor);
        expect(result.assumptions.join(" ")).toContain("calibration must pass");
      }
    }
  });
  it("fails closed on malformed financial dates or non-integer commitment amounts", () => {
    expect(forecast({...input(), commitments: [{date: "2026-02-30", minor: -10}]}).eligible).toBe(false);
    expect(forecast({...input(), commitments: [{date: today, minor: -1.01}]}).eligible).toBe(false);
    expect(forecast({...input(), transactions: [{...history[0], date: "invalid"}]}).eligible).toBe(false);
  });
});
